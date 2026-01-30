# Folly 术语表

## 概述

本文档解释 Folly 中常见的术语、概念和缩写。

---

## 🔤 A-C

### ABI (Application Binary Interface)
应用程序二进制接口。**重要**：Folly 不保证 ABI 兼容性，每次提交都可能变化。因此应该静态链接 Folly。

```cpp
// 推荐：静态链接
target_link_libraries(myapp PRIVATE folly)

// 不推荐：动态链接（ABI 可能不兼容）
```

### Arena
内存分配器，用于批量分配相同生命周期的对象。Arena 分配的内存无法单独释放，必须整体释放。

**特点**：
- 分配：O(1)
- 释放：O(1)（整块）
- 无碎片

**参见**：Day07_Arena内存分配器.md

### AsyncSocket
Folly 的异步 Socket 实现，基于 EventBase。支持非阻塞的 TCP/UDP 连接。

**特点**：
- 事件驱动
- 零拷贝（使用 IOBuf）
- 跨线程回调

### AtomicHashMap
Wait-Free 并发哈希表。查找操作永不阻塞，插入/删除使用 CAS。

**限制**：
- 容量固定
- 不支持迭代
- 只支持等值查找

**参见**：Day09_原子哈希表AtomicHashMap.md

### Baton
轻量级同步原语，用于一次性事件通知。比 condition_variable 快 5-10 倍。

**用途**：
- 一次性初始化
- 生产者-消费者（单次）
- 线程启动信号

**参见**：Day08_同步原语Baton.md

---

## 🔤 D-F

### Executor
执行器接口，用于在线程池上执行任务。Folly 提供多种 Executor 实现。

**类型**：
- `CPUThreadPoolExecutor`：CPU 密集型任务
- `IOThreadPoolExecutor`：I/O 密集型任务
- `InlineExecutor`：同步执行
- `ManualExecutor`：手动驱动

**使用**：
```cpp
folly::CPUThreadPoolExecutor executor(4);
executor.add([]() {
    // 在线程池中执行
});
```

### F14
Folly 的第 14 代哈希表实现，使用 SIMD 和其他优化技术。

**命名**：F14 = Folly 14

**核心优化**：
1. SIMD 向量过滤
2. 双重哈希探测
3. 内存布局优化
4. 四种存储策略

**参见**：Day04-05_F14哈希表深度剖析.md

### Folly
Facebook Open-source Library 的缩写。发音为 "WAH-lee"（不是 "FOH-lee"）。

**设计理念**：
- 性能优先
- 实用性 > 通用性
- 暴露底层细节

### Futex (Fast Userspace muTEX)
Linux 特有的系统调用，用于高效的用户空间同步。Baton 等组件基于 futex 实现。

**优势**：
- 无竞争时不进入内核
- 比传统的 mutex 更快

---

## 🔤 G-L

### getdeps.py
Folly 的依赖管理和构建工具。自动下载、编译和安装 Folly 及其依赖。

**使用**：
```bash
# 构建
python3 ./build/fbcode_builder/getdeps.py build folly

# 测试
python3 ./build/fbcode_builder/getdeps.py test folly

# 安装系统依赖
python3 ./build/fbcode_builder/getdeps.py install-system-deps --recursive
```

**参见**：Day01_Folly架构概览与构建系统_增强版.md

### Hazptr (Hazard Pointers)
无锁内存回收机制，用于安全地回收可能被其他线程使用的内存。

**解决的问题**：ABA 问题

**工作原理**：
1. 保护：声明正在使用的指针
2. 检查：删除前检查是否有保护
3. 延迟回收：等待安全后回收

**参见**：Day10_Hazard_Pointers危险指针.md

### HHWheelTimer
O(1) 时间复杂度的定时器实现。使用时间轮数据结构。

**名字来源**：Hashed Hierarchical Wheel

**特点**：
- 插入：O(1)
- 触发：O(1)
- 内存占用小

**参见**：VISUAL_GUIDE.md

---

## 🔤 M-P

### Memory Ordering
内存序，定义原子操作的可见性和顺序约束。

**类型**：
- `relaxed`：无同步保证
- `consume`：依赖序
- `acquire`：获取语义
- `release`：释放语义
- `acq_rel`：获取+释放
- `seq_cst`：顺序一致（最强）

