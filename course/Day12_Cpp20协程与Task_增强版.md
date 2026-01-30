# Folly 深度学习课程 - 第 12 天（增强版）

# 第 12 天：C++20 协程与 Task - 异步编程的未来

## 学习目标
- 深入理解 C++20 协程的底层机制
- 掌握 folly::coro::Task 的完整实现
- 学习协程帧、co_await 机制的细节
- 理解协程与 Executor 的集成

## 核心内容

### 12.1 C++20 协程：编译器魔法揭秘

#### 协程的三种关键字

**co_await：等待异步操作**

```cpp
// 语法
auto result = co_await awaitable;

// 编译器转换
{
    auto&& awaiter = get_awaitable(awaitable);
    if (!awaiter.await_ready()) {
        // 挂起协程
        awaiter.await_suspend(coroutine_handle);
        // 返回到调用者
        return;  // <-- 协程在这里暂停

        // <-- 恢复点：awaitable 完成后从这里继续
    }
    auto result = awaiter.await_resume();
}
```

**co_yield：生成值**

```cpp
// 语法
co_yield value;

// 编译器转换
{
    promise.yield_value(value);
    // 挂起协程
    return;  // <-- 可以在这里恢复
}
```

**co_return：返回值**

```cpp
// 语法
co_return value;

// 编译器转换
{
    promise.return_value(value);
    goto final_suspend;  // 跳到最终挂起点
}
```

---

#### 协程帧的内存布局

**编译器生成的协程帧结构**：

```cpp
// 编译器为每个协程生成的帧（伪代码）
template <typename Promise, typename... Args>
struct CoroutineFrame {
    // === 1. 协程状态 ===
    enum State { Suspended, Running, Destroyed };
    State state_;

    // === 2. Promise 对象 ===
    Promise promise_;

    // === 3. 恢复点（suspend point） ===
    int suspend_point_;

    // === 4. 续元（continuation）===
    std::coroutine_handle<> continuation_;

    // === 5. 局部变量（按声明顺序）===
    // 编译器自动排列
    alignas(Promise) char promise_buffer_[sizeof(Promise)];

    // 局部变量 1
    char local1_buffer_[sizeof(LocalVar1)];

    // 局部变量 2
    char local2_buffer_[sizeof(LocalVar2)];

    // ...

    // === 6. 临时变量（编译器生成）===
    char temporaries_[...];

    // === 7. 析构标记 ===
    bool destroyed_;

    // 恢复协程
    void resume() {
        switch (suspend_point_) {
            case 0: goto L0;
            case 1: goto L1;
            case 2: goto L2;
        }

    L0:  // 初始点
        suspend_point_ = 1;
        // ... 协程体第一部分 ...

    L1:  // 第一个 co_await
        suspend_point_ = 2;
        // ... 协程体第二部分 ...

    L2:  // 第二个 co_await
        // ... 完成
    }
};
```

**实际案例分析**：

```cpp
// 源代码
folly::coro::Task<int> example(int x) {
    int local1 = x * 2;        // L0
    co_await folly::coro::sleep(1ms);  // L1
    int local2 = local1 + 1;   // L2
    co_return local2;          // L3
}

// 编译器生成的帧（简化）
struct CoroutineFrame {
    // 状态
    int suspend_point_;
    folly::coro::TaskPromise<int> promise_;

    // 续元
    std::coroutine_handle<> continuation_;

    // 局部变量
    int local1_;  // 在 L0-L3 都需要
    int local2_;  // 在 L2-L3 需要

    // 临时变量
    folly::Duration sleep_duration_;

    // 大小（64位）：
    // - suspend_point_:       4 字节
    // - padding:             4 字节
    // - promise_:            64 字节
    // - continuation_:       8 字节
    // - local1_:             4 字节
    // - local2_:             4 字节
    // - sleep_duration_:     8 字节
    // 总计：~96 字节
};
```

**小对象优化**：

```cpp
// 如果协程帧很小（< 512 字节）
// 编译器可能在栈上分配（而非堆）

// 示例：小协程
folly::coro::Task<int> small(int x) {
    co_return x * 2;
}
// 帧大小：~64 字节
// 分配：栈上（零开销）

// 示例：大协程
folly::coro::Task<void> large() {
    std::string str(1000, 'x');  // 大字符串
    std::vector<int> vec(1000);  // 大向量
    co_await something();
    co_return;
}
// 帧大小：~4000 字节
// 分配：堆上（开销）
```

---

### 12.2 folly::coro::Task 完整实现

#### Promise 类型定义

**folly/coro/Task.h:85-145**

