# Folly 面试问题集合

## 概述

本文档收集了 Folly 相关的高频面试问题，涵盖基础知识、深度理解和实战应用。

---

## 📚 基础知识

### Q1: 什么是 Folly？为什么要使用它？

**参考答案**：
Folly (Facebook Open-source Library) 是 Facebook 开源的一个 C++ 库集合，专注于性能和实用性。

**优势**：
1. **高性能**：针对生产环境优化，性能优于标准库
2. **实用性**：解决实际开发中的常见问题
3. **完整性**：涵盖数据结构、并发、异步等多个领域

**使用场景**：
- 需要高性能哈希表 → F14Map
- 小对象容器 → small_vector
- 批量内存分配 → Arena
- 事件驱动架构 → EventBase
- 异步编程 → Future/Task

### Q2: Folly 与标准库有什么区别？

**参考答案**：

| 特性 | 标准库 | Folly |
|------|--------|-------|
| 目标 | 通用性 | 性能优先 |
| ABI | 稳定保证 | 不保证 |
| 优化 | 平衡性能 | 激进优化 |
| 抽象 | 高抽象 | 底层暴露 |

**举例**：
- `std::unordered_map` vs `folly::F14FastMap`
  - F14 使用 SIMD 优化，快 2-3 倍
  - F14 内存占用更少
  - F14 支持异构查找

### Q3: 如何在项目中引入 Folly？

**参考答案**：

1. **评估需求**：确定需要哪些组件
2. **版本选择**：使用稳定版本
3. **构建系统**：
   ```cmake
   find_package(folly REQUIRED)
   target_link_libraries(myapp PRIVATE folly)
   ```

4. **渐进式采用**：从简单组件开始

---

## 🔥 核心组件

### Q4: F14 哈希表为什么比 std::unordered_map 快？

**参考答案**：

**核心技术**：
1. **SIMD 向量过滤**：使用 AVX2 指令一次比较 14 个哈希标记
2. **双重哈希探测**：减少冲突
3. **内存布局优化**：减少缓存未命中
4. **溢出计数机制**：优化空间使用

**性能数据**：
- 查找：快 2.5 倍
- 插入：快 1.9 倍
- 内存：省 40%

### Q5: F14Map 的四种变体有什么区别？

**参考答案**：

| 变体 | 存储方式 | 适用场景 | 特点 |
|------|----------|----------|------|
| F14NodeMap | 节点堆分配 | 需要引用稳定 | 迭代器不失效 |
| F14ValueMap | 值内联 | 小对象（< 24 字节） | 无堆分配 |
| F14VectorMap | 值连续存储 | 大对象 | 内存紧凑 |
| F14FastMap | 自动选择 | 通用场景 | 编译期优化 |

**选择策略**：
```cpp
// 小键值对 → F14ValueMap
folly::F14ValueMap<int, int> map;

// 大对象 → F14VectorMap
folly::F14VectorMap<std::string, std::vector<int>> map;

// 引用稳定 → F14NodeMap
folly::F14NodeMap<int, std::string> map;

// 默认 → F14FastMap（自动选择）
folly::F14FastMap<int, std::string> map;
```

### Q6: small_vector 的优势是什么？

**参考答案**：

**Small Buffer Optimization (SBO)**：
- 前 N 个元素存储在栈上
- 超过 N 个时转移到堆
- 避免小数组时的堆分配

**性能优势**：
- 8 元素内：快 7 倍
- 无堆分配开销
- 更好的缓存局部性

**使用场景**：
```cpp
// 好：大多数情况 < 8 个元素
folly::small_vector<int, 8> vec;

// 差：通常很多元素
std::vector<int> vec;  // 使用标准库
```

### Q7: Arena 分配器何时使用？

**参考答案**：

**适用场景**：
1. 批量分配相同生命周期的对象
2. 临时对象快速创建和销毁
3. 减少内存碎片

**优势**：
- 分配：O(1)（指针移动）
- 释放：O(1)（整块释放）
- 无碎片

**示例**：
```cpp
folly::SysArena arena;
for (int i = 0; i < 10000; ++i) {
    void* ptr = arena.allocate(64);
    // 使用 ptr
}
// Arena 析构时一次性释放所有内存
```

