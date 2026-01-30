# Folly 深度学习课程 - 第 11 天

# 第 11 天：EventBase 与异步 I/O

## 学习目标
- 理解事件驱动的编程模型
- 掌握 EventBase 的实现原理
- 学习异步 I/O 的性能优化

## 核心内容

### 11.1 为什么需要异步 I/O？

**同步 I/O 的问题**：

```cpp
// 同步读取
void handleClient(int socket) {
    char buffer[4096];
    ssize_t n = read(socket, buffer, sizeof(buffer));  // 阻塞！

    if (n > 0) {
        process(buffer, n);
    }
}

// 问题：每个线程只能处理一个客户端
// 线程数 = 客户端数
// 大量线程导致上下文切换开销
```

**异步 I/O 的优势**：
- **单线程多连接**：一个线程处理多个客户端
- **低延迟**：无阻塞调用
- **高吞吐**：减少上下文切换

### 11.2 EventBase 的设计

**核心思想**：事件循环 + 回调

```cpp
#include <folly/io/async/EventBase.h>

folly::EventBase evb;

// 注册定时器
evb.runAfterDelay([] {
    printf("Timer fired!\n");
}, 1000);

// 注册事件
evb.runInEventBaseThread([] {
    printf("Running in EventBase thread!\n");
});

// 启动事件循环
evb.loopForever();

// 或单次循环
evb.loopOnce();
```

### 11.3 EventBase 的实现

**内部结构**：

```cpp
class EventBase {
    event_base* libevent_base_;  // libevent 句柄
    std::thread loop_thread_;    // 事件循环线程

public:
    void loop() {
        running_ = true;
        while (running_) {
            // libevent 事件循环
            event_base_loop(libevent_base_, EVLOOP_ONCE);
        }
    }

    void loopForever() {
        loop();
    }

    void loopOnce() {
        event_base_loop(libevent_base_, EVLOOP_ONCE | EVLOOP_NONBLOCK);
    }

    void terminateLoopSoon() {
        running_ = false;
        // 唤醒事件循环
        event_base_loopbreak(libevent_base_);
    }
};
```

**事件注册**：

```cpp
class EventHandler {
    event* event_;

public:
    void registerHandler(EventBase* evb, int fd, short events) {
        event_ = event_new(
            evb->getLibeventBase(),
            fd,
            events | EV_PERSIST,
            &EventHandler::libeventCallback,
            this
        );
        event_add(event_, nullptr);
    }

private:
    static void libeventCallback(int fd, short events, void* arg) {
        auto* handler = static_cast<EventHandler*>(arg);
        handler->handlerReady(fd, events);
    }
};
```

### 11.4 定时器实现

**HHWheelTimer：分层时间轮**

```cpp
#include <folly/io/async/HHWheelTimer.h>

folly::EventBase evb;
folly::HHWheelTimer::UniquePtr timer(
    new folly::HHWheelTimer(&evb)
);

// 注册定时器
timer->scheduleTimeout(
    new MyTimeout(),
    std::chrono::milliseconds(1000)
);
```

**分层时间轮原理**：

```
时间轮结构（4 层，每层 256 槽）：
+-------------------+
| Level 0: 0-255ms |  每 1ms 前进一格
+-------------------+
| Level 1: 0-255s   |  每 256ms 前进一格
+-------------------+
| Level 2: 0-255min |  每 256s 前进一格
+-------------------+
| Level 3: 0-255h   |  每 256min 前进一格
+-------------------+

优势：
- O(1) 调度
- 内存紧凑
- 高效的定时器管理
```

**实现**：

```cpp
class HHWheelTimer {
    struct Callback {
        virtual void timeoutExpired() = 0;
        virtual ~Callback() = default;
    };

    std::array<std::vector<Callback*>, 256> buckets_[4];

public:
    void scheduleTimeout(Callback* cb, std::chrono::milliseconds delay) {
        size_t level, bucket;

        if (delay.count() < 256) {
            level = 0;
            bucket = (now_ + delay) % 256;
        } else if (delay.count() < 256 * 256) {
            level = 1;
            bucket = ((now_ + delay) / 256) % 256;
        }
        // ...

        buckets_[level][bucket].push_back(cb);
    }

    void tick() {
        now_++;

        // 检查当前槽
        size_t slot = now_ % 256;
        for (auto* cb : buckets_[0][slot]) {
            cb->timeoutExpired();
        }
        buckets_[0][slot].clear();

        // 级联：当低层绕回时
        if (slot == 0) {
            cascade(1);
        }
    }

private:
    void cascade(int level) {
        if (level >= 4) return;

        size_t slot = (now_ >> (8 * level)) % 256;

        // 将本层的定时器下放到低层
        for (auto* cb : buckets_[level][slot]) {
            // 重新调度到低层
        }
        buckets_[level][slot].clear();

        if (slot == 0) {
            cascade(level + 1);
        }
    }
};
```

### 11.5 跨线程调度

**runInEventBaseThread**：

```cpp
class EventBase {
    std::queue<Func> queue_;
    std::mutex queue_mutex_;
    int event_fd_;  // 用于唤醒事件循环

public:
    void runInEventBaseThread(Func func) {
        {
            std::lock_guard<std::mutex> lock(queue_mutex_);
            queue_.push(std::move(func));
        }

        // 唤醒事件循环
        uint64_t value = 1;
        write(event_fd_, &value, sizeof(value));
    }

private:
    void processQueue() {
        std::lock_guard<std::mutex> lock(queue_mutex_);

        while (!queue_.empty()) {
            auto func = std::move(queue_.front());
            queue_.pop();
            func();  // 执行回调
        }
    }
};
```

### 11.6 性能优化

**优化 1：批量处理事件**

```cpp
void loop() {
    const int kMaxEventsPerIteration = 64;

    while (running_) {
        int n = epoll_wait(epoll_fd_, events_, kMaxEventsPerIteration, timeout);

        for (int i = 0; i < n; ++i) {
            processEvent(events_[i]);
        }

        // 批量处理回调队列
        processQueue();
    }
}
```

**优化 2：边缘触发（Edge-Triggered）**

```cpp
// 使用 EPOLLET（边缘触发）
struct epoll_event ev;
ev.events = EPOLLIN | EPOLLET;  // 边缘触发
epoll_ctl(epoll_fd_, EPOLL_CTL_ADD, fd, &ev);
```

**边缘触发 vs 水平触发**：
- **水平触发**：每次 epoll_wait 都返回就绪事件
- **边缘触发**：只在状态变化时返回一次

**优化 3：零拷贝**

```cpp
#include <folly/io/async/AsyncSocket.h>

void sendMessage(int fd, const std::string& msg) {
    // 使用 sendfile 或 splice 避免内核-用户空间拷贝
    sendfile(fd, file_fd, &offset, count);
}
```

## 性优启示 #11：事件驱动设计

EventBase 展示了事件驱动编程的优势：
1. **单线程多任务**：减少线程开销
2. **非阻塞 I/O**：避免线程阻塞
3. **回调机制**：灵活的事件处理

## 课后作业

1. 实现简化的事件循环
2. 比较同步 vs 异步 I/O 的性能
3. 实现分层时间轮定时器

---

**第 11 天完。明天见！**
