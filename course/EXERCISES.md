# Folly 深度学习课程 - 习题集与答案

## 习题说明

本习题集包含 14 天的练习题，分为三个难度级别：
- **基础题**（⭐）：巩固概念
- **进阶题**（⭐⭐）：应用实践
- **挑战题**（⭐⭐⭐）：深入研究

---

## Day 1: Folly 架构概览与构建系统

### 基础题

**题目 1.1**：Folly 的三大核心原则是什么？

**答案**：
1. 性能优先：只在现有方案无法满足性能需求时创建新组件
2. 实用性导向：解决 Facebook 内部实际遇到的性能瓶颈
3. 无内部依赖限制：Folly 模块可以使用任何其他 Folly 组件

---

**题目 1.2**：如何使用 getdeps.py 构建 Folly？

**答案**：
```bash
# 完整构建
python3 ./build/fbcode_builder/getdeps.py build folly --allow-system-packages

# 只安装依赖
python3 ./build/fbcode_builder/getdeps.py install-system-deps --recursive
```

---

### 进阶题

**题目 1.3**：阅读 `folly/CMakeLists.txt`，找出最大的 5 个库（按源文件数量）。

**答案**：
```bash
# 查找所有 folly_add_library 调用
grep -r "folly_add_library" folly/ --include="CMakeLists.txt" -A 20

# 统计 SRCS 数量
# 大致结果（具体数量随版本变化）：
# 1. io/async（异步I/O）
# 2. container（容器）
# 3. futures（Future/Promise）
# 4. coro（协程）
# 5. synchronization（同步）
```

---

**题目 1.4**：实现一个简单的 Folly 风格的组件。

**参考答案**：
```cpp
// my_folly_component.h
#pragma once
#include <folly/FBVector.h>

namespace myapp {

// 简单的栈分配向量
template <typename T, size_t N>
class StackVector {
    folly::small_vector<T, N> data_;

public:
    void push(const T& value) {
        data_.push_back(value);
    }

    T& operator[](size_t index) {
        return data_[index];
    }

    size_t size() const {
        return data_.size();
    }
};

} // namespace myapp
```

---

### 挑战题

**题目 1.5**：分析 Folly 为什么不提供 ABI 兼容性保证。这是一个明智的设计决策吗？为什么？

**答案**：

Folly 不提供 ABI 兼容性的原因：

1. **性能优先**：
   - ABI 兼容性会限制优化空间
   - 可以自由改变内部实现
   - 可以充分利用编译器特性

2. **实际应用场景**：
   - Facebook 内部总是从源码构建
   - 发布时静态链接
   - 不需要动态链接库

3. **开发效率**：
   - 不需要维护旧版本接口
   - 可以快速迭代
   - 减少技术债务

这是一个**明智的设计决策**，因为：
- ✅ 符合 Folly 的目标（高性能）
- ✅ 适合主要用户（Facebook 和从源码构建的项目）
- ✅ 简化了维护
- ❌ 不适合需要动态链接的场景

---

## Day 2: 分支预测与编译器优化

### 基础题

**题目 2.1**：解释 FOLLY_LIKELY 和 FOLLY_UNLIKELY 的作用。

**答案**：
- `FOLLY_LIKELY`：告诉编译器条件很可能为真
- `FOLLY_UNLIKELY`：告诉编译器条件很可能为假
- 用于优化分支预测，减少流水线清空

---

**题目 2.2**：如何使用强制内联？

**答案**：
```cpp
#include <folly/Portability.h>

// 强制内联
FOLLY_ALWAYS_INLINE int add(int a, int b) {
    return a + b;
}

// 禁止内联
FOLLY_NOINLINE void debugFunction() {
    // 调试代码
}
```

---

### 进阶题

**题目 2.3**：编写微基准测试，比较使用 FOLLY_LIKELY 前后的性能差异。

**参考答案**：
```cpp
#include <folly/Benchmark.h>
#include <folly/Likely.h>

BENCHMARK(unlikely_branch, iters) {
    int sum = 0;
    for (size_t i = 0; i < iters; ++i) {
        // 99% 的情况：data 是有效的
        int* data = reinterpret_cast<int*>((i % 100) ? 0 : i + 1);

        if (FOLLY_UNLIKELY(data == nullptr)) {
            sum += 1;
        } else {
            sum += *data;
        }
    }
    folly::doNotOptimize(sum);
}

// 运行：./benchmark
// 预期：unlikely_branch 会更快（错误路径被优化）
```