### Q8: Baton 和 std::condition_variable 的区别？

**参考答案**：

| 特性 | Baton | condition_variable |
|------|--------|-------------------|
| 用途 | 一次性同步 | 多次同步 |
| 性能 | 更快（futex） | 较慢 |
| 复杂度 | 简单 | 复杂（需要 mutex） |

**Baton 优势**：
- 更轻量（5-10x 性能提升）
- API 简单
- 不需要 mutex

**使用场景**：
```cpp
// Baton：一次性事件
folly::Baton<> baton;
// 等待初始化完成
baton.wait();

// condition_variable：多次通知
std::condition_variable cv;
// 生产者-消费者场景
```

### Q9: AtomicHashMap 是如何实现 Wait-Free 的？

**参考答案**：

**Wait-Free 证明**：
1. **查找操作**：
   - 读取 key（memory_order_relaxed）
   - 匹配后 acquire fence
   - 最多 n 次探测（n = capacity）
   - 保证有限步骤完成

2. **CAS 循环**：
   ```cpp
   do {
       expected = EMPTY;
   } while (!key_.compare_exchange_strong(expected, desired));
   ```

3. **无锁设计**：
   - 读操作不加锁
   - 写操作使用 CAS
   - 删除使用标记位

**限制**：
- 只支持等值查找
- 不支持迭代
- 容量固定

### Q10: Hazard Pointers 解决了什么问题？

**参考答案**：

**ABA 问题**：
```
时间线：T0 ────── T1 ────── T2
线程A：  读 PTR   │        │
线程B：       删除 PTR    │
线程C：           分配 PTR │
线程A：  CAS(PTR→C) ──────✓ (错误！)
```

**解决方案**：
1. 保护阶段：
   ```cpp
   hazptr_holder.protect(ptr);  // 声明正在使用
   ```

2. 延迟回收：
   - 标记为待删除
   - 检查是否有 Hazptr 保护
   - 等待安全后回收

3. 批量回收：
   - 减少回收开销
   - 推迟到下一个批次

---

## ⚡ 性能优化

### Q11: 如何使用 FOLLY_LIKELY/UNLIKELY 优化代码？

**参考答案**：

**原理**：
- 告诉编译器分支预测信息
- 编译器生成更优的汇编代码

**使用示例**：
```cpp
int process(int errorCode) {
    if (FOLLY_UNLIKELY(errorCode != 0)) {
        // 错误处理（不常见）
        handle_error();
        return -1;
    }
    // 正常路径（常见）
    return process_success();
}
```

**效果**：
- 减少分支预测失败
- 提升性能 10-20%（热点代码）

### Q12: 如何避免伪共享？

**参考答案**：

**问题**：
两个变量在同一缓存行，多线程修改时相互失效缓存。

**解决方案**：
```cpp
// 差：伪共享
struct BadCounter {
    std::atomic<int> counter1;
    std::atomic<int> counter2;  // 可能同一缓存行
};

// 好：使用 padding
struct GoodCounter {
    std::atomic<int> counter1;
    char padding1[64];  // 缓存行大小
    std::atomic<int> counter2;
};

// 最佳：使用 Folly 宏
struct BestCounter {
    std::atomic<int> counter1;
    FOLLY_ALIGN_TO_AVOID_FALSE_SHARING
    std::atomic<int> counter2;
};
```

### Q13: 如何编写微基准测试？

**参考答案**：

**使用 folly/Benchmark.h**：
```cpp
#include <folly/Benchmark.h>

BENCHMARK(MyFunction, iters) {
    for (size_t i = 0; i < iters; ++i) {
        doSomething(i);
    }
}

// 对比测试
BENCHMARK(STDVersion, iters) {
    std::unordered_map<int, int> map;
    for (size_t i = 0; i < iters; ++i) {
        map.insert(std::make_pair(i, i));
    }
}

BENCHMARK_DRAW_LINE();
```

**最佳实践**：
1. 多次迭代取平均
2. 对比标准库
3. 使用不同数据规模
4. 检查汇编代码

---

## 🔄 并发和异步