```cpp
template <typename T>
class Task {
public:
    // Promise 类型（编译器查找）
    class promise_type {
    public:
        // === 协程创建 ===
        Task get_return_object() {
            return Task(std::coroutine_handle<promise_type>::from_promise(*this));
        }

        // === 初始挂起 ===
        std::suspend_never initial_suspend() noexcept {
            return {};  // 立即开始执行
        }

        // === 最终挂起 ===
        std::suspend_always final_suspend() noexcept {
            return {};  // 挂起以便访问结果
        }

        // === 异常处理 ===
        void unhandled_exception() {
            exception_ = std::current_exception();
        }

        // === 返回值处理 ===
        void return_value(T value) {
            result_.emplace(std::move(value));
        }

        // === co_yield （Task 不支持）===
        // 未定义：Task 不支持生成器

        // === Await 转换 ===
        template <typename Awaitable>
        auto await_transform(Awaitable&& awaitable) {
            // 转换 awaitable 类型
            return folly::coro::co_awaitTry(
                std::forward<Awaitable>(awaitable)
            );
        }

    private:
        std::optional<T> result_;
        std::exception_ptr exception_;
        std::coroutine_handle<> continuation_;

        friend class Task;
    };

private:
    std::coroutine_handle<promise_type> coro_;
};
```

#### Task 作为 Awaitable

**folly/coro/Task.h:200-250**

```cpp
template <typename T>
class Task {
public:
    // === Awaitable 接口 ===

    // 1. await_ready：是否准备好
    bool await_ready() const noexcept {
        return coro_.done();  // 已完成 = 准备好
    }

    // 2. await_suspend：挂起时的行为
    bool await_suspend(std::coroutine_handle<> continuation) {
        // 保存续元
        coro_.promise().continuation_ = continuation;

        // 如果协程已完成，不挂起
        if (coro_.done()) {
            return false;
        }

        // 否则挂起，等待完成
        return true;
    }

    // 3. await_resume：恢复时返回值
    T await_resume() {
        // 检查异常
        if (coro_.promise().exception_) {
            std::rethrow_exception(coro_.promise().exception_);
        }

        // 返回结果
        return std::move(coro_.promise().result_.value());
    }
};
```

**使用示例**：

```cpp
// 嵌套协程
folly::coro::Task<int> compute() {
    co_await folly::coro::sleep(100ms);
    co_return 42;
}

folly::coro::Task<int> wrapper() {
    // co_await compute()
    // 1. 调用 compute()，创建协程
    // 2. 调用 await_ready()：false（未完成）
    // 3. 调用 await_suspend(wrapper_handle)：
    //    - 保存 wrapper 的续元到 compute.promise
    //    - 返回 true（挂起 wrapper）
    // 4. wrapper 挂起，返回到调用者
    //
    // ... compute 完成 ...
    //
    // 5. compute 调用 continuation_.resume()
    // 6. wrapper 恢复
    // 7. 调用 await_resume()：获取结果 42
    int result = co_await compute();
    co_return result * 2;
}
```

---

### 12.3 co_await 机制深度解析

#### Awaitable 接口完整版

```cpp
// Awaitable 可以是任何类型，只要满足以下接口之一：

// === 方式 1：成员函数 ===
struct Awaitable1 {
    bool await_ready();
    void await_suspend(std::coroutine_handle<>);
    T await_resume();
};

// === 方式 2：operator co_await ===
struct Awaitable2 {
    // 转换为真正的 Awaitable
    auto operator co_await() {
        struct Awaiter {
            bool await_ready();
            void await_suspend(std::coroutine_handle<>);
            T await_resume();
        };
        return Awaiter{...};
    }
};

// === 方式 3：自由函数（ADL）===
struct Awaitable3 {};

// 在同一命名空间
auto operator co_await(Awaitable3&& a) {
    struct Awaiter {
        bool await_ready();
        void await_suspend(std::coroutine_handle<>);
        T await_resume();
    };
    return Awaiter{...};
}
```

#### co_await 的执行流程

**完整流程**：

```cpp
// 源代码
{
    auto result = co_await awaitable;
    // 使用 result
}

// 编译器展开
{
    // 1. 获取 awaiter（通过 await_transform 或直接）
    auto&& awaiter = get_awaitable(awaitable);

    // 2. 检查是否准备好
    if (!awaiter.await_ready()) {

        // 3. 未准备好：挂起
        // 3.1 获取当前协程句柄
        std::coroutine_handle<> current_coro = \
            std::coroutine_handle<promise_type>::from_address(
                __builtin_frame_address(0)
            );

        // 3.2 调用 await_suspend
        if (awaiter.await_suspend(current_coro)) {
            // 返回到调用者/恢复者
            // <--- 协程在这里暂停

            // <--- await_suspend 返回 false 后从这里恢复
            // 或：await_suspend 调用的 coroutine.resume() 后恢复
        }
    }

    // 4. 恢复：获取结果
    auto result = awaiter.await_resume();

    // 5. 继续执行
    // 使用 result
}
```