---

**题目 2.4**：使用 objdump 查看编译器如何优化带有分支预测的代码。

**参考答案**：
```bash
# 1. 编译测试代码
g++ -O3 -march=native -c test.cpp -o test.o

# 2. 查看汇编
objdump -d -M intel test.o | grep -A 20 "function_name"

# 3. 观察冷路径是否被移到代码末尾
```

---

### 挑战题

**题目 2.5**：使用 perf 分析实际程序的分支预测准确率，并提出优化建议。

**参考答案**：
```bash
# 1. 记录分支预测事件
perf record -e branches:u -e branch-misses:u ./program

# 2. 查看报告
perf report --sort=branch-misses

# 3. 查看特定函数
perf annotate function_name

# 4. 分析结果
# - branches:u: 总分支数
# - branch-misses: 分支预测失败数
# - 准确率 = 1 - (branch-misses / branches)

# 优化建议：
# - 如果准确率 < 70%：考虑重新排序条件
# - 如果准确率 < 50%：考虑使用查找表
# - 如果有数据依赖：考虑使用 PGO
```

---

## Day 3: 内存对齐与缓存友好设计

### 基础题

**题目 3.1**：什么是伪共享（False Sharing）？如何避免？

**答案**：
- **定义**：多个线程修改同一缓存行的不同数据，导致缓存失效
- **避免方法**：
  ```cpp
  // 方法 1：手动填充
  struct GoodCounter {
      alignas(64) std::atomic<int> counter;
      char padding[64 - sizeof(std::atomic<int>)];
  };

  // 方法 2：使用 Folly 常量
  struct GoodCounter2 {
      alignas(folly::cacheline_align_v) std::atomic<int> counter;
  };
  ```

---

**题目 3.2**：small_vector 相比 std::vector 的优势是什么？

**答案**：
- **SBO（小缓冲区优化）**：小数组在栈上，零堆分配
- **性能提升**：7-10x（对于小数组）
- **适用场景**：临时小数组、函数局部数组

---

### 进阶题

**题目 3.3**：编写微基准测试，测量伪共享的性能影响。

**参考答案**：
```cpp
#include <folly/Benchmark.h>
#include <thread>
#include <atomic>

BENCHMARK(FalseSharing, iters) {
    struct BadCounter {
        std::atomic<int> c1;
        std::atomic<int> c2;  // 同一缓存行
    } counter;

    std::thread t1([&] {
        for (size_t i = 0; i < iters; ++i) {
            counter.c1.fetch_add(1, std::memory_order_relaxed);
        }
    });

    std::thread t2([&] {
        for (size_t i = 0; i < iters; ++i) {
            counter.c2.fetch_add(1, std::memory_order_relaxed);
        }
    });

    t1.join();
    t2.join();
}

BENCHMARK(NoFalseSharing, iters) {
    struct GoodCounter {
        alignas(64) std::atomic<int> c1;
        char padding1[64 - sizeof(std::atomic<int>)];
        alignas(64) std::atomic<int> c2;
    } counter;

    // ... 相同的测试代码
}
```

---

**题目 3.4**：优化一个实际的数据结构布局。

**参考答案**：
```cpp
// 优化前
struct BadLayout {
    bool flag1;     // 1 字节
    // 7 字节填充
    long id;        // 8 字节
    int value;      // 4 字节
    // 4 字节填充
}; // 总大小：24 字节

// 优化后
struct GoodLayout {
    long id;        // 8 字节
    int value;      // 4 字节
    bool flag1;     // 1 字节
    // 3 字节填充
}; // 总大小：16 字节

// 节省：33% 内存
```

---

### 挑战题

**题目 3.5**：使用 cachegrind 分析程序的缓存命中率，并优化。

**参考答案**：
```bash
# 1. 运行 cachegrind
valgrind --tool=cachegrind ./program

# 2. 查看结果
cg_annotate cachegrind.out.<pid> | less

# 3. 关键指标
# - Ir: 指令读取次数
# - I1mr: L1 指令缓存未命中
# - LLmr: 最后一层缓存未命中
# - Dr: 数据读取次数
# - D1mr: L1 数据缓存未命中
# - Dw: 数据写入次数

# 4. 优化建议
# - 高 D1mr：考虑预取
# - 高 LLmr：考虑数据重排
# - 高 I1mr：考虑代码布局
```

---

## Day 4-5: F14 哈希表