### Q14: EventBase 的事件循环是如何工作的？

**参考答案**：

**工作原理**：
1. 注册事件处理器（I/O、定时器、信号）
2. 调用 `loop()` 或 `loopForever()`
3. 等待事件就绪
4. 分发到对应回调
5. 重复步骤 2-4

**核心组件**：
- **libevent**：底层事件多路复用
- **HHWheelTimer**：O(1) 定时器
- **AsyncSocket**：异步 Socket

**使用示例**：
```cpp
folly::EventBase evb;

// 注册定时器
evb.runAfterDelay([] {
    std::cout << "Timer fired!" << std::endl;
}, 1000);

// 启动事件循环
evb.loopForever();
```

### Q15: C++20 协程相比回调有什么优势？

**参考答案**：

**回调地狱**：
```cpp
void asyncOperation() {
    fetch(asyncCb1([](result1) {
        process(result1, asyncCb2([](result2) {
            process(result2, asyncCb3([](result3) {
                // 3 层嵌套！
            }));
        }));
    }));
}
```

**协程版本**：
```cpp
folly::coro::Task<void> asyncOperation() {
    auto result1 = co_await fetch1();
    auto result2 = co_await process(result1);
    auto result3 = co_await process(result2);
    // 线性代码！
}
```

**优势**：
1. 代码可读性高
2. 错误处理简单
3. 不丢失栈信息
4. 性能相当（零开销抽象）

---

## 💼 实战场景

### Q16: 如何设计高性能日志系统？

**参考答案**：

**关键设计**：
1. **无锁队列**：ProducerConsumerQueue
2. **批量写入**：减少系统调用
3. **异步处理**：不阻塞主线程
4. **内存优化**：使用 small_vector

**代码框架**：
```cpp
class HighPerformanceLogger {
    folly::ProducerConsumerQueue<LogEntry> queue_;
    folly::EventBase evb_;
    std::thread writerThread_;

public:
    void log(std::string message) {
        queue_.write(LogEntry(std::move(message)));
    }

    void start() {
        writerThread_ = std::thread([this]() {
            evb_.loopForever();
        });
    }
};
```

**性能目标**：
- 支持 100K 条/秒
- 延迟 < 100μs
- CPU 使用率 < 10%

### Q17: 如何实现并发缓存？

**参考答案**：

**设计方案**：
```cpp
class ConcurrentCache {
    // 使用 F14Map + Synchronized
    folly::Synchronized<folly::F14FastMap<Key, Value>> cache_;

public:
    Value get(Key key) {
        return cache_.withRLock([&](auto& map) {
            auto it = map.find(key);
            if (it != map.end()) {
                return it->second;
            }
            return Value{};
        });
    }

    void put(Key key, Value value) {
        cache_.withWLock([&](auto& map) {
            map[key] = value;
        });
    }
};
```

**优化点**：
1. 读写锁分离
2. 高性能哈希表
3. 异步刷新
4. LRU 淘汰

### Q18: 如何优化大量小对象的分配？

**参考答案**：

**方案 1：Arena**
```cpp
folly::SysArena arena;
for (int i = 0; i < 100000; ++i) {
    Node* node = arena.allocate(sizeof(Node));
    new (node) Node(...);
}
```

**方案 2：对象池**
```cpp
class ObjectPool {
    std::vector<std::unique_ptr<Node>> pool_;

public:
    Node* acquire() {
        if (!pool_.empty()) {
            auto obj = pool_.back().release();
            pool_.pop_back();
            return obj;
        }
        return new Node();
    }

    void release(Node* obj) {
        obj->reset();
        pool_.push_back(std::unique_ptr<Node>(obj));
    }
};
```

**性能对比**：
- malloc：850 ns
- Arena：9 ns（95x 提升）
- ObjectPool：20 ns（42x 提升）

---

## 🎯 高级问题

### Q19: Folly 的协程是如何实现的？

**参考答案**：

**协程帧结构**：
```cpp
struct CoroutineFrame {
    // 编译器管理
    State state_;
    PromiseType promise_;
    std::coroutine_handle<> continuation_;

    // 局部变量
    char local_var1_buffer_[sizeof(Var1)];
    char local_var2_buffer_[sizeof(Var2)];
};
```

