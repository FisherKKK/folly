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

# 第 1 天：Folly 架构概览与构建系统

## 学习目标
- 理解 Folly 的设计哲学和架构原则
- 掌握 Folly 的构建系统
- 了解 Folly 与标准库和 Boost 的关系

## 核心内容

### 1.1 Folly 的设计哲学

**Folly 不是要取代标准库，而是补充它。**

Folly 的三个核心原则：

1. **性能优先**：只在现有方案（std、Boost）无法满足性能需求时才创建新组件
2. **实用性导向**：解决 Facebook 内部实际遇到的性能瓶颈
3. **无内部依赖限制**：Folly 模块可以使用任何其他 Folly 组件

### 1.2 平坦命名空间结构

Folly 采用独特的"平坦"目录结构：

```
folly/
├── container/          # 高性能容器
│   ├── F14Map.h
│   ├── small_vector.h
│   └── ...
├── synchronization/    # 同步原语
│   ├── Baton.h
│   ├── AtomicHashMap.h
│   └── ...
├── io/
│   └── async/         # 异步 I/O
│       ├── EventBase.h
│       └── AsyncSocket.h
├── coro/              # C++20 协程
├── memory/            # 内存管理
└── executors/         # 线程池
```

**关键点**：所有公共头文件都在 `folly/` 目录下，直接映射到 `folly::` 命名空间。

### 1.3 构建系统深度解析

Folly 使用 CMake 构建系统，有 **108 个粒度化库**：

```cmake
# 示例：定义一个 Folly 库
folly_add_library(
  container
  HEADERS
    folly/container/F14Map.h
    folly/container/small_vector.h
  SRCS
    folly/container/F14Map.cpp
  EXPORTED_DEPS
    folly:memory
    folly:lang
  EXTERNAL_DEPS
    boost
)
```

**关键设计**：
- **OBJECT 库**：源文件只编译一次，复用于多个目标
- **粒度化链接**：可以只链接需要的组件
- **EXCLUDE_FROM_MONOLITH**：排除从主 libfolly.a（用于 benchmark）

### 1.4 构建和测试

```bash
# 使用 getdeps.py 构建（推荐）
python3 ./build/fbcode_builder/getdeps.py --allow-system-packages build

# 直接使用 CMake
mkdir _build && cd _build
cmake .. -DBUILD_TESTS=ON
make -j$(nproc)

# 运行测试
ctest
```

## 性优启示 #1：构建系统优化

Folly 的构建系统本身就是一个性能优化的例子：
- **编译一次**：源文件编译为 OBJECT 库后复用
- **按需链接**：只链接实际使用的组件
- **并行构建**：充分利用多核

## 课后作业

1. 编译 Folly 并查看生成了多少个静态库文件
2. 查看 `folly/CMakeLists.txt`，找出最大的 5 个库
3. 理解为什么 Folly 选择不提供 ABI 兼容性保证

---

**第 1 天完。明天见！**