### 基础题

**题目 4.1**：F14 的名字含义是什么？

**答案**：**F14 = Filtering 14 keys**
- 使用 14-way 探测
- 通过 SIMD 指令一次过滤 14 个键
- 负载因子可达 85.7%（12/14）

---

**题目 4.2**：F14 有哪几种存储策略？

**答案**：
1. **F14NodeMap**：间接存储，引用稳定
2. **F14ValueMap**：内联存储，最快
3. **F14VectorMap**：向量存储，内存高效
4. **F14FastMap**：自动选择

---

### 进阶题

**题目 4.3**：实现异构查找（Heterogeneous Lookup）。

**参考答案**：
```cpp
#include <folly/container/F14Map.h>
#include <folly/functional/Invoke.h>

// 定义透明哈希
using StringHash = folly::transparent<folly::Hasher<folly::StringPiece>>;
using StringEqual = folly::transparent<std::equal_to<folly::StringPiece>>;

// 使用透明哈希
folly::F14FastMap<std::string, int, StringHash, StringEqual> map;

// 现在可以直接用 StringPiece 查找
folly::StringPiece key = "hello";
map.find(key);  // 无需构造 std::string
```

---

**题目 4.4**：比较 F14Map 与 std::unordered_map 的性能。

**参考答案**：
```cpp
#include <folly/Benchmark.h>
#include <folly/container/F14Map.h>
#include <unordered_map>

BENCHMARK(F14_insert, iters) {
    folly::F14FastMap<int, int> map;
    for (size_t i = 0; i < iters; ++i) {
        map.insert({i % 10000, i});
    }
}

BENCHMARK(UnorderedMap_insert, iters) {
    std::unordered_map<int, int> map;
    for (size_t i = 0; i < iters; ++i) {
        map.insert({i % 10000, i});
    }
}

// 预期结果：F14Map 快 2-3 倍
```

---

### 挑战题

**题目 4.5**：实现 F14 标签过滤的简化版本。

**参考答案**：
```cpp
#include <emmintrin.h>  // SSE2

class SimpleF14Filter {
    uint8_t tags_[16];

public:
    void setTag(size_t index, uint8_t tag) {
        tags_[index] = tag;
    }

    bool findTag(uint8_t target_tag) const {
        // 加载 16 字节标签向量
        __m128i tag_vector = _mm_loadu_si128((__m128i*)tags_);

        // 并行比较目标标签与所有 14 个标签
        __m128i target = _mm_set1_epi8(target_tag);
        __m128i cmp = _mm_cmpeq_epi8(tag_vector, target);

        // 生成掩码
        uint16_t mask = _mm_movemask_epi8(cmp);

        // 过滤掉元数据字节和空槽
        mask &= 0x3FFF;  // 只保留低 14 位

        return mask != 0;
    }
};
```

---

## Day 6: Small Vector

### 基础题

**题目 6.1**：small_vector 的 SBO 是什么？

**答案**：
- **SBO = Small Buffer Optimization**（小缓冲区优化）
- 小数组存储在栈上（对象内部），而非堆
- 阈值 N：前 N 个元素零堆分配

---

**题目 6.2**：何时应该使用 small_vector？

**答案**：
- ✅ 小数组（< 10 个元素）
- ✅ 临时数组
- ✅ 函数局部数组
- ❌ 大数组（> 100 个元素）
- ❌ 需要引用稳定的场景

---

### 进阶题

**题目 6.3**：测试不同内联大小（N）的性能。

**参考答案**：
```cpp
#include <folly/Benchmark.h>
#include <folly/container/small_vector.h>

BENCHMARK(SmallVector_N4, iters) {
    folly::small_vector<int, 4> vec;
    for (size_t i = 0; i < 10; ++i) {
        vec.push_back(i);
    }
}

BENCHMARK(SmallVector_N8, iters) {
    folly::small_vector<int, 8> vec;
    for (size_t i = 0; i < 10; ++i) {
        vec.push_back(i);
    }
}

BENCHMARK(SmallVector_N16, iters) {
    folly::small_vector<int, 16> vec;
    for (size_t i = 0; i < 10; ++i) {
        vec.push_back(i);
    }
}

// 预期：N=16 最快（全部栈上）
```

---

**题目 6.4**：实现 small_vector 的简化版本。