---

### 12.4 实际案例：定时器 Awaitable

#### 实现 sleep 函数

**folly/coro/Sleep.h 实现**：

```cpp
#include <folly/io/async/EventBase.h>

// 定时器 Awaitable
class SleepAwaitable {
    folly::Duration duration_;
    folly::EventBase* evb_;

public:
    SleepAwaitable(folly::Duration duration, folly::EventBase* evb)
        : duration_(duration), evb_(evb) {}

    // 1. await_ready：0 延时立即就绪
    bool await_ready() const noexcept {
        return duration_.count() == 0;
    }

    // 2. await_suspend：注册定时器
    bool await_suspend(std::coroutine_handle<> handle) {
        // 在 EventBase 中注册定时器
        evb_->runAfterDelay(
            [handle]() mutable {
                // 定时器到期：恢复协程
                handle.resume();
            },
            duration_.count()
        );

        // 挂起协程
        return true;
    }

    // 3. await_resume：无返回值
    void await_resume() const noexcept {
        // 什么也不做
    }
};

// sleep 函数
inline SleepAwaitable sleep(folly::Duration duration, folly::EventBase* evb) {
    return SleepAwaitable{duration, evb};
}

// 使用示例
folly::coro::Task<void> example() {
    folly::EventBase evb;

    // 等待 100ms
    co_await sleep(100ms, &evb);

    std::cout << "Done!" << std::endl;
}
```

**性能分析**：

```
操作                时间（ns）    说明
co_await sleep(0)   5            立即返回
co_await sleep(1μs) 1200         定时器开销
co_await sleep(1ms) 1000500      1ms + 开销
上下文切换          ~200         恢复协程

结论：
- 协程切换比线程切换快（~200ns vs ~5μs）
- 适合高延迟操作（> 100μs）
```

---

### 12.5 协程与 Executor 集成

#### Executor 接口

**folly/executors/Executor.h**：

```cpp
class Executor {
public:
    virtual ~Executor() = default;

    // 提交任务
    virtual void add(Func func) = 0;

    // 检查是否在执行器线程
    virtual bool isInExecutorThread() = 0;

    // 获取执行器名称
    virtual const char* getName() = 0;
};

// CPU 线程池执行器
class CPUThreadPoolExecutor : public Executor {
    std::vector<std::thread> threads_;
    folly::UnboundedQueue<Func> queue_;

public:
    CPUThreadPoolExecutor(size_t numThreads)
        : threads_(numThreads) {
        for (auto& t : threads_) {
            t = std::thread([this] {
                while (running_) {
                    Func task;
                    if (queue_.try_dequeue(task)) {
                        task();
                    }
                }
            });
        }
    }

    void add(Func func) override {
        queue_.enqueue(std::move(func));
    }
};

// I/O 线程池执行器
class IOThreadPoolExecutor : public Executor {
    // 类似实现，但针对 I/O 优化
};
```

#### 协程调度到 Executor

**folly/coro/Task.h:350-400**：

```cpp
template <typename T>
class Task {
public:
    // 调度到执行器
    template <typename Executor>
    auto scheduleOn(Executor* ex) && {
        // 创建包装协程
        return [](Task&& task, Executor* ex) -> folly::coro::Task<T> {
            // 切换到执行器线程
            co_await co_reschedule_current_executor(ex);

            // 执行原任务
            co_return co_await std::move(task);
        }(std::move(*this), ex);
    }
};

// 辅助函数：重新调度当前协程
struct RescheduleAwaitable {
    Executor* executor_;

    bool await_ready() { return false; }

    void await_suspend(std::coroutine_handle<> handle) {
        // 在执行器中提交恢复任务
        executor_->add([handle]() mutable {
            handle.resume();
        });
    }

    void await_resume() {}
};

inline RescheduleAwaitable co_reschedule_current_executor(Executor* ex) {
    return RescheduleAwaitable{ex};
}
```

**使用示例**：

```cpp
folly::coro::Task<int> computeOnCPU() {
    // 这个函数在 CPU executor 中运行
    int result = heavyComputation();
    co_return result;
}

folly::coro::Task<void> run() {
    folly::CPUThreadPoolExecutor cpuExecutor(4);
    folly::IOThreadPoolExecutor ioExecutor(2);

    // 切换到 CPU executor
    int result = co_await computeOnCPU().scheduleOn(&cpuExecutor);

    // 切换到 I/O executor
    co_await writeToDisk(result).scheduleOn(&ioExecutor);

    std::cout << "Done: " << result << std::endl;
}
```

