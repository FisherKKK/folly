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

# 第 2 天：分支预测与编译器优化提示

## 学习目标
- 理解分支预测对性能的影响
- 掌握 Folly 的分支预测宏
- 学习编译器优化属性的使用

## 核心内容

### 2.1 为什么分支预测很重要？

现代 CPU 使用**流水线**执行指令。分支预测失败会导致：
1. 流水线清空（10-20 个周期损失）
2. CPU 无法乱序执行
3. 性能严重下降

**示例**：搜索操作中的分支

```cpp
// 不好的代码
bool find(const std::vector<int>& data, int target) {
    for (int x : data) {
        if (x == target) {  // 分支预测困难
            return true;
        }
    }
    return false;
}
```

### 2.2 FOLLY_LIKELY / FOLLY_UNLIKELY 宏

Folly 提供了分支预测提示（定义在 `folly/Likely.h`）：

```cpp
#define FOLLY_LIKELY(...) FOLLY_BUILTIN_EXPECT((__VA_ARGS__), 1)
#define FOLLY_UNLIKELY(...) FOLLY_BUILTIN_EXPECT((__VA_ARGS__), 0)
```

**使用场景**：

```cpp
#include <folly/Likely.h>

// 场景 1：错误处理是冷路径
void processData(Data* data) {
    if (FOLLY_UNLIKELY(data == nullptr)) {
        throw std::invalid_argument("null data");
    }
    // 热路径：编译器会优化这部分代码
    // ...
}

// 场景 2：常见情况优先
void handleRequest(Request* req) {
    if (FOLLY_LIKELY(req->isValid())) {
        // 快速路径
        processValidRequest(req);
    } else {
        // 慢速路径
        handleInvalidRequest(req);
    }
}
```

**汇编对比**：

```asm
; 不使用分支预测
test   rax, rax
je     .L_error_handler
; ...

; 使用 FOLLY_LIKELY
test   rax, rax
; 编译器会将 fast path 的代码线性排列
; 减少跳转指令
```

### 2.3 强制内联与禁止内联

```cpp
// folly/Portability.h
#define FOLLY_ALWAYS_INLINE __attribute__((always_inline)) inline
#define FOLLY_NOINLINE __attribute__((noinline))
```

**使用场景**：

```cpp
// 小函数：强制内联消除函数调用开销
FOLLY_ALWAYS_INLINE int add(int a, int b) {
    return a + b;
}

// 大函数或调试用：禁止内联
FOLLY_NOINLINE void debugTrace() {
    // 这个函数不会被内联
}
```

### 2.4 目标架构优化

```cpp
#define FOLLY_TARGET_ATTRIBUTE(target) __attribute__((__target__(target)))

// 只在支持 AVX2 的 CPU 上使用
FOLLY_TARGET_ATTRIBUTE("avx2")
void processVectorAVX2(float* data, size_t size) {
    // AVX2 指令
}
```

## 性优启示 #2：分支预测策略

1. **标记错误路径**：错误检查通常是不常见的
2. **标记热路径**：将最常见的执行路径线性化
3. **配置文件导向优化（PGO）**：使用真实数据收集分支统计

```bash
# GCC/Clang PGO 编译
gcc -fprofile-generate ./program
./program  # 运行典型 workload
gcc -fprofile-use -O3 ./program
```

## 课后作业

1. 编写一个微基准测试，比较使用 `FOLLY_LIKELY` 前后的性能差异
2. 阅读 `folly/Likely.h`，理解 `__builtin_expect` 的工作原理
3. 使用 `objdump -d` 查看编译器如何优化带有分支预测的代码

---

**第 2 天完。明天见！**
