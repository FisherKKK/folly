# Folly 深度学习课程 - 快速导航

欢迎来到 **Folly 深度学习课程**！这是一个专注于高性能 C++ 编程的 14 天系统学习课程，深入探索 Facebook 开源库 Folly 的设计理念和实现技巧。

---

## 📚 课程概览

### 课程结构

```
course/
├── 📖 README.md (本文件)
├── 🎯 Day00_学习指南.md           # 从这里开始！
├── 📑 INDEX.md                   # 综合索引（新！）
│
├── 📚 配套资源
│   ├── 📊 EXERCISES.md           # 14天习题集与答案
│   ├── 📋 QUICK_REFERENCE.md     # 组件速查表
│   ├── 🔧 TROUBLESHOOTING.md     # 故障排查指南
│   ├── 🎨 VISUAL_GUIDE.md        # 可视化学习指南
│   ├── 💡 PROJECT_IDEAS.md       # 实战项目 ideas
│   ├── ✅ PROGRESS_TRACKER.md    # 学习进度跟踪
│   ├── 💻 CODE_EXAMPLES.md       # 代码示例集
│   ├── 📝 PRODUCTION_CHECKLIST.md # 生产环境清单
│   ├── ⚡ QUICKSTART.md          # 5分钟快速入门
│   ├── ❓ INTERVIEW_QUESTIONS.md # 面试问题集合
│   ├── 📖 GLOSSARY.md            # 术语表
│   ├── ❔ FAQ.md                 # 常见问题
│   └── ⚠️  COMMON_PITFALLS.md     # 常见错误和陷阱
│
├── 基础版课程（14天）
│   ├── Day01-14: 核心概念和用法
│   └── 📄 性能优化最佳实践_综合指南.md
│
└── 增强版课程（15天）
    ├── Day01-14: 深度技术解析
    └── 包含实战案例和性能分析
```

---

## 🚀 快速开始

### 🌟 5分钟快速上手

**第一次接触 Folly？** 从这里开始：

1. **[📑 INDEX.md](./INDEX.md)** ⭐ 快速找到你需要的文档
2. **[⚡ 5分钟快速入门](./QUICKSTART.md)** → 在 5 分钟内：
3. **[Day00: 学习指南](./Day00_学习指南.md)** → 完整学习路径

### 1. 学习路径选择

#### 🌱 初学者路径（2-4 周）
```
Day00 (学习指南)
    ↓
Day01-14 基础版
    ↓
选择感兴趣的增强版深入阅读
    ↓
完成实战项目
```

#### ⚡ 快速预览路径（1 周）
```
Day00 (学习指南)
    ↓
Day01, Day03, Day04, Day07, Day11, Day12 (核心组件)
    ↓
Day14 (综合项目)
```

#### 🎓 深度学习路径（4-6 周）
```
Day00 (学习指南)
    ↓
Day01-14 基础版 + 增强版（每天学习两版）
    ↓
阅读源码
    ↓
完成所有课后作业
    ↓
实战项目
```

---

## 📋 课程大纲

### 第一周：基础篇

| 天 | 主题 | 核心组件 | 难度 |
|----|------|----------|------|
| Day 1 | [Folly 架构概览与构建系统](./Day01_Folly架构概览与构建系统.md) | 构建系统，目录结构 | ⭐ |
| Day 2 | [分支预测与编译器优化](./Day02_分支预测与编译器优化提示.md) | FOLLY_LIKELY, 内联 | ⭐⭐ |
| Day 3 | [内存对齐与缓存友好设计](./Day03_内存对齐与缓存友好设计.md) | 缓存行，伪共享 | ⭐⭐⭐ |
| Day 4-5 | [F14 哈希表深度剖析](./Day04_F14哈希表深度剖析上.md) | F14Map, SIMD | ⭐⭐⭐⭐ |
| Day 6 | [Small Vector 与 SBO](./Day06_Small_Vector与SBO深度剖析.md) | small_vector | ⭐⭐⭐ |
| Day 7 | [Arena 内存分配器](./Day07_Arena内存分配器.md) | Arena | ⭐⭐⭐ |

### 第二周：高级篇

| 天 | 主题 | 核心组件 | 难度 |
|----|------|----------|------|
| Day 8 | [同步原语 - Baton](./Day08_同步原语Baton.md) | Baton, futex | ⭐⭐⭐⭐ |
| Day 9 | [原子哈希表](./Day09_原子哈希表AtomicHashMap.md) | AtomicHashMap | ⭐⭐⭐⭐⭐ |
| Day 10 | [Hazard Pointers](./Day10_Hazard_Pointers危险指针.md) | Hazptr | ⭐⭐⭐⭐⭐ |
| Day 11 | [EventBase 与异步 I/O](./Day11_EventBase与异步IO.md) | EventBase | ⭐⭐⭐⭐ |
| Day 12 | [C++20 协程与 Task](./Day12_Cpp20协程与Task.md) | Task, co_await | ⭐⭐⭐⭐⭐ |
| Day 13 | [性能测量与优化](./Day13_性能测量与优化技巧.md) | Benchmark, perf | ⭐⭐⭐ |
| Day 14 | [综合项目与最佳实践](./Day14_综合项目与最佳实践.md) | 完整项目 | ⭐⭐⭐⭐ |

