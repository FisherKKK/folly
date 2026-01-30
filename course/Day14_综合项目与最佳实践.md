# Folly 深度学习课程 - 第 14 天（最后一天）

# 第 14 天：综合项目与最佳实践

## 学习目标
- 将所学知识整合到一个实际项目中
- 理解 Folly 在生产环境中的使用
- 掌握高性能 C++ 编程的最佳实践

## 核心内容

### 14.1 综合项目：高性能日志系统

**需求**：
- 多线程安全写入
- 高吞吐量（> 1M 条/秒）
- 低延迟（< 1μs P99）
- 异步刷新到磁盘

**架构设计**：

```cpp
#include <folly/ConcurrentHashMap.h>
#include <folly/ProducerConsumerQueue.h>
#include <folly/synchronization/Hazptr.h>
#include <folly/io/async/EventBase.h>
#include <folly/executors/CPUThreadPoolExecutor.h>

class Logger {
public:
    Logger(size_t num_threads = 4, size_t queue_size = 100000)
        : executor_(num_threads),
          queues_(num_threads),
          flush_thread_(&Logger::flushLoop, this) {
        for (auto& queue : queues_) {
            queue = std::make_unique<Queue>(queue_size);
        }
    }

    void log(std::string message) {
        // 负载均衡到不同队列
        size_t thread_id = folly::AccessSpreader<>::current(0, queues_.size());
        auto& queue = queues_[thread_id];

        if (!queue->try_write(std::move(message))) {
            // 队列满：丢弃或阻塞
            dropped_.fetch_add(1, std::memory_order_relaxed);
        }
    }

    ~Logger() {
        shutdown_ = true;
        flush_thread_.join();
    }

private:
    using Queue = folly::ProducerConsumerQueue<std::string>;

    void flushLoop() {
        folly::EventBase evb;

        // 定期刷新
        evb.runAfterDelay([this] {
            flush();
        }, std::chrono::milliseconds(100));

        evb.loopForever();
    }

    void flush() {
        std::vector<std::string> batch;
        batch.reserve(10000);

        for (auto& queue : queues_) {
            std::string msg;
            while (queue->read(msg)) {
                batch.push_back(std::move(msg));
            }
        }

        // 批量写入磁盘
        writeBatch(batch);
    }

    folly::CPUThreadPoolExecutor executor_;
    std::vector<std::unique_ptr<Queue>> queues_;
    std::thread flush_thread_;
    std::atomic<size_t> dropped_{0};
    std::atomic<bool> shutdown_{false};
};
```

### 14.2 性能优化技术总结

**1. 数据结构选择**

| 场景 | 推荐数据结构 | 理由 |
|------|-------------|------|
| 通用哈希表 | `folly::F14FastMap` | 自动选择最优策略 |
| 大对象哈希表 | `folly::F14NodeMap` | 引用稳定 |
| 小数组 | `folly::small_vector` | 零堆分配 |
| 批量分配 | `folly::Arena` | 减少 malloc 开销 |
| 并发计数器 | `std::atomic` | 无锁 |

**2. 内存优化**

```cpp
// SBO：栈上存储
folly::small_vector<int, 8> vec;

// Arena：批量分配
folly::SysArena arena;
void* ptr = arena.allocate(1024);

// 对齐：避免伪共享
struct FOLLY_ALIGNAS(64) AlignedData {
    int data[16];
};
```

**3. 并发优化**

```cpp
// Hazard Pointer：无锁回收
hazptr_local<1> h;
h.protect(0, ptr);
// ... 使用 ptr ...

// Baton：轻量同步
folly::Baton<> baton;
baton.wait();
baton.post();

// AtomicHashMap：并发哈希表
folly::AtomicHashMap<int, int> map(1024);
map.insert(1, 100);
```

**4. 异步优化**

```cpp
// EventBase：事件驱动
folly::EventBase evb;
evb.runInEventBaseThread([] {
    // 异步执行
});

// 协程：优雅的异步代码
folly::coro::Task<void> asyncOperation() {
    auto result = co_await fetchData();
    co_return process(result);
}
```

### 14.3 Folly 最佳实践

**1. 使用正确的组件**

```cpp
// ❌ 不好：使用 std::unordered_map
std::unordered_map<std::string, int> map;

// ✅ 好：使用 F14
folly::F14FastMap<std::string, int> map;
```

**2. 预分配容量**

```cpp
// ❌ 不好：多次重新分配
folly::F14FastMap<int, int> map;
for (int i = 0; i < 10000; ++i) {
    map[i] = i;  // 触发多次重新分配
}

// ✅ 好：预分配
folly::F14FastMap<int, int> map;
map.reserve(10000);
for (int i = 0; i < 10000; ++i) {
    map[i] = i;
}
```

**3. 避免不必要的拷贝**

```cpp
// ❌ 不好
std::string process(std::string data) {
    return data + "!";
}

// ✅ 好
std::string process(const std::string& data) {
    return data + "!";
}

// ✅ 更好（移动语义）
std::string process(std::string&& data) {
    data += "!";
    return data;
}
```

**4. 使用异构查找**

```cpp
// ❌ 不好
std::unordered_map<std::string, int> map;
map.find("hello");  // 构造临时 std::string

// ✅ 好
using TransparentHash = folly::transparent<folly::Hasher<folly::StringPiece>>;
folly::F14FastMap<std::string, int, TransparentHash> map;
map.find("hello");  // 直接使用 StringPiece
```

