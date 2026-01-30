# Folly 深度学习课程 - 第 8 天

# 第 8 天：同步原语 - Baton

## 学习目标
- 理解轻量级同步原语的设计
- 掌握 Baton 的实现原理
- 学习 futex 和无锁技术

## 核心内容

### 8.1 为什么需要 Baton？

**问题**：标准同步原语的局限

```cpp
std::mutex mtx;
std::condition_variable cv;
bool ready = false;

// 生产者
{
    std::lock_guard<std::mutex> lock(mtx);
    ready = true;
    cv.notify_one();
}

// 消费者
{
    std::unique_lock<std::mutex> lock(mtx);
    cv.wait(lock, [] { return ready; });
}
```

**问题**：
- **重量级**：mutex + condition_variable 开销大
- **复杂**：需要额外的状态变量
- **过度设计**：单次手放场景不需要这么复杂

### 8.2 Baton 的设计

**核心思想**：极简的单次手放原语

```cpp
#include <folly/synchronization/Baton.h>

folly::Baton<> baton;

// 线程 1：等待
baton.wait();  // 阻塞直到 post()

// 线程 2：唤醒
baton.post();  // 唤醒等待的线程
```

**特点**：
- **极小**：只有 4 字节
- **零填充**：无内部 padding（用户管理对齐）
- **单次手放**：一个 post() 和一个 wait()

### 8.3 Baton 的实现

**状态机**：

```cpp
enum State : uint32_t {
    INIT = 0,      // 初始状态
    WAITING = 1,   // 有线程在等待
    POSTED = 2,    // 已 post
};

template <bool MayBlock, template <typename> class Atom>
class Baton {
    Atom<uint32_t> state_;  // 只有 4 字节！

public:
    constexpr Baton() noexcept : state_(INIT) {}

    void post() {
        if (MayBlock) {
            // 可能阻塞：使用 futex
            auto s = state_.load(std::memory_order_acquire);
            if (s == POSTED) {
                return;  // 已经 post 过
            }

            if (state_.exchange(POSTED, std::memory_order_acq_rel) == WAITING) {
                // 有线程在等待，唤醒它
                futexWake(&state_, 1);
            }
        } else {
            // 非阻塞：简单的 store-release
            state_.store(POSTED, std::memory_order_release);
        }
    }

    void wait() {
        if (FOLLY_LIKELY(state_.load(std::memory_order_acquire) == POSTED)) {
            return;  // 快速路径：已经 post
        }

        // 慢速路径：需要等待
        if (state_.exchange(WAITING, std::memory_order_acq_rel) != POSTED) {
            // 还没 post，使用 futex 等待
            futexWait(&state_, WAITING);
        }
    }
};
```

### 8.4 Futex（Fast Userspace muTex）

**什么是 futex？**

Linux futex 是一个系统调用，提供了高效的用户空间同步：

```cpp
// futex 系统调用
int futex(
    int* uaddr,        // 用户空间地址
    int futex_op,      // 操作
    int val,           // 期望值
    const struct timespec* timeout,  // 超时
    ...
);
```

**Baton 如何使用 futex**：

```cpp
// 等待
void futexWait(Atom<uint32_t>* addr, uint32_t expected) {
    syscall(SYS_futex, addr, FUTEX_WAIT_PRIVATE, expected, nullptr);
    // 如果 *addr == expected，阻塞
    // 否则立即返回（EAGAIN）
}

// 唤醒
void futexWake(Atom<uint32_t>* addr, int count) {
    syscall(SYS_futex, addr, FUTEX_WAKE_PRIVATE, count, nullptr);
    // 唤醒最多 count 个等待的线程
}
```

**优势**：
- **快速路径**：无系统调用（纯用户空间）
- **慢速路径**：必要时才进入内核
- **高效**：内核维护等待队列

### 8.5 非阻塞版本

**Baton<false>：无阻塞版本**

```cpp
template <template <typename> class Atom>
class Baton<false, Atom> {  // MayBlock = false
    Atom<uint32_t> state_;

public:
    void post() {
        // 简单的 store-release
        state_.store(POSTED, std::memory_order_release);
    }

    bool try_wait() {
        // 只检查，不阻塞
        return state_.load(std::memory_order_acquire) == POSTED;
    }

    void wait() {
        // 自旋等待
        while (state_.load(std::memory_order_acquire) != POSTED) {
            // 可以加 pause 指令降低功耗
            _mm_pause();
        }
    }
};
```

**使用场景**：
- **已知等待时间短**：自旋比阻塞快
- **实时性要求**：避免调度延迟
- **信号处理程序**：async-signal-safe

### 8.6 Baton 的使用模式

**模式 1：简单的屏障**

```cpp
folly::Baton<> start_baton;

void worker(int id) {
    start_baton.wait();  // 所有线程等待

    // 同时开始工作
    doWork(id);
}

int main() {
    std::vector<std::thread> threads;
    for (int i = 0; i < 10; ++i) {
        threads.emplace_back(worker, i);
    }

    // 确保所有线程都创建完成
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    start_baton.post();  // 同时唤醒所有线程
}
```

**模式 2：一次性初始化**

```cpp
class LazyInit {
    folly::Baton<> init_baton_;
    std::once_flag flag_;
    T* value_;

public:
    T* get() {
        std::call_once(flag_, [this] {
            value_ = new T(/* ... */);
            init_baton_.post();  // 初始化完成
        });

        init_baton_.wait();  // 等待初始化
        return value_;
    }
};
```

### 8.7 避免伪共享

**问题**：多个 Baton 在同一缓存行

```cpp
// 不好的设计
struct BadAlign {
    folly::Baton<> b1;  // 偏移 0
    folly::Baton<> b2;  // 偏移 4 - 同一缓存行！
};
```

**解决方案**：手动对齐

```cpp
struct GoodAlign {
    folly::Baton<> b1;
    char padding1[64 - sizeof(folly::Baton<>)];

    folly::Baton<> b2;
    char padding2[64 - sizeof(folly::Baton<>)];
};
```

## 性优启示 #8：极简设计

Baton 展示了如何设计高效的同步原语：
1. **最小化状态**：4 字节的状态机
2. **快速路径优化**：无系统调用的常见情况
3. **平台特定**：使用 futex 等 OS 原语

## 课后作业

1. 实现 `Baton` 的简化版本
2. 比较 `Baton` vs `std::condition_variable` 的性能
3. 设计一个支持超时的 `Baton`

---

**第 8 天完。明天见！**