---

### 12.6 性能优化技巧

#### 优化 1：避免不必要的协程

**不好**：

```cpp
folly::coro::Task<int> bad() {
    // 不必要的协程包装
    co_return co_await compute();
}
```

**好**：

```cpp
// 直接返回 Task
folly::coro::Task<int> good() {
    co_return co_await compute();
}

// 或使用函数返回
folly::coro::Task<int> good() {
    return compute();  // 直接返回
}
```

---

#### 优化 2：并发执行

**串行（慢）**：

```cpp
folly::coro::Task<void> serial() {
    auto a = co_await fetchA();  // 100ms
    auto b = co_await fetchB();  // 100ms
    auto c = co_await fetchC();  // 100ms
    // 总时间：300ms
}
```

**并行（快）**：

```cpp
folly::coro::Task<void> parallel() {
    auto [a, b, c] = co_await folly::coro::collectAll(
        fetchA(),  // 100ms
        fetchB(),  // 100ms
        fetchC()   // 100ms
    );
    // 总时间：100ms（3x 速度）
}
```

**collectAll 实现**：

```cpp
template <typename... Tasks>
auto collectAll(Tasks&&... tasks) {
    return [&tasks...](auto&& promise) -> folly::coro::Task<void> {
        // 启动所有任务
        std::vector<folly::coro::Task> awaitables;
        (awaitables.push_back(std::move(tasks)), ...);

        // 等待所有完成
        for (auto& awaitable : awaitables) {
            co_await awaitable;
        }

        // 返回结果元组
        promise.return_value(std::make_tuple(...));
    };
}
```

---

#### 优化 3：协程内联

```cpp
// 小协程可以内联
FOLLY_CORO_TASK_INLINE
folly::coro::Task<int> small(int x) {
    co_return x * 2;
}

// 编译器可能完全优化掉协程帧
// 等价于直接返回 Task
```

---

### 12.7 实际案例：异步 HTTP 客户端

```cpp
#include <folly/coro/Task.h>
#include <folly/io/async/EventBase.h>
#include <folly/http/HTTPClient.h>

class AsyncHttpClient {
    folly::EventBase* evb_;

public:
    AsyncHttpClient(folly::EventBase* evb) : evb_(evb) {}

    // 异步 GET 请求
    folly::coro::Task<std::string> get(std::string url) {
        // 1. 解析 URL
        auto [host, port, path] = parseUrl(url);

        // 2. 连接（异步）
        auto socket = co_await connect(host, port);

        // 3. 发送请求（异步）
        co_await sendRequest(*socket, "GET", path);

        // 4. 接收响应（异步）
        auto response = co_await receiveResponse(*socket);

        co_return response.body();
    }

    // 批量请求（并发）
    folly::coro::Task<std::vector<std::string>> batchGet(
        std::vector<std::string> urls
    ) {
        std::vector<folly::coro::Task<std::string>> tasks;

        for (auto& url : urls) {
            tasks.push_back(get(url));
        }

        // 并发执行所有请求
        auto results = co_await folly::coro::collectAllRange(
            std::move(tasks)
        );

        co_return results;
    }
};

// 使用示例
folly::coro::Task<void> fetchUrls() {
    folly::EventBase evb;
    AsyncHttpClient client(&evb);

    std::vector<std::string> urls = {
        "https://api.example.com/user/1",
        "https://api.example.com/user/2",
        "https://api.example.com/user/3",
    };

    // 并发获取所有 URL
    auto responses = co_await client.batchGet(urls);

    for (auto& response : responses) {
        std::cout << response << std::endl;
    }
}
```

---

## 课后作业（增强版）

1. **实现 Awaitable**：
   ```cpp
   // 实现以下 Awaitable：
   // - TimerAwaitable（定时器）
   // - EventAwaitable（事件触发）
   // - YieldAwaitable（让出执行权）
   ```

2. **性能测试**：
   ```cpp
   // 对比协程 vs 回调的性能
   // - 延迟（P50, P99, P999）
   // - 吞吐
   // - 内存使用
   ```

3. **实际应用**：
   - 使用协程重构异步代码
   - 集成到现有项目中
   - 测量性能提升

---

## 延伸阅读

- **标准**：C++20 协程（std::coroutine）
- **源码**：`folly/coro/Task.h`
- **文章**：
  - "Understanding C++20 Coroutines" by Rainer Grimm
  - "C++ Coroutines: Understanding asymmetric control flow"
- **视频**：
  - CppCon 协程系列演讲

---

**第 12 天完（增强版）。明天见！**