**5. 线程安全的数据结构**

```cpp
// ❌ 不好：外部加锁
std::mutex mtx;
std::unordered_map<int, int> map;

{
    std::lock_guard<std::mutex> lock(mtx);
    map[1] = 100;
}

// ✅ 好：使用并发数据结构
folly::AtomicHashMap<int, int> map(1024);
map.insert(1, 100);  // 线程安全
```

### 14.4 生产环境考虑

**1. 错误处理**

```cpp
folly::Expected<Result, Error> operation() {
    if (FOLLY_UNLIKELY(error)) {
        return folly::makeUnexpected<Error>(/* ... */);
    }
    return Result{/* ... */};
}

auto result = operation();
if (result.hasValue()) {
    // 成功
    use(result.value());
} else {
    // 错误
    handleError(result.error());
}
```

**2. 资源管理**

```cpp
// 使用 SCOPE_EXIT
void process() {
    FILE* f = fopen("log.txt", "w");
    SCOPE_EXIT { fclose(f); };

    // 使用 f
    // ...
}  // 自动关闭
```

**3. 性能监控**

```cpp
// folly/Benchmark.h 的实时版本
#include <folly/stats/Benchmark.h>

void criticalSection() {
    SCOPED_TIMER_SECTION(section_timer, "critical_section");

    // 关键代码
    // ...
}  // 自动记录时间
```

**4. 内存限制**

```cpp
// 限制 Arena 大小
folly::SysArena arena(4096, /* min block size */
                      1024 * 1024 * 1024);  // 1GB 限制

// 检查内存使用
if (arena.bytesUsed() > limit) {
    // 处理
}
```

### 14.5 学习路径建议

**初级（1-3 个月）**：
1. 熟练使用 Folly 容器（F14Map, small_vector）
2. 理解 Arena 和内存管理
3. 掌握 Baton 和基本同步原语

**中级（3-6 个月）**：
1. 深入理解 F14 实现原理
2. 学习无锁编程和 Hazard Pointers
3. 掌握 EventBase 和异步 I/O

**高级（6-12 个月）**：
1. 理解协程的实现原理
2. 能够设计高性能数据结构
3. 掌握平台特定的优化技巧

**专家（1 年以上）**：
1. 贡献 Folly 开源项目
2. 设计自己的性能优化库
3. 深入理解编译器和体系结构

### 14.6 进一步学习资源

**书籍**：
- "C++ Concurrency in Action" by Anthony Williams
- "The Art of Multiprocessor Programming" by Herlihy & Shavit
- "Computer Systems: A Programmer's Perspective" by Bryant & O'Hallaron

**论文**：
- F14 Design Documents (folly/container/F14.md)
- Hazard Pointers (Maged Michael)
- Lock-free Data Structures (各种学术论文)

**工具**：
- perf, valgrind, cachegrind
- Google Benchmark
- Clang/LLVM 优化文档

**实践项目**：
1. 实现一个高性能缓存
2. 设计一个无锁队列
3. 优化现有代码的性能

## 性优启示 #14：性能工程是实践学科

高性能编程不是理论，而是实践：
1. **测量驱动**：用数据说话
2. **渐进优化**：一次解决一个瓶颈
3. **持续学习**：跟上硬件和编译器的发展

---

## 课程总结

通过这 14 天的学习，你已经：

1. ✅ 掌握了 Folly 的核心架构和设计哲学
2. ✅ 理解了高性能数据结构的实现原理（F14, small_vector）
3. ✅ 学会了内存优化技术（Arena, SBO）
4. ✅ 掌握了并发编程技巧（Baton, AtomicHashMap, Hazard Pointers）
5. ✅ 理解了异步编程模型（EventBase, 协程）
6. ✅ 学会了性能测量和优化方法

**下一步行动**：
1. 在实际项目中应用这些技术
2. 深入阅读 Folly 源码
3. 贡献 Folly 开源社区
4. 分享你的知识和经验

**记住**：性能优化是一个持续的过程，而不是一次性的任务。保持好奇心，继续学习和实践！

---

## 附录：常用 Folly 组件速查表

| 组件 | 头文件 | 用途 |
|------|--------|------|
| F14FastMap | folly/container/F14Map.h | 通用哈希表 |
| small_vector | folly/container/small_vector.h | 小数组优化 |
| Arena | folly/memory/Arena.h | 批量内存分配 |
| Baton | folly/synchronization/Baton.h | 轻量同步 |
| AtomicHashMap | folly/synchronization/AtomicHashMap.h | 并发哈希表 |
| EventBase | folly/io/async/EventBase.h | 事件循环 |
| Task | folly/coro/Task.h | 协程任务 |

**编译标志**：
- `-O2` 或 `-O3`：优化级别
- `-march=native`：启用 CPU 特定优化
- `-flto`：链接时优化
- `-fsanitize=thread`：线程安全检查

**常用工具**：
- `perf record/report`：性能分析
- `valgrind --tool=cachegrind`：缓存分析
- `google-benchmark`：微基准测试

---

**恭喜！课程完成！🎉**

祝你学习愉快！高性能 C++ 编程的世界充满挑战和乐趣。继续探索，不断优化！