**参考答案**：
```cpp
template <typename T, size_t N>
class simple_small_vector {
    union {
        struct {
            T* data_;
            size_t size_;
            size_t capacity_;
        } heap_;

        struct {
            unsigned char buffer_[N * sizeof(T)];
            size_t size_;
        } stack_;
    } u_;

    bool is_heap() const {
        return u_.stack_.size_ > N;
    }

public:
    void push_back(const T& value) {
        if (size() < capacity()) {
            // 仍有空间
            if (is_heap()) {
                new (&u_.heap_.data_[u_.heap_.size_]) T(value);
                u_.heap_.size_++;
            } else {
                new (&u_.stack_.buffer_[u_.stack_.size_ * sizeof(T)]) T(value);
                u_.stack_.size_++;
            }
        } else {
            // 需要增长（省略）
        }
    }

    size_t size() const {
        return is_heap() ? u_.heap_.size_ : u_.stack_.size_;
    }

    size_t capacity() const {
        return is_heap() ? u_.heap_.capacity_ : N;
    }

    T& operator[](size_t index) {
        if (is_heap()) {
            return u_.heap_.data_[index];
        } else {
            return *reinterpret_cast<T*>(
                &u_.stack_.buffer_[index * sizeof(T)]
            );
        }
    }
};
```

---

## Day 7: Arena

### 基础题

**题目 7.1**：Arena 分配器的主要优势是什么？

**答案**：
- **批量分配**：减少 malloc 调用
- **统一释放**：无需追踪单个对象
- **提高局部性**：相关对象存储在一起

---

**题目 7.2**：如何使用 Arena？

**参考答案**：
```cpp
#include <folly/memory/Arena.h>

folly::SysArena arena;

// 分配
void* ptr1 = arena.allocate(64);
void* ptr2 = arena.allocate(128);

// 无需单独释放
// Arena 析构时统一释放所有内存
```

---

### 进阶题

**题目 7.3**：比较 Arena vs malloc 的性能。

**参考答案**：
```cpp
#include <folly/Benchmark.h>
#include <folly/memory/Arena.h>

BENCHMARK(Arena_allocate, iters) {
    folly::SysArena arena;
    for (size_t i = 0; i < iters; ++i) {
        arena.allocate(64);
    }
    // Arena 析构时统一释放
}

BENCHMARK(Malloc_allocate, iters) {
    std::vector<void*> ptrs;
    ptrs.reserve(iters);

    for (size_t i = 0; i < iters; ++i) {
        ptrs.push_back(malloc(64));
    }

    for (void* ptr : ptrs) {
        free(ptr);
    }
}

// 预期：Arena 快 5-10 倍
```

---

**题目 7.4**：设计一个支持对象复用的 Arena。

**参考答案**：
```cpp
template <typename T>
class ObjectArena {
    folly::SysArena arena_;
    std::vector<T*> free_list_;

public:
    template <typename... Args>
    T* create(Args&&... args) {
        if (!free_list_.empty()) {
            T* obj = free_list_.back();
            free_list_.pop_back();
            new (obj) T(std::forward<Args>(args)...);
            return obj;
        }

        void* mem = arena_.allocate(sizeof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }

    void destroy(T* obj) {
        obj->~T();
        free_list_.push_back(obj);
    }

    // 所有对象在 arena 析构时统一释放
};
```

---

## Day 8: Baton

### 基础题

**题目 8.1**：Baton 比 condition_variable 快的原因是什么？

**答案**：
- **更小**：只有 4 字节
- **更简单**：单次手放（post + wait）
- **更高效**：使用 futex，快速路径无系统调用

---

**题目 8.2**：如何使用 Baton？

**参考答案**：
```cpp
#include <folly/synchronization/Baton.h>

folly::Baton<> baton;

// 线程 1：等待
baton.wait();  // 阻塞直到 post()

// 线程 2：唤醒
baton.post();  // 唤醒等待的线程
```

---

### 进阶题

**题目 8.3**：实现一个简单的 Barrier（屏障）。

**参考答案**：
```cpp
#include <folly/synchronization/Baton.h>
#include <vector>

class SimpleBarrier {
    std::vector<folly::Baton<>> batons_;
    size_t count_;

public:
    SimpleBarrier(size_t n) : batons_(n), count_(n) {}

    void wait() {
        // 唤醒其他线程
        for (auto& b : batons_) {
            b.post();
        }

        // 等待其他线程
        for (auto& b : batons_) {
            b.wait();
        }
    }
};
```

---

**题目 8.4**：实现支持超时的 Baton。

