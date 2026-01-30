# Folly 深度学习课程 - 第 12 天

# 第 12 天：C++20 协程与 Task

## 学习目标
- 理解协程的基本概念
- 掌握 folly::coro::Task 的实现
- 学习协程的性能优化

## 核心内容

### 12.1 为什么需要协程？

**回调地狱（Callback Hell）**：

```cpp
void asyncOperation(Callback<void(Result)> callback) {
    fetchData(
        [=](Data1 d1) {
            processMore(
                d1,
                [=](Data2 d2) {
                    finalStep(
                        d2,
                        [=](Result r) {
                            callback(r);
                        }
                    );
                }
            );
        }
    );
}
```

**协程版本**：

```cpp
folly::coro::Task<Result> asyncOperation() {
    auto d1 = co_await fetchData();
    auto d2 = co_await processMore(d1);
    auto r = co_await finalStep(d2);
    co_return r;
}
```

### 12.2 C++20 协程基础

**协程关键字**：
- `co_await`：等待异步操作
- `co_yield`：生成值
- `co_return`：返回值

**协程帧**：

```cpp
// 编译器为协程生成的伪代码
struct CoroutineFrame {
    // 1. 协程状态
    enum class State { Suspended, Running, Destroyed };
    State state_;

    // 2. 参数和局部变量
    PromiseType promise_;
    std::coroutine_handle<> continuation_;

    // 3. 临时变量
    TempVars temps_;

    // 4. 恢复点（suspend point）
    int suspend_point_;

    void resume() {
        switch (suspend_point_) {
            case 0: goto L0;
            case 1: goto L1;
            case 2: goto L2;
        }

    L0:
        suspend_point_ = 1;
        // ... 协程体代码

    L1:
        suspend_point_ = 2;
        // ... 更多代码
    }
};
```

### 12.3 folly::coro::Task

**基本使用**：

```cpp
#include <folly/coro/Task.h>
#include <folly/executors/CPUThreadPoolExecutor.h>

folly::coro::Task<int> compute() {
    co_await folly::coro::sleep(std::chrono::milliseconds(100));
    co_return 42;
}

folly::coro::Task<void> run() {
    int result = co_await compute();
    std::cout << "Result: " << result << std::endl;
}

int main() {
    folly::EventBase evb;
    folly::CPUThreadPoolExecutor executor(4);

    // 在 executor 中运行协程
    auto future = run().scheduleOn(&executor).start();

    // 等待完成
    std::move(future).get();
}
```

**Task 的实现**：

```cpp
template <typename T>
class Task {
public:
    class promise_type {
    public:
        Task get_return_object() {
            return Task(std::coroutine_handle<promise_type>::from_promise(*this));
        }

        std::suspend_never initial_suspend() {
            return {};  // 立即开始执行
        }

        std::suspend_always final_suspend() noexcept {
            return {};  // 挂起以便访问结果
        }

        void unhandled_exception() {
            exception_ = std::current_exception();
        }

        void return_value(T value) {
            result_ = std::move(value);
        }

    private:
        std::optional<T> result_;
        std::exception_ptr exception_;
        std::coroutine_handle<> continuation_;

        friend class Task;
    };

private:
    std::coroutine_handle<promise_type> coro_;

public:
    Task(std::coroutine_handle<promise_type> coro) : coro_(coro) {}

    ~Task() {
        if (coro_) {
            coro_.destroy();
        }
    }

    // 等待 Task 完成
    bool await_ready() {
        return coro_.done();
    }

    bool await_suspend(std::coroutine_handle<> continuation) {
        coro_.promise().continuation_ = continuation;
        return true;  // 挂起
    }

    T await_resume() {
        if (coro_.promise().exception_) {
            std::rethrow_exception(coro_.promise().exception_);
        }
        return std::move(coro_.promise().result_.value());
    }
};
```

### 12.4 co_await 机制

**Awaitable 接口**：

```cpp
struct Awaitable {
    // 1. 是否准备好
    bool await_ready();

    // 2. 挂起时做什么
    void await_suspend(std::coroutine_handle<>);

    // 3. 恢复时返回什么
    T await_resume();
};
```

**示例：定时器**：

```cpp
struct TimerAwaitable {
    std::chrono::milliseconds duration;
    folly::EventBase* evb_;

    bool await_ready() {
        return duration.count() == 0;  // 0 延时立即就绪
    }

    void await_suspend(std::coroutine_handle<> handle) {
        // 注册定时器回调
        evb_->runAfterDelay(
            [handle]() mutable {
                handle.resume();  // 恢复协程
            },
            duration.count()
        );
    }

    void await_resume() {
        // 无返回值
    }
};

// 使用
folly::coro::Task<void> example() {
    co_await TimerAwaitable{100ms, &evb};  // 等待 100ms
    std::cout << "Timer fired!" << std::endl;
}
```

### 12.5 协程与 Executor

**Executor 接口**：

```cpp
class Executor {
public:
    virtual void add(Func func) = 0;
    virtual bool isInExecutorThread() = 0;
};

// CPU 线程池
folly::CPUThreadPoolExecutor cpuExecutor(4);

// I/O 线程池
folly::IOThreadPoolExecutor ioExecutor(2);
```

**调度协程到 Executor**：

```cpp
folly::coro::Task<int> computeOnCPU() {
    co_await folly::coro::co_reschedule_current_executor;
    // 现在在 CPU executor 线程中
    co_return heavyComputation();
}

folly::coro::Task<void> run() {
    // 切换到 CPU executor 执行计算
    int result = co_await computeOnCPU().scheduleOn(cpuExecutor);
    std::cout << result << std::endl;
}
```

### 12.6 协程取消

**CancellationToken**：

```cpp
struct CancellationToken {
    bool isCancelled() const {
        return cancelled_.load(std::memory_order_acquire);
    }

    void cancel() {
        cancelled_.store(true, std::memory_order_release);
    }

private:
    std::atomic<bool> cancelled_{false};
};

folly::coro::Task<void> cancellableOperation(CancellationToken token) {
    for (int i = 0; i < 100; ++i) {
        if (token.isCancelled()) {
            co_return;  // 提前退出
        }
        co_await doStep(i);
    }
}
```

### 12.7 协程性能优化

**优化 1：小对象优化**

```cpp
// 如果协程帧很小，直接内联
// 避免堆分配
folly::coro::Task<int> fastTask() {
    // 只有少量局部变量
    int x = 42;
    co_return x;
}
```

**优化 2：避免不必要的 co_await**

```cpp
// 不好
folly::coro::Task<int> bad() {
    auto x = co_await computeX();
    auto y = co_await computeY();
    co_return x + y;
}

// 好：并发执行
folly::coro::Task<int> good() {
    auto [x, y] = co_await folly::coro::collectAll(
        computeX(),
        computeY()
    );
    co_return x + y;
}
```

**优化 3：内联协程**

```cpp
// 使用 co_await 直接等待，不创建中间 Task
folly::coro::Task<void> optimized() {
    int x = co_await computeX();  // 直接等待
    co_return;
}
```

## 性优启示 #12：协程的威力

协程提供了异步编程的优雅解决方案：
1. **线性代码**：避免回调地狱
2. **零开销抽象**：编译器优化
3. **灵活调度**：与 Executor 集成

## 课后作业

1. 实现简单的 Task 类型
2. 实现定时器 awaitable
3. 比较协程 vs 回调的性能

---

**第 12 天完。明天见！**
