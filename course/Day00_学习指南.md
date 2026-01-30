# Folly 深度学习课程 - 学习指南

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

## 学习路线图

### 第一周：基础篇（Day 1-7）

#### Day 1: Folly 架构概览与构建系统
**难度：⭐**
**重要性：⭐⭐⭐⭐⭐**

- 理解 Folly 的设计哲学
- 掌握 CMake 构建系统
- 学会编译和测试 Folly
- **重点**：getdeps.py 的使用

**前置知识**：CMake 基础
**预计时间**：2-3 小时

---

#### Day 2: 分支预测与编译器优化提示
**难度：⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解 CPU 流水线原理
- 掌握 FOLLY_LIKELY/UNLIKELY 宏
- 学习编译器优化属性
- **重点**：__builtin_expect 的工作原理

**前置知识**：计算机组成原理
**预计时间**：3-4 小时

---

#### Day 3: 内存对齐与缓存友好设计
**难度：⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 理解内存对齐的重要性
- 掌握缓存行（Cache Line）优化
- 学习避免伪共享（False Sharing）
- **重点**：alignas 和缓存行对齐

**前置知识**：CPU 缓存层次结构
**预计时间**：4-5 小时

---

#### Day 4-5: F14 哈希表深度剖析
**难度：⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 理解 F14 的设计理念
- 掌握 SIMD 向量过滤技术
- 学习双重哈希冲突解决策略
- 理解四种存储策略（Node/Value/Vector/Fast）
- **重点**：SIMD 并行比较和标签系统

**前置知识**：哈希表基础、SIMD 指令
**预计时间**：6-8 小时（两天）

---

#### Day 6: Small Vector 与 SBO 深度剖析
**难度：⭐⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解小缓冲区优化（SBO）的设计原理
- 掌握 small_vector 的实现细节
- 学习平台特定的优化技巧
- **重点**：union 存储和栈堆转换

**前置知识**：C++ 内存管理
**预计时间**：3-4 小时

---

#### Day 7: Arena 内存分配器
**难度：⭐⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解 Arena 分配器的设计理念
- 掌握批量分配技术
- 学习内存池和重用策略
- **重点**：块大小选择和大对象优化

**前置知识**：内存分配器（allocator）
**预计时间**：3-4 小时

---

### 第二周：高级篇（Day 8-14）

#### Day 8: 同步原语 - Baton
**难度：⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解轻量级同步原语的设计
- 掌握 Baton 的实现原理
- 学习 futex 和无锁技术
- **重点**：futex 系统调用和状态机

**前置知识**：多线程编程、系统调用
**预计时间**：4-5 小时

---

#### Day 9: 原子哈希表（AtomicHashMap）
**难度：⭐⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解无锁数据结构的设计挑战
- 掌握 AtomicHashMap 的实现策略
- 学习 Wait-Free 技术
- **重点**：CAS 操作和线性探测

**前置知识**：C++ 原子操作、无锁编程
**预计时间**：5-6 小时

---

#### Day 10: Hazard Pointers（危险指针）
**难度：⭐⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐**

- 理解无锁数据结构的内存回收问题
- 掌握 Hazard Pointer 的实现原理
- 学习 ABA 问题的解决方案
- **重点**：延迟回收和批量检查

**前置知识**：无锁编程、ABA 问题
**预计时间**：5-6 小时

---

#### Day 11: EventBase 与异步 I/O
**难度：⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 理解事件驱动的编程模型
- 掌握 EventBase 的实现原理
- 学习异步 I/O 的性能优化
- **重点**：事件循环和 libevent

**前置知识**：异步 I/O、事件驱动编程
**预计时间**：4-5 小时

---

#### Day 12: C++20 协程与 Task
**难度：⭐⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 理解协程的基本概念
- 掌握 folly::coro::Task 的实现
- 学习协程的性能优化
- **重点**：co_await 机制和协程帧

**前置知识**：C++20 协程、异步编程
**预计时间**：6-8 小时

---