---

## 🎯 按主题学习

### 数据结构

- **[F14 哈希表](./Day04_F14哈希表深度剖析上.md)** ⭐⭐⭐⭐⭐
  - 为什么比 std::unordered_map 快 2-3 倍
  - SIMD 向量过滤技术
  - 四种存储策略选择

- **[small_vector](./Day06_Small_Vector与SBO深度剖析.md)** ⭐⭐⭐⭐
  - 小缓冲区优化（SBO）
  - 零堆分配的数组容器
  - 实际应用场景

### 内存管理

- **[Arena 分配器](./Day07_Arena内存分配器.md)** ⭐⭐⭐⭐
  - 批量分配，统一释放
  - 减少 malloc 开销
  - 提高缓存局部性

- **[内存对齐与缓存](./Day03_内存对齐与缓存友好设计.md)** ⭐⭐⭐⭐⭐
  - 避免伪共享
  - 缓存行对齐
  - 数据布局优化

### 并发编程

- **[Baton 同步原语](./Day08_同步原语Baton.md)** ⭐⭐⭐⭐
  - 轻量级一次性同步
  - 基于 futex 实现
  - 比 condition_variable 快 5-10 倍

- **[AtomicHashMap](./Day09_原子哈希表AtomicHashMap.md)** ⭐⭐⭐⭐⭐
  - Wait-Free 查找
  - Lock-Free 设计
  - 并发哈希表实现

- **[Hazard Pointers](./Day10_Hazard_Pointers危险指针.md)** ⭐⭐⭐⭐⭐
  - 无锁内存回收
  - 解决 ABA 问题
  - 延迟回收策略

### 异步编程

- **[EventBase](./Day11_EventBase与异步IO.md)** ⭐⭐⭐⭐⭐
  - 事件驱动架构
  - 异步 I/O 框架
  - 高性能网络编程

- **[C++20 协程](./Day12_Cpp20协程与Task.md)** ⭐⭐⭐⭐⭐
  - folly::coro::Task
  - 协程帧原理
  - 异步编程优雅方案

### 性能优化

- **[分支预测](./Day02_分支预测与编译器优化提示.md)** ⭐⭐⭐⭐
  - FOLLY_LIKELY/UNLIKELY
  - CPU 流水线优化
  - 编译器优化属性

- **[性能测量](./Day13_性能测量与优化技巧.md)** ⭐⭐⭐⭐⭐
  - 微基准测试
  - perf 性能分析
  - 优化方法论

---

## 💡 实战资源

### 代码示例

```bash
# 示例 1：使用 F14Map
#include <folly/container/F14Map.h>

folly::F14FastMap<std::string, int> map;
map["hello"] = 42;
auto it = map.find("hello");  // 无需构造临时对象！

# 示例 2：使用 small_vector
#include <folly/container/small_vector.h>

folly::small_vector<int, 8> vec;  // 前 8 个元素在栈上
vec.push_back(1);  // 零堆分配
```

### 性能对比表

| 组件 | 替代标准库 | 性能提升 | 适用场景 |
|------|-----------|---------|----------|
| F14Map | unordered_map | 2-3x | 通用哈希表 |
| small_vector | vector | 7x (小数组) | 小数组优化 |
| Arena | malloc | 10x (批量) | 批量分配 |
| Baton | condition_variable | 5-10x | 一次性同步 |
| EventBase | - | - | 异步 I/O |

---

## 🛠️ 实用工具

### 性能分析工具

```bash
# 1. perf - CPU 性能分析
perf record ./program
perf report

# 2. valgrind - 内存分析
valgrind --tool=memcheck ./program
valgrind --tool=cachegrind ./program

# 3. flamegraph - 火焰图生成
perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
```

### 构建工具

```bash
# 使用 getdeps.py 构建
python3 ./build/fbcode_builder/getdeps.py build folly

# 使用 CMake 直接构建
mkdir _build && cd _build
cmake .. -DBUILD_TESTS=ON
make -j$(nproc)
```

---

## 📖 推荐阅读顺序

### 0. 快速查找（随时查阅）
- [📑 INDEX.md](./INDEX.md) ⭐ 综合索引，快速定位
- 按功能、按天数、按组件、按难度查找

### 1. 快速上手（1-2 天）
1. [⚡ 5分钟快速入门](./QUICKSTART.md) ⭐ 从这里开始！
2. [Day00: 学习指南](./Day00_学习指南.md)
3. [Day01: Folly 架构概览](./Day01_Folly架构概览与构建系统.md)
4. [📖 GLOSSARY: 术语表](./GLOSSARY.md)（遇到术语时查阅）
5. [🎨 VISUAL_GUIDE: 可视化学习](./VISUAL_GUIDE.md)（学习图表和流程）

