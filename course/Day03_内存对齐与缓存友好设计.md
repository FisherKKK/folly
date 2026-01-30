# Folly 深度学习课程：高性能 C++ 编程的 14 天之旅

## 课程简介

本课程将带你深入探索 Facebook 开源的高性能 C++ 库 **Folly** (Facebook Open-source Library) 的底层实现和性能优化技巧。通过 14 天的系统学习，你将掌握：

- Folly 的核心架构设计理念
- 高性能数据结构的实现原理
- 内存分配和缓存优化策略
- 并发编程和同步原语
- 异步 I/O 和协程框架
- 平台特定的优化技巧

**前置知识要求：**
- 熟悉 C++17/20 基础语法
- 了解数据结构与算法基础
- 有一定的多线程编程经验
- 了解基本的计算机体系结构（缓存、内存对齐等）

---

# 第 3 天：内存对齐与缓存友好设计

## 学习目标
- 理解内存对齐的重要性
- 掌握缓存行（Cache Line）概念
- 学习避免伪共享（False Sharing）的技巧

## 核心内容

### 3.1 内存对齐基础

**为什么需要对齐？**
- 未对齐的访问可能需要多次内存访问
- 某些指令（如 SIMD）要求严格对齐
- 原子操作通常需要对齐

**Folly 的对齐工具**：

```cpp
#include <folly/lang/Align.h>

// 获取类型的对齐要求
constexpr size_t align = folly::align_of<int>::value;

// 对齐指针
void* aligned_ptr = folly::align_up(ptr, 64);

// 分配对齐内存
void* mem = folly::aligned_malloc(1024, 64);
folly::aligned_free(mem);
```

### 3.2 缓存行优化

**关键概念**：
- **缓存行大小**：通常是 64 字节（x86-64）
- **伪共享**：多个线程修改同一缓存行的不同数据

```cpp
// 不好的设计：伪共享
struct BadCounter {
    std::atomic<int> thread1_count;  // 偏移 0
    std::atomic<int> thread2_count;  // 偏移 4 - 同一缓存行！
};

// 好的设计：避免伪共享
struct GoodCounter {
    alignas(64) std::atomic<int> thread1_count;
    char padding1[64 - sizeof(std::atomic<int>)];

    alignas(64) std::atomic<int> thread2_count;
    char padding2[64 - sizeof(std::atomic<int>)];
};
```

**Folly 的缓存行工具**：

```cpp
#include <folly/lang/Align.h>

// 获取缓存行大小
constexpr size_t kCacheLineSize = folly::kCachelineLineSize;  // 通常是 64

// 缓存行对齐的类
struct FOLLY_ALIGNAS(kCacheLineSize) AlignedStruct {
    int data[16];
};
```

### 3.3 小缓冲区优化（Small Buffer Optimization, SBO）

Folly 的 `small_vector` 实现了 SBO：

```cpp
#include <folly/container/small_vector.h>

// small_vector 在栈上存储小数组，避免堆分配
folly::small_vector<int, 8> vec;  // 前 8 个元素在栈上

vec.push_back(1);   // 无堆分配
vec.push_back(2);   // 无堆分配
// ...
vec.push_back(9);   // 第 9 个元素时才分配堆内存
```

**SBO 的优势**：
1. **减少堆分配**：小数组零开销
2. **提高缓存局部性**：栈上数据访问更快
3. **减少内存碎片**：避免大量小分配

**实现原理**（简化）：

```cpp
template <typename T, size_t N>
class small_vector {
    union {
        struct {
            T* data_;
            size_t size_;
            size_t capacity_;
        } heap_;  // 堆模式

        struct {
            unsigned char buffer_[N * sizeof(T)];
            size_t size_;
        } stack_;  // 栈模式
    };

    bool is_heap_allocated() const {
        return size_ > N;
    }
};
```

### 3.4 数据结构布局优化

**原则 1：将常用数据放在一起**

```cpp
// 不好的布局
struct BadLayout {
    bool flag1;     // 偏移 0
    char padding[7];
    int value;      // 偏移 8
    bool flag2;     // 偏移 12
    char padding2[7];
    long id;        // 偏移 16-24
};

// 好的布局
struct GoodLayout {
    long id;        // 8 字节，偏移 0
    int value;      // 4 字节，偏移 8
    bool flag1;     // 1 字节，偏移 12
    bool flag2;     // 1 字节，偏移 13
    // padding 6 字节
};
```

**原则 2：按访问模式排序**

```cpp
// 热数据（频繁访问）在前，冷数据（不常访问）在后
struct CacheFriendly {
    // 热数据
    int frequently_accessed;
    int also_often_used;

    // 冷数据
    int rarely_accessed;
    int debug_info;
};
```

## 性优启示 #3：缓存是关键

现代 CPU 的性能瓶颈通常是**内存访问**，而非计算：
1. **L1 缓存**：~4 周期访问
2. **L2 缓存**：~12 周期访问
3. **L3 缓存**：~40 周期访问
4. **主内存**：~200+ 周期访问

**策略**：
- 将相关数据紧凑排列
- 使用 SBO 避免间接访问
- 对齐到缓存行边界
- 避免伪共享

## 课后作业

1. 编写微基准测试，测量伪共享的性能影响
2. 实现 SBO 的简化版 `small_vector`
3. 使用 `perf` 工具分析程序的缓存命中率

---

**第 3 天完。明天见！**