#### Day 13: 性能测量与优化技巧
**难度：⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 掌握微基准测试的编写方法
- 学习性能分析工具的使用
- 理解常见的性能陷阱
- **重点**：folly/Benchmark.h 和 perf 工具

**前置知识**：性能分析
**预计时间**：4-5 小时

---

#### Day 14: 综合项目与最佳实践
**难度：⭐⭐⭐⭐**
**重要性：⭐⭐⭐⭐⭐**

- 将所学知识整合到实际项目中
- 理解 Folly 在生产环境中的使用
- 掌握高性能 C++ 编程的最佳实践
- **重点**：综合应用和性能优化

**前置知识**：全部前面的内容
**预计时间**：6-8 小时

---

## 学习策略

### 1. 理论与实践结合

**每天的学习流程**：

```
1. 阅读基础版课程（30-45 分钟）
   ↓
2. 阅读 Folly 源码（30-45 分钟）
   ↓
3. 完成课后作业（1-2 小时）
   ↓
4. 阅读增强版课程（可选，30-45 分钟）
   ↓
5. 实验和探索（1-2 小时）
```

### 2. 源码阅读方法

**推荐的源码阅读顺序**：

```cpp
// 1. 先看公共接口（.h 文件）
#include <folly/container/F14Map.h>
// 理解 API 设计和使用方法

// 2. 再看实现细节（.cpp 文件）
// folly/container/F14Map.cpp
// 理解具体实现算法

// 3. 关键实现深入分析
// folly/container/detail/F14Detail.h
// 理解底层优化技巧
```

**源码阅读工具**：
- **IDE**：CLion、VS Code（配合 C/C++ 插件）
- **代码导航**：ctags、cscope
- **可视化**：Understand、Doxygen

### 3. 实验环境准备

**必需工具**：

```bash
# 1. 编译工具链
sudo apt install build-essential cmake g++-10

# 2. 性能分析工具
sudo apt install perf linux-tools-generic valgrind

# 3. Folly 依赖
sudo ./build/fbcode_builder/getdeps.py install-system-deps --recursive

# 4. 基准测试框架
git clone https://github.com/google/benchmark.git
```

**可选工具**：

```bash
# 火焰图生成
git clone https://github.com/brendangregg/FlameGraph

# 缓存分析
sudo apt install cachegrind kcachegrind

# 汇编查看
sudo apt install binutils
```

### 4. 学习资源

**官方资源**：
- Folly GitHub：https://github.com/facebook/folly
- Folly 文档：https://facebook.github.io/folly/
- C++ 参考：https://en.cppreference.com/

**推荐书籍**：
- "C++ Concurrency in Action" by Anthony Williams
- "The Art of Multiprocessor Programming" by Herlihy & Shavit
- "Computer Systems: A Programmer's Perspective" by Bryant & O'Hallaron

**在线资源**：
- Intel 优化手册：https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
- LLVM 编译器文档：https://llvm.org/docs/
- Linux perf wiki：https://perf.wiki.kernel.org/

---

## 学习检查点

### Week 1 检查点

**完成第 1 周后，你应该能够**：

- ✅ 成功编译和运行 Folly
- ✅ 理解 FOLLY_LIKELY/UNLIKELY 的使用场景
- ✅ 解释伪共享及其危害
- ✅ 实现 F14 哈希表的简化版本
- ✅ 使用 small_vector 替代 std::vector
- ✅ 应用 Arena 优化内存分配

**自测题**：
1. 为什么 F14 使用 14-way 探测？
2. 如何避免多线程程序中的伪共享？
3. small_vector 相比 std::vector 的优势是什么？

---

### Week 2 检查点

**完成第 2 周后，你应该能够**：

- ✅ 理解 Baton 的状态机和 futex 机制
- ✅ 实现 Wait-Free 的查找操作
- ✅ 使用 Hazard Pointers 安全回收内存
- ✅ 编写基于 EventBase 的异步程序
- ✅ 使用 C++20 协程编写异步代码
- ✅ 使用 perf 分析程序性能瓶颈
- ✅ 应用 Folly 最佳实践优化代码