**Folly 中**：
```cpp
// Load: relaxed + acquire fence
auto it = map.find(key);
std::atomic_thread_fence(std::memory_order_acquire);

// Store: release fence + relaxed
value_.store(new_value, std::memory_order_release);
```

### PGO (Profile-Guided Optimization)
配置文件导向优化。根据实际运行数据优化编译结果。

**步骤**：
1. 用 `-fprofile-generate` 编译
2. 运行典型 workload
3. 用 `-fprofile-use` 重新编译

**效果**：性能提升 10-30%

### ProducerConsumerQueue
无锁队列，支持单生产者单消费者或多生产者多消费者。

**特点**：
- Wait-Free
- 固定大小
- 零拷贝（移动语义）

**使用**：
```cpp
folly::ProducerConsumerQueue<int> queue(1024);
queue.write(42);
int value;
queue.read(value);
```

### Pseudo-Sharing (伪共享)
多个独立变量位于同一缓存行，导致缓存失效。

**问题**：
```
核心1: 写 counter1 → 缓存行失效 → 核心2 的缓存失效
核心2: 写 counter2 → 缓存行失效 → 核心1 的缓存失效
```

**解决**：使用 padding 隔离

**参见**：Day03_内存对齐与缓存友好设计.md

---

## 🔤 R-S

### SBO (Small Buffer Optimization)
小缓冲区优化。在容器内部存储少量元素，避免堆分配。

**实现**：small_vector

**优势**：
- 小数组：快 7 倍
- 无堆分配
- 更好的缓存局部性

**参见**：Day06_Small_Vector与SBO深度剖析.md

### SIMD (Single Instruction, Multiple Data)
单指令多数据。一条指令同时处理多个数据。

**F14 中使用**：
```cpp
// AVX2 指令一次比较 14 个哈希标记
__m256i tag_chunk = _mm256_loadu_si256((__m256i*)tags);
__m256i match = _mm256_cmpeq_epi8(tag_chunk, tag_vec);
```

**要求**：
- CPU 支持（AVX2/AVX-512）
- 数据对齐
- 编译器优化

### Small Vector
具有 SBO 的 vector。前 N 个元素在栈上，超过后转移到堆。

**使用**：
```cpp
folly::small_vector<int, 8> vec;  // 前 8 个在栈上
vec.push_back(1);   // 栈
vec.push_back(2);   // 栈
...
vec.resize(100);    // 堆
```

**参见**：Day06_Small_Vector与SBO深度剖析.md

### Synchronized (folly::Synchronized)
线程安全包装器，自动管理读写锁。

**使用**：
```cpp
folly::Synchronized<std::vector<int>> vec;

// 读锁
vec.withRLock([&](const auto& v) {
    // 读取 v
});

// 写锁
vec.withWLock([&](auto& v) {
    v.push_back(42);
});
```

**特点**：
- RAII 自动加锁/解锁
- 读写锁分离
- 链式调用

---

## 🔤 T-Z

### Task
C++20 协程的包装，协程化的异步任务。

**使用**：
```cpp
folly::coro::Task<int> compute() {
    co_await folly::coro::sleep(100ms);
    co_return 42;
}

// 启动
auto future = compute().scheduleOn(&executor).start();
```

**参见**：Day12_Cpp20协程与Task.md

### ThreadLocal
线程本地存储。每个线程有独立的副本。

**使用**：
```cpp
folly::ThreadLocalPtr<MyClass> ptr;

// 线程 1
ptr.reset(new MyClass());

// 线程 2
ptr.get();  // 返回 nullptr（每个线程独立）
```

### Wait-Free
无锁算法的一种。保证所有操作在有限步骤内完成。

**相比 Lock-Free**：
- Lock-Free：至少有一个操作在有限步骤完成
- Wait-Free：所有操作都在有限步骤完成

**Folly 中**：AtomicHashMap 的查找是 Wait-Free

### WOL (Write-Once-Lock)
只写一次的锁模式。某些数据结构使用此模式优化性能。

---

## 🎯 性能术语

### Cache Coherence
缓存一致性。多核 CPU 保证每个核心看到的缓存数据一致。

