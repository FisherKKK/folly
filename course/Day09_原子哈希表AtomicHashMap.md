# Folly 深度学习课程 - 第 9 天

# 第 9 天：原子哈希表（AtomicHashMap）

## 学习目标
- 理解无锁数据结构的设计挑战
- 掌握 AtomicHashMap 的实现策略
- 学习等待查找（Wait-Free）技术

## 核心内容

### 9.1 为什么需要 AtomicHashMap？

**问题**：`std::unordered_map` 不是线程安全的

```cpp
std::unordered_map<int, int> map;

// 线程 1
map[1] = 100;

// 线程 2
map[2] = 200;  // 数据竞争！未定义行为
```

**解决方案**：
- **外部加锁**：`std::mutex` + `std::unordered_map`
- **并发哈希表**：`tbb::concurrent_hash_map`
- **AtomicHashMap**：Folly 的实现

### 9.2 AtomicHashMap 的设计

**核心思想**：固定大小 + 原子操作

```cpp
#include <folly/synchronization/AtomicHashMap.h>

folly::AtomicHashMap<int, std::string> map(1024);  // 固定容量

// 线程安全的操作
map.insert(1, "hello");
map.insert(2, "world");

auto* result = map.find(1);
if (result) {
    std::cout << *result << std::endl;
}
```

**特点**：
- **查找无锁**：find() 是 wait-free
- **固定大小**：不支持动态增长
- **int32/int64 键**：优化的小整数键
- **高性能**：比 `tbb::concurrent_hash_map` 快 2-4 倍

### 9.3 内部结构

**AHArray：核心数组**

```cpp
template <typename Key, typename Value>
class AtomicHashMap {
    struct Entry {
        std::atomic<Key> key_;
        Value value_;

        // 空键标记（用于已删除的槽）
        static constexpr Key kEmptyKey = Key(-1);
    };

    std::unique_ptr<Entry[]> entries_;
    size_t capacity_;
    size_t num_slots_;  // 实际使用的槽位数量
};
```

**查找算法**：

```cpp
Value* find(Key key) {
    size_t index = hash(key) & (capacity_ - 1);

    // 线性探测
    while (true) {
        Entry& entry = entries_[index];
        Key found_key = entry.key_.load(std::memory_order_relaxed);

        if (found_key == key) {
            // 找到匹配
            return &entry.value_;
        } else if (found_key == Entry::kEmptyKey) {
            // 空槽，键不存在
            return nullptr;
        }

        // 继续探测
        index = (index + 1) & (capacity_ - 1);
    }
}
```

**为什么 wait-free？**
- **无阻塞**：使用 `memory_order_relaxed` 读取键
- **无循环依赖**：不等待其他线程
- **固定步数**：最多探测 `capacity_` 次

### 9.4 插入算法

**插入策略**：先探测，后 CAS

```cpp
bool insert(Key key, const Value& value) {
    size_t start_index = hash(key) & (capacity_ - 1);
    size_t index = start_index;

    // 第一轮：查找键或空槽
    size_t first_empty = -1;
    while (true) {
        Entry& entry = entries_[index];
        Key found_key = entry.key_.load(std::memory_order_relaxed);

        if (found_key == key) {
            // 键已存在（根据策略可能更新或返回）
            return false;
        } else if (found_key == Entry::kEmptyKey) {
            first_empty = index;
            break;  // 找到空槽
        }

        index = (index + 1) & (capacity_ - 1);
        if (index == start_index) {
            return false;  // 表已满
        }
    }

    // 第二轮：尝试插入
    index = first_index;
    while (true) {
        Entry& entry = entries_[index];
        Key expected = Entry::kEmptyKey;

        // CAS：尝试占据空槽
        if (entry.key_.compare_exchange_strong(
                expected, key,
                std::memory_order_release,
                std::memory_order_relaxed)) {
            // 成功占据
            entry.value_ = value;
            return true;
        }

        // CAS 失败：检查是否是我们要找的键
        if (expected == key) {
            return false;  // 其他线程已经插入
        }

        // 继续尝试下一个槽
        index = (index + 1) & (capacity_ - 1);
    }
}
```

### 9.5 键锁定策略

**问题**：插入时的并发修改

**解决方案**：锁定键的范围

```cpp
struct Entry {
    std::atomic<Key> key_;
    std::atomic<uint8_t> lock_;  // 锁标志

    void lock() {
        uint8_t expected = 0;
        while (!lock_.compare_exchange_strong(
            expected, 1,
            std::memory_order_acquire)) {
            expected = 0;
            // 自旋等待
        }
    }

    void unlock() {
        lock_.store(0, std::memory_order_release);
    }
};
```

**插入带锁**：

```cpp
bool insert(Key key, const Value& value) {
    // ... 找到槽位

    entry.lock();
    SCOPE_EXIT { entry.unlock(); };

    // 再次检查（可能已改变）
    if (entry.key_.load(std::memory_order_relaxed) != Entry::kEmptyKey) {
        return false;
    }

    entry.key_.store(key, std::memory_order_release);
    entry.value_ = value;
    return true;
}
```

### 9.6 增长策略：AHMap

**问题**：AtomicHashMap 大小固定

**解决方案**：多层 AHMap

```cpp
template <typename Key, typename Value>
class AHMap {
    std::vector<std::unique_ptr<AtomicHashMap<Key, Value>>> levels_;

public:
    AHMap(size_t initial_capacity) {
        levels_.push_back(
            std::make_unique<AtomicHashMap<Key, Value>>(initial_capacity)
        );
    }

    Value* find(Key key) {
        // 在所有层中查找
        for (auto& level : levels_) {
            if (Value* result = level->find(key)) {
                return result;
            }
        }
        return nullptr;
    }

    void insert(Key key, const Value& value) {
        // 尝试在顶层插入
        if (!levels_.back()->insert(key, value)) {
            // 顶层满了，增长
            grow();
            levels_.back()->insert(key, value);
        }
    }

private:
    void grow() {
        size_t new_capacity = levels_.back()->capacity() * 2;
        levels_.push_back(
            std::make_unique<AtomicHashMap<Key, Value>>(new_capacity)
        );
    }
};
```

### 9.7 性能优化技巧

**优化 1：SIMD 扫描**

```cpp
// 批量检查多个槽的键
__m256i keys = _mm256_loadu_si256((__m256i*)&entries_[index]);
__m256i target = _mm256_set1_epi32(key);
__m256i cmp = _mm256_cmpeq_epi32(keys, target);
uint32_t mask = _mm256_movemask_epi8(cmp);

if (mask) {
    // 找到可能的匹配
}
```

**优化 2：缓存行对齐**

```cpp
struct FOLLY_ALIGNAS(64) Entry {
    std::atomic<Key> key_;
    Value value_;
};
```

**优化 3：预取**

```cpp
Value* find(Key key) {
    size_t index = hash(key) & (capacity_ - 1);

    // 预取下一个可能的槽
    __builtin_prefetch(&entries_[(index + 1) & (capacity_ - 1)]);

    // ... 查找逻辑
}
```

## 性优启示 #9：无锁设计的权衡

AtomicHashMap 展示了无锁设计的挑战：
1. **固定大小**：为了无锁而牺牲动态性
2. **类型限制**：int32/int64 键的优化
3. **CAS 失败重试**：高竞争下性能下降

## 课后作业

1. 实现 `AtomicHashMap` 的简化版本（支持 insert 和 find）
2. 比较不同并发级别下的性能
3. 设计一个支持动态增长的方案

---

**第 9 天完。明天见！**
