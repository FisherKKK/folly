# Folly 深度学习课程 - 第 6 天

# 第 6 天：Small Vector 与 SBO 深度剖析

## 学习目标
- 理解小缓冲区优化（SBO）的设计原理
- 掌握 `small_vector` 的实现细节
- 学习平台特定的优化技巧

## 核心内容

### 6.1 SBO 的动机

**问题**：标准 `std::vector` 的问题

```cpp
std::vector<int> vec;
vec.push_back(1);   // 堆分配！
vec.push_back(2);   // 即使只有 2 个元素
```

**代价**：
- 小数组也需要堆分配（malloc 开销）
- 缓存不友好（堆上的数据分散）
- 内存碎片（大量小分配）

### 6.2 small_vector 的设计

**核心思想**：利用对象的栈空间存储元素

```cpp
template <typename T, size_t N = 1>
class small_vector {
    union Storage {
        struct Heap {
            T* data_;
            size_t size_;
            size_t capacity_;
        } heap_;

        struct Stack {
            unsigned char buffer_[N * sizeof(T)];
            size_t size_;
        } stack_;
    } storage_;

    bool is_heap() const {
        return size() > N;
    }
};
```

**内存布局**：

```
small_vector<int, 4> 的内存布局：
+------------------+----------------------+
| Stack Mode       | Heap Mode            |
+------------------+----------------------+
| buffer_[16 bytes]| data_* (8 bytes)     | 0-7
| size_ (4 bytes)  | size_ (4 bytes)      | 8-11
| capacity_ (4)    | capacity_ (4)        | 12-15
+------------------+----------------------+
```

### 6.3 平台特定的优化

Folly 使用平台特定的打包优化：

```cpp
// folly/container/small_vector.h
#if (FOLLY_X64 || FOLLY_PPC64 || FOLLY_AARCH64 || FOLLY_RISCV64)
#define FOLLY_SV_PACK_ATTR FOLLY_PACK_ATTR  // 紧凑打包
#define FOLLY_SV_PACK_PUSH FOLLY_PACK_PUSH
#define FOLLY_SV_PACK_POP FOLLY_PACK_POP
#else
#define FOLLY_SV_PACK_ATTR  // 无打包
#define FOLLY_SV_PACK_PUSH
#define FOLLY_SV_PACK_POP
#endif

template <typename T, std::size_t N, class P>
class FOLLY_SV_PACK_ATTR small_vector {
    // ...
};
```

**效果**：
- **64 位平台**：紧凑打包，最小化填充
- **32 位平台**：正常对齐，避免未对齐访问问题

### 6.4 生长策略

**小 → 大转换**：

```cpp
void push_back(const T& value) {
    if (size() < capacity()) {
        // 仍在栈模式或堆有空间
        construct_at_end(value);
    } else {
        // 需要增长
        // 如果当前在栈模式，转移到堆
        // 如果在堆模式，重新分配
        value_type* new_data = allocate_and_copy(new_capacity);
        destroy_and_dealloc();
        data_ = new_data;
        capacity_ = new_capacity;
        construct_at_end(value);
    }
    ++size_;
}
```

**增长因子**：

```cpp
// Folly 使用 1.5x 增长（类似 std::vector）
size_t new_capacity = std::max(size_t(2), capacity() + capacity() / 2);
```

### 6.5 移动语义优化

**关键优化**：移动而非复制

```cpp
// 从栈转移到堆
void relocate_to_heap() {
    T* heap_data = allocate_heap(N * 2);  // 分配更大的堆内存

    // 使用移动构造函数
    for (size_t i = 0; i < size_; ++i) {
        new (&heap_data[i]) T(std::move(stack_buffer()[i]));
        stack_buffer()[i].~T();  // 析构栈上的对象
    }

    data_ = heap_data;
    capacity_ = N * 2;
}
```

**优势**：
- **O(1) 移动**：移动构造通常是指针/基本类型的复制
- **避免深层复制**：对于复杂类型很重要

### 6.6 迭代器失效规则

**small_vector 的迭代器失效**：

```cpp
folly::small_vector<int, 4> vec;

// 场景 1：栈模式，有空间
vec.push_back(1);
vec.push_back(2);
auto it = vec.begin();
vec.push_back(3);  // 迭代器仍然有效（仍在栈上）

// 场景 2：栈 → 堆转换
vec.push_back(4);
vec.push_back(5);  // 触发栈 → 堆！it 失效！

// 场景 3：堆模式，重新分配
vec.reserve(100);  // it 失效！
```

**规则**：
- **栈模式 + 不溢出**：迭代器稳定
- **栈 → 堆转换**：所有迭代器失效
- **堆模式 + 重新分配**：所有迭代器失效
- **与 std::vector 相同**：一旦在堆上，行为相同

### 6.7 SBO 的其他应用

**fbstring（Folly 的 string）**：

```cpp
#include <folly/FBString.h>

folly::fbstring str = "hello";  // SBO：存储在栈上
// 小字符串（< 23 字节）无堆分配

str = "a very long string that exceeds the small buffer optimization...";
// 触发堆分配
```

**FBString 的 SBO 布局**：

```cpp
class fbstring {
    union {
        struct {
            char* data_;
            size_t size_;
            size_t capacity_;
        } heap_;

        struct {
            char buffer_[23];
            unsigned char size_;  // 最高位标记模式
        } stack_;
    };
};
```

## 性优启示 #6：零开销抽象

SBO 展示了如何实现零开销抽象：
1. **快速路径优化**：小对象零开销
2. **透明转换**：自动在栈/堆之间切换
3. **类型安全**：不牺牲 C++ 的类型系统

## 课后作业

1. 实现 `small_vector` 的简化版本（支持 push_back 和 operator[]）
2. 比较不同内联大小（N=1, 4, 8, 16）的性能
3. 测试 SBO vs 堆分配的性能差异（使用微基准测试）

---

**第 6 天完。明天见！**