**参考答案**：
```cpp
#include <folly/synchronization/Baton.h>
#include <chrono>

class TimeoutBaton {
    folly::Baton<> baton_;
    std::atomic<bool> posted_{false};

public:
    bool wait(std::chrono::milliseconds timeout) {
        // 轮询检查
        auto start = std::chrono::steady_clock::now();

        while (!posted_.load()) {
            if (baton_.try_wait_for(timeout / 10)) {
                return true;
            }

            auto elapsed = std::chrono::steady_clock::now() - start;
            if (elapsed >= timeout) {
                return false;  // 超时
            }
        }

        return true;
    }

    void post() {
        posted_.store(true);
        baton_.post();
    }
};
```

---

## Day 9: AtomicHashMap

### 基础题

**题目 9.1**：AtomicHashMap 的查找是 Wait-Free 的吗？

**答案**：
- ✅ **查找是 Wait-Free**：固定步数内完成
- ❌ **插入是 Lock-Free**：可能 CAS 重试

---

**题目 9.2**：AtomicHashMap 的大小是固定的吗？

**答案**：
- ✅ **是的**，容量固定
- ✅ 原因：为了无锁设计
- ⚠️ 解决方案：使用多层 AHMap 或重新创建

---

### 进阶题

**题目 9.3**：实现简化版的 AtomicHashMap。

**参考答案**：
```cpp
#include <atomic>
#include <vector>

template <typename Key, typename Value>
class SimpleAtomicHashMap {
    struct Entry {
        std::atomic<Key> key_;
        Value value_;

        static constexpr Key kEmptyKey = Key(-1);
    };

    std::unique_ptr<Entry[]> entries_;
    size_t capacity_;
    size_t mask_;

public:
    SimpleAtomicHashMap(size_t capacity)
        : capacity_(capacity)
        , mask_(capacity - 1)
    {
        entries_ = std::make_unique<Entry[]>(capacity_);
    }

    Value* find(Key key) {
        size_t index = hash(key) & mask_;

        for (size_t i = 0; i < capacity_; ++i) {
            Entry& entry = entries_[index];

            Key found = entry.key_.load(std::memory_order_relaxed);
            if (found == key) {
                return &entry.value_;
            }

            if (found == Entry::kEmptyKey) {
                return nullptr;
            }

            index = (index + 1) & mask_;
        }

        return nullptr;
    }

    bool insert(Key key, const Value& value) {
        size_t index = hash(key) & mask_;

        for (size_t i = 0; i < capacity_; ++i) {
            Entry& entry = entries_[index];

            Key expected = Entry::kEmptyKey;
            if (entry.key_.compare_exchange_strong(
                    expected, key,
                    std::memory_order_release,
                    std::memory_order_relaxed)) {
                entry.value_ = value;
                return true;
            }

            if (expected == key) {
                return false;  // 已存在
            }

            index = (index + 1) & mask_;
        }

        return false;  // 表满
    }
};
```

---

## Day 10-14: 简化题目

由于篇幅限制，这里只提供部分题目的简化版本。完整答案请参考相关课程。

### Day 10: Hazard Pointers

**题目 10.1**：Hazard Pointers 解决什么问题？
**答案**：无锁数据结构的内存回收问题

### Day 11: EventBase

**题目 11.1**：EventBase 是什么？
**答案**：事件循环，基于 libevent

### Day 12: 协程

**题目 12.1**：co_await 的作用是什么？
**答案**：等待异步操作完成

### Day 13: 性能测量

**题目 13.1**：如何使用 folly/Benchmark.h？
**答案**：
```cpp
BENCHMARK(test_name, iters) {
    // 测试代码
}
```

### Day 14: 综合项目

**题目 14.1**：设计高性能日志系统需要考虑什么？
**答案**：
- 无锁队列
- 批量刷新
- 异步 I/O
- 内存优化

---

## 总结

本习题集涵盖了 Folly 课程的核心知识点：

1. **基础概念**：巩固理论学习
2. **代码实践**：动手编写代码
3. **性能分析**：使用工具优化
4. **系统设计**：综合应用知识

**学习建议**：
- 每天完成对应天的习题
- 先做基础题，再做进阶题
- 挑战题可选，深入研究者必做
- 对比答案，理解原理

**下一步**：
- 完成所有基础题
- 选择感兴趣的进阶题
- 阅读源码验证答案
- 在实际项目中应用

祝你学习进步！🚀