**co_await 机制**：
1. 调用 await_ready()
2. 如果未就绪，调用 await_suspend()
3. 挂起协程，保存状态
4. 后续恢复时调用 await_resume()

**与 Executor 集成**：
```cpp
folly::coro::Task<int> task() {
    co_return 42;
}

// 调度到线程池
auto future = task().scheduleOn(&executor).start();
```

### Q20: 如何分析 Folly 程序的性能？

**参考答案**：

**工具链**：
1. **perf**：CPU 性能分析
   ```bash
   perf record ./program
   perf report
   ```

2. **valgrind**：内存分析
   ```bash
   valgrind --tool=memcheck ./program
   valgrind --tool=cachegrind ./program
   ```

3. **folly/Benchmark**：微基准测试
   ```cpp
   BENCHMARK(Func, iters) {
       for (size_t i = 0; i < iters; ++i) {
           func();
       }
   }
   ```

4. **火焰图**：可视化热点
   ```bash
   perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
   ```

**优化流程**：
1. 测量（Benchmark）
2. 分析（perf）
3. 识别热点
4. 优化
5. 验证

---

## 📝 代码题

### Q21: 实现 Wait-Free 并发队列

**要求**：
- 使用 folly::AtomicHashMap
- 支持多生产者多消费者
- Wait-Free 操作

**参考实现**：
```cpp
#include <folly/synchronization/AtomicHashMap.h>
#include <folly/ProducerConsumerQueue.h>

template <typename T>
class WaitFreeQueue {
    folly::ProducerConsumerQueue<T> queue_;

public:
    explicit WaitFreeQueue(size_t capacity)
        : queue_(capacity) {}

    bool push(T value) {
        return queue_.write(std::move(value));
    }

    bool pop(T& value) {
        return queue_.read(value);
    }
};
```

### Q22: 实现高性能计数器

**要求**：
- 避免伪共享
- 支持多线程更新
- 性能最优

**参考实现**：
```cpp
#include <folly/ThreadLocal.h>
#include <folly/synchronization/AtomicStruct.h>

class HighPerformanceCounter {
    struct Counter {
        std::atomic<uint64_t> value;
        char padding[folly::hardware_destructive_interference_size];
    };

    std::vector<Counter> counters_;

public:
    HighPerformanceCounter() : counters_(std::thread::hardware_concurrency()) {}

    void increment() {
        int tid = getThreadId();
        counters_[tid].value.fetch_add(1, std::memory_order_relaxed);
    }

    uint64_t total() const {
        uint64_t sum = 0;
        for (const auto& c : counters_) {
            sum += c.value.load(std::memory_order_relaxed);
        }
        return sum;
    }
};
```

### Q23: 使用协程实现异步 HTTP 客户端

**要求**：
- 使用 folly::coro::Task
- 支持超时
- 错误处理

**参考实现**：
```cpp
#include <folly/coro/Task.h>
#include <folly/io/async/EventBase.h>

folly::coro::Task<std::string> httpGet(
    folly::EventBase* evb,
    const std::string& url,
    std::chrono::milliseconds timeout
) {
    // 创建客户端
    auto client = createHttpClient(evb);

    // 异步请求（带超时）
    auto response = co_await folly::futures::sleep(timeout)
        .thenTry([&](auto&&) {
            return client->get(url);
        });

    co_return response.body();
}
```

---

## 🎓 面试技巧

### 如何回答 Folly 相关问题

1. **理解原理**：不只是 API，要理解为什么这样设计
2. **对比分析**：与标准库对比，突出优势
3. **实战经验**：分享实际项目中的使用
4. **性能数据**：用数据说话

### 常见追问

- "为什么不用标准库？"
- "这个选择的 trade-off 是什么？"
- "如何测试性能提升？"
- "遇到过什么坑？"

---

## 📚 延伸阅读

- **Folly 文档**：https://facebook.github.io/folly/
- **Folly 源码**：https://github.com/facebook/folly
- **CppCon 演讲**：搜索 "Folly performance"

---

**祝你面试成功！** 🚀