### 2. 核心组件（1 周）
1. [Day04: F14 哈希表](./Day04_F14哈希表深度剖析上.md)
2. [Day06: small_vector](./Day06_Small_Vector与SBO深度剖析.md)
3. [Day07: Arena](./Day07_Arena内存分配器.md)
4. [Day11: EventBase](./Day11_EventBase与异步IO.md)
5. [💻 CODE_EXAMPLES: 代码示例](./CODE_EXAMPLES.md)（边学边练）

### 3. 深入学习（2-4 周）
- 完整阅读基础版 Day01-14
- 选择性阅读增强版
- 完成 [习题集](./EXERCISES.md)
- 阅读源码
- 使用 [✅ PROGRESS_TRACKER: 进度跟踪](./PROGRESS_TRACKER.md)

### 4. 实战准备（1-2 周）
- 查看 [实战项目 Ideas](./PROJECT_IDEAS.md)
- 阅读 [📝 PRODUCTION_CHECKLIST: 生产清单](./PRODUCTION_CHECKLIST.md)
- 准备面试：[❓ INTERVIEW_QUESTIONS](./INTERVIEW_QUESTIONS.md)
- 避免常见错误：[⚠️ COMMON_PITFALLS](./COMMON_PITFALLS.md)（新增）
- 遇到问题：[❔ FAQ](./FAQ.md)（新增）
- 选择适合的项目开始实践

---

## 🔗 外部资源

### 官方文档
- [Folly GitHub](https://github.com/facebook/folly)
- [Folly 文档](https://facebook.github.io/folly/)
- [Folly Wiki](https://github.com/facebook/folly/wiki)

### 相关书籍
- "C++ Concurrency in Action" by Anthony Williams
- "The Art of Multiprocessor Programming" by Herlihy & Shavit
- "Computer Systems: A Programmer's Perspective" by Bryant & O'Hallaron

### 在线资源
- [CppCon 演讲](https://www.youtube.com/user/CppCon)
- [C++ 标准](https://en.cppreference.com/)
- [Compiler Explorer](https://godbolt.org/)

---

## ❓ 常见问题

### Q: 我应该从哪里开始？
**A:** 从 [Day00: 学习指南](./Day00_学习指南.md) 开始！

### Q: 需要什么基础？
**A:**
- 熟悉 C++17/20 语法
- 了解数据结构与算法
- 有一定的多线程编程经验
- 了解计算机体系结构基础（缓存、内存对齐）

### Q: 课程难度如何？
**A:**
- 基础版：⭐⭐⭐ (中级)
- 增强版：⭐⭐⭐⭐ (高级)

### Q: 需要多长时间？
**A:**
- 快速预览：1 周
- 标准学习：2-4 周
- 深度学习：4-6 周

### Q: 如何实践？
**A:**
- 完成课后作业
- 阅读源码
- 在自己的项目中应用
- 贡献 Folly 开源社区

---

## 🎓 学习检查点

### Week 1 检查点
完成第 1 周后，你应该能够：
- ✅ 成功编译和运行 Folly
- ✅ 理解 FOLLY_LIKELY/UNLIKELY 的使用
- ✅ 解释伪共享及其危害
- ✅ 使用 F14Map 和 small_vector
- ✅ 应用 Arena 优化内存分配

### Week 2 检查点
完成第 2 周后，你应该能够：
- ✅ 使用 Baton 实现轻量级同步
- ✅ 理解 Wait-Free 的含义
- ✅ 使用 Hazard Pointers 安全回收内存
- ✅ 编写基于 EventBase 的异步程序
- ✅ 使用 C++20 协程编写异步代码
- ✅ 使用 perf 分析程序性能

---

## 📝 课程更新

### v1.0 (2024-01-30)
- ✅ 完成基础版课程（14天）
- ✅ 完成增强版课程（15天）
- ✅ 添加学习指南
- ✅ 添加实战案例

### 计划更新
- ⏳ 添加配套代码仓库
- ⏳ 添加习题集和答案
- ⏳ 添加视频教程
- ⏳ 添加在线练习环境

---

## 🤝 贡献

欢迎贡献！你可以：
- 报告错误和问题
- 提供改进建议
- 贡献新的实战案例
- 分享你的学习经验

---

## 📄 许可

本课程内容基于 Folly 开源项目，遵循 Apache 2.0 许可证。

---

## 🎉 开始学习

准备好了吗？让我们开始吧！

**👉 [从 Day00: 学习指南开始](./Day00_学习指南.md)**

或者

**👉 [直接从 Day01 开始](./Day01_Folly架构概览与构建系统.md)**

祝你学习愉快！🚀