**协议**：MESI（Modified, Exclusive, Shared, Invalid）

### Cache Line
缓存行，CPU 缓存的最小单位。通常是 64 字节。

**优化**：
- 对齐到缓存行边界
- 避免伪共享
- 利用空间局部性

### False Sharing
见 Pseudo-Sharing

### Latency vs Throughput
- **延迟（Latency）**：单个操作的完成时间
- **吞吐（Throughput）**：单位时间的操作数量

**优化目标**：
- 低延迟：P99 < 1ms
- 高吞吐：> 100K ops/sec

### P50, P95, P99
百分位延迟。

- P50：中位数（50% 的请求）
- P95：95% 的请求完成时间
- P99：99% 的请求完成时间

**Folly 优化**：关注 P99 延迟

---

## 🛠️ 工具术语

### ASAN (AddressSanitizer)
地址消毒器，检测内存错误。

```bash
g++ -fsanitize=address -g program.cpp
./program
```

### Perf
Linux 性能分析工具。

```bash
# CPU 性能
perf record ./program
perf report

# 火焰图
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

### Valgrind
内存调试和性能分析工具。

```bash
# 内存泄漏检测
valgrind --tool=memcheck --leak-check=full ./program

# 缓存分析
valgrind --tool=cachegrind ./program
```

---

## 📊 数据结构术语

### Chaining vs Open Addressing
哈希表的冲突解决策略。

- **Chaining（链地址法）**：每个桶是一个链表
  - std::unordered_map 使用
  - 内存开销大

- **Open Addressing（开放寻址）**：在桶内探测
  - F14 使用
  - 内存紧凑，缓存友好

### Heterogeneous Lookup
异构查找。用不同类型查找，无需构造键对象。

```cpp
folly::F14FastMap<std::string, int> map;

// 好：直接用字符串字面量
map.find("hello");

// 差：需要构造 string
std::string key = "hello";
map.find(key);
```

### Probe Sequence
探测序列。开放寻址哈希表中的探测顺序。

**F14 使用**：双重哈希探测

---

## 🔄 并发术语

### ABA Problem
ABA 问题。一个值从 A 变为 B 再变回 A，CAS 无法检测。

**解决**：Hazard Pointers, Double-Word CAS

### CAS (Compare-And-Swap)
比较并交换。原子操作的原语。

```cpp
do {
    expected = current_value;
    desired = new_value;
} while (!atomic.compare_exchange_strong(expected, desired));
```

### Critical Section
临界区。访问共享资源的代码段，需要互斥访问。

### Deadlock
死锁。两个或多个线程互相等待，永远无法继续。

### Race Condition
竞态条件。多个线程同时访问共享数据，结果依赖于执行顺序。

---

## 💡 设计模式术语

### RAII (Resource Acquisition Is Initialization)
资源获取即初始化。C++ 的核心资源管理模式。

**Folly 中**：
```cpp
{
    folly::SysArena arena;
    // 使用 arena
}  // 自动释放
```

### SBO
见 Small Buffer Optimization

### SCOPE_EXIT
作用域退出时执行。Folly 的 ScopeGuard 实现。

```cpp
#include <folly/ScopeGuard.h>

void func() {
    FILE* f = fopen("file.txt", "w");
    SCOPE_EXIT { fclose(f); };  // 函数结束时自动执行

    // 使用 f
}
```

---

## 🧪 测试术语

### Benchmark
基准测试。测量代码性能的测试。

**使用**：folly/Benchmark.h

### Micro-benchmark
微基准测试。测试非常小的代码片段。

**注意**：
- 多次迭代取平均
- 避免编译器优化掉
- 测试真实场景

### Regression Test
回归测试。确保新代码没有破坏现有功能。

---

## 🎓 学习建议

### 如何使用本术语表

1. **遇到术语时**：快速查找解释
2. **复习时**：按字母顺序浏览
3. **面试前**：背诵核心术语

### 推荐学习顺序

1. 基础概念（Folly, SBO, Arena）
2. 数据结构（F14, small_vector）
3. 并发（Baton, Hazptr, AtomicHashMap）
4. 异步（EventBase, Task）
5. 性能（SIMD, PGO, Cache）

---

**建议**：将此术语表加入书签，随时查阅！📖