**综合项目**：
- 设计并实现一个高性能日志系统
- 性能目标：> 1M 条/秒，P99 < 1μs

---

## 常见问题

### Q1: 学习曲线陡峭怎么办？

**A**: 分层次学习：
1. **基础版**：理解概念和使用方法
2. **增强版**：深入原理和优化技巧
3. **源码**：研究实现细节

不要急于求成，先理解再深入。

---

### Q2: 汇编代码看不懂怎么办？

**A**:
1. 先从简单的函数开始
2. 使用在线资源：x86-64 Assembly Reference
3. 使用 Compiler Explorer (godbolt.org) 可视化
4. 关注关键指令：mov, cmp, jmp, call

---

### Q3: 性能测试结果不一致？

**A**:
1. 多次运行取平均值
2. 关闭后台程序
3. 使用 CPU 性能模式（performance governor）
4. 固定 CPU 频率
5. 使用足够大的样本量

```bash
# 固定 CPU 频率
sudo cpupower frequency-set -g performance

# 绑定到特定 CPU
taskset -c 0 ./benchmark
```

---

### Q4: 如何验证学习效果？

**A**:
1. **课后作业**：完成每天的作业
2. **源码阅读**：跟踪关键代码路径
3. **性能测试**：编写 benchmark 验证理论
4. **实际应用**：在自己的项目中应用
5. **教学输出**：向他人解释学到的知识

---

## 进阶路径

完成基础课程后，可以继续深入：

### Level 1: Folly 专家（3-6 个月）

- 深入研究每个组件的实现
- 贡献 Folly 开源项目
- 优化现有组件的性能
- 设计新的高性能组件

### Level 2: 性能工程师（6-12 个月）

- 精通性能分析工具
- 理解 CPU 微架构
- 掌握编译器优化技术
- 设计性能测试框架

### Level 3: 系统架构师（1-2 年）

- 设计高性能系统架构
- 平衡性能与可维护性
- 跨平台性能优化
- 性能基准和标准制定

---

## 学习社区

**参与方式**：

- **GitHub**：提交 Issue 和 PR
- **Stack Overflow**：提问和回答
- **Reddit**：r/cpp, r/performance
- **会议**：CppCon, Meeting C++

**中文社区**：

- **知乎**：关注"C++ 高性能编程"话题
- **博客园**：搜索 Folly 相关博客
- **GitHub CN**：参与中文讨论

---

## 学习时间规划

### 全职学习（2 周）

```
每天 8 小时：
- 理论学习：3 小时
- 源码阅读：2 小时
- 实践编程：3 小时
```

### 业余学习（4-6 周）

```
每天 2-3 小时：
- 工作日：理论学习 + 作业
- 周末：源码阅读 + 实验
```

### 快速预览（1 周）

```
每天 4 小时：
- 只阅读基础版
- 跳过增强版
- 选择性完成作业
```

---

## 学习成果展示

完成课程后，你可以：

1. **技术博客**：撰写学习笔记和心得
2. **开源项目**：贡献 Folly 或相关项目
3. **技术分享**：在公司或社区做分享
4. **性能优化**：优化实际项目性能
5. **面试准备**：展示深入理解能力

---

## 结语

高性能 C++ 编程是一个持续学习的过程。Folly 作为工业级的高性能库，提供了大量值得学习的实践。通过本课程，你将建立扎实的性能优化基础，为后续的深入学习和实践做好准备。

**记住**：
- 📖 **理论结合实践**：不要只看书，要动手写代码
- 🔍 **测量优于猜测**：用数据说话，不要盲目优化
- 🤝 **社区交流**：参与讨论，分享经验
- 🚀 **持续学习**：技术不断演进，保持好奇心

祝你学习愉快！

---

**下一步**：开始 [Day 1: Folly 架构概览与构建系统](./Day01_Folly架构概览与构建系统.md) 🎯
