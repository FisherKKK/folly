# Folly 代码示例集

## 概述

本文档收集了 Folly 课程中的所有重要代码示例，可以直接复制运行。

---

## Day 1: 构建 Folly

### 最简单的 Folly 程序

```cpp
#include <folly/FBString.h>
#include <iostream>

int main() {
    folly::fbstring str = "Hello, Folly!";
    std::cout << str << std::endl;

    str += " How are you?";
    std::cout << str << std::endl;

    return 0;
}
```

**编译**：
```bash
g++ -std=c++17 -I/path/to/folly \
    -L/path/to/folly/lib \
    -lfolly hello.cpp -o hello
```

---

## Day 2: 分支预测

### 使用 FOLLY_LIKELY/UNLIKELY

```cpp
#include <folly/Likely.h>
#include <iostream>

void processError(int errorCode) {
    if (FOLLY_UNLIKELY(errorCode != 0)) {
        // 错误处理（不太可能执行）
        std::cerr << "Error: " << errorCode << std::endl;
        // 复杂的错误恢复逻辑
        cleanup();
        logError();
        notifyAdmin();
    } else {
        // 正常流程（很可能执行）
        continueProcessing();
    }
}

// 快速路径检查
int findValue(const std::vector<int>& vec, int target) {
    for (int value : vec) {
        if (FOLLY_LIKELY(value == target)) {
            return value;
        }
    }
    return -1;
}
```

---

## Day 3: 内存对齐

### 避免伪共享

```cpp
#include <folly/CacheLocality.h>
#include <atomic>

// 错误示例：两个变量可能在同一缓存行
struct BadCounter {
    std::atomic<int> counter1;
    std::atomic<int> counter2;  // 可能与 counter1 共享缓存行
};

// 正确示例：使用 padding 隔离
struct GoodCounter {
    std::atomic<int> counter1;
    char padding1[folly::hardware_destructive_interference_size];

    std::atomic<int> counter2;
    char padding2[folly::hardware_destructive_interference_size];
};

// 使用 Folly 的宏
struct BestCounter {
    std::atomic<int> counter1;
    FOLLY_ALIGN_TO_AVOID_FALSE_SHARING
    std::atomic<int> counter2;
};
```

### 缓存友好的数据布局

```cpp
// 结构体数组 vs 数组结构体

// 差：缓存不友好（AOS）
struct ParticleAOS {
    float x, y, z;
    float vx, vy, vz;
    float mass;
};

std::vector<ParticleAOS> particles;

// 好：缓存友好（SOA）
struct ParticlesSOA {
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
    std::vector<float> mass;
};

// 计算所有粒子的总质量（SOA 更快）
float totalMass(const ParticlesSOA& particles) {
    float sum = 0.0f;
    for (float m : particles.mass) {
        sum += m;
    }
    return sum;
}
```

---

## Day 4-5: F14 哈希表

### 基本使用

```cpp
#include <folly/container/F14Map.h>
#include <folly/container/F14Set.h>
#include <string>

// F14FastMap - 最快的变体
folly::F14FastMap<std::string, int> wordCounts;

void countWords(const std::string& text) {
    // 插入
    wordCounts["hello"]++;
    wordCounts["world"]++;

    // 查找
    auto it = wordCounts.find("hello");
    if (it != wordCounts.end()) {
        std::cout << "Count: " << it->second << std::endl;
    }

    // 异构查找（无需构造 std::string）
    folly::StringPiece key = "hello";
    auto it2 = wordCounts.find(key);
}

// F14NodeMap - 引用稳定
folly::F14NodeMap<int, std::string> idToName;

void registerUser(int id, const std::string& name) {
    idToName[id] = name;  // 迭代器不会失效
}

// F14Set
folly::F14FastSet<int> uniqueIds;

void addId(int id) {
    uniqueIds.insert(id);
}
```

### 自定义哈希

```cpp
#include <folly/container/F14Map.h>
#include <folly/hash/Hash.h>

struct Point {
    int x, y;

    bool operator==(const Point& other) const {
        return x == other.x && y == other.y;
    }
};

struct PointHash {
    size_t operator()(const Point& p) const {
        // 使用 Folly 的哈希组合
        return folly::hash::hash_combine(p.x, p.y);
    }
};

// 使用自定义哈希
folly::F14FastMap<Point, std::string, PointHash> pointLabels;

void labelPoint(const Point& p, const std::string& label) {
    pointLabels[p] = label;
}
```

### 内存高效的 F14ValueMap

```cpp
#include <folly/container/F14Map.h>

// 小对象使用 F14ValueMap（内联存储）
struct SmallKey {
    int id;
    char name[16];
};

struct SmallValue {
    double data;
    int flags;
};

folly::F14ValueMap<SmallKey, SmallValue> smallMap;

void insertSmall(const SmallKey& key, const SmallValue& value) {
    smallMap[key] = value;  // 无堆分配
}
```

---

## Day 6: small_vector

### 基本使用

```cpp
#include <folly/container/small_vector.h>
#include <vector>

// 前 8 个 int 在栈上
folly::small_vector<int, 8> vec;

void processNumbers() {
    vec.push_back(1);
    vec.push_back(2);
    vec.push_back(3);

    // 像 std::vector 一样使用
    for (int x : vec) {
        std::cout << x << " ";
    }

    vec.resize(100);  // 超过 8 个，使用堆
}

// 容器优化
folly::small_vector<std::string, 4> strings;

void collectStrings() {
    strings.push_back("hello");  // 栈上分配
    strings.push_back("world");  // 栈上分配
    // 小于 4 个时，无堆分配
}
```

### 迭代器稳定性

```cpp
folly::small_vector<int, 4> vec = {1, 2, 3};

auto it = vec.begin();
vec.push_back(4);  // 如果容量未超，it 仍然有效

// 注意：当从栈转移到堆时，迭代器会失效
vec.resize(100);
// it 现在失效了
```

---

## Day 7: Arena

### 基本使用

```cpp
#include <folly/memory/Arena.h>
#include <string>

class ArenaAllocator {
    folly::SysArena arena_;

public:
    // 分配内存
    void* allocate(size_t size) {
        return arena_.allocate(size);
    }

    // 分配并构造对象
    template <typename T, typename... Args>
    T* construct(Args&&... args) {
        void* mem = arena_.allocate(sizeof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }
};

// 使用场景：批量处理
void processBatch(const std::vector<std::string>& data) {
    folly::SysArena arena;

    for (const auto& str : data) {
        // 在 Arena 中分配
        char* buffer = static_cast<char*>(arena.allocate(str.size()));
        std::memcpy(buffer, str.data(), str.size());

        // 使用 buffer
        processBuffer(buffer, str.size());
    }

    // Arena 析构时，一次性释放所有内存
}
```

### 线程本地 Arena

```cpp
#include <folly/memory/Arena.h>
#include <thread>

class ThreadLocalArena {
    static folly::SysArena& getArena() {
        static thread_local folly::SysArena arena;
        return arena;
    }

public:
    static void* allocate(size_t size) {
        return getArena().allocate(size);
    }
};

// 多线程使用
void workerThread(int id) {
    // 每个线程有自己的 Arena
    char* buffer = static_cast<char*>(
        ThreadLocalArena::allocate(1024)
    );

    // 使用 buffer
    // ...

    // 线程结束时，Arena 自动释放
}
```

---

## Day 8: Baton

### 基本使用

```cpp
#include <folly/synchronization/Baton.h>
#include <thread>
#include <iostream>

void producerConsumerExample() {
    folly::Baton<> baton;
    std::string data;

    // 生产者线程
    std::thread producer([&]() {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        data = "Hello from producer!";
        baton.post();  // 通知消费者
    });

    // 消费者线程
    std::thread consumer([&]() {
        baton.wait();  // 等待数据
        std::cout << "Received: " << data << std::endl;
    });

    producer.join();
    consumer.join();
}

// 一次性初始化
class LazyInitializer {
    folly::Baton<> initBaton_;
    std::string expensiveObject_;

public:
    const std::string& get() {
        // 快速路径：已初始化
        if (initBaton_.try_wait()) {
            return expensiveObject_;
        }

        // 慢路径：需要初始化
        expensiveObject_ = performExpensiveInit();
        initBaton_.post();
        return expensiveObject_;
    }

private:
    std::string performExpensiveInit() {
        // 昂贵的初始化操作
        return "initialized";
    }
};
```

### 超时等待

```cpp
#include <folly/synchronization/Baton.h>
#include <chrono>

bool waitForData(folly::Baton<>& baton, int timeoutMs) {
    return baton.try_wait_for(std::chrono::milliseconds(timeoutMs));
}

// 使用
void processWithTimeout() {
    folly::Baton<> baton;

    // 在另一个线程中 post
    std::thread worker([&]() {
        doWork();
        baton.post();
    });

    // 等待最多 1 秒
    if (baton.try_wait_for(std::chrono::seconds(1))) {
        std::cout << "Work completed" << std::endl;
    } else {
        std::cout << "Timeout!" << std::endl;
    }

    worker.join();
}
```

---

## Day 9: AtomicHashMap

### 基本使用

```cpp
#include <folly/synchronization/AtomicHashMap.h>
#include <thread>

// 创建：指定最大容量
constexpr size_t MAX_SIZE = 10000;
folly::AtomicHashMap<int, std::string> map(MAX_SIZE);

void insert(int key, const std::string& value) {
    map.insert(std::make_pair(key, value));
}

std::string lookup(int key) {
    auto it = map.find(key);
    if (it != map.end()) {
        return it->second;
    }
    return "";
}

// 多线程插入
void concurrentInsertExample() {
    folly::AtomicHashMap<int, int> map(1000);

    std::vector<std::thread> threads;
    for (int i = 0; i < 10; ++i) {
        threads.emplace_back([&, i]() {
            for (int j = 0; j < 100; ++j) {
                int key = i * 100 + j;
                map.insert(std::make_pair(key, key * 2));
            }
        });
    }

    for (auto& t : threads) {
        t.join();
    }

    std::cout << "Size: " << map.size() << std::endl;
}
```

### 自定义 Key

```cpp
#include <folly/synchronization/AtomicHashMap.h>

struct MyKey {
    int id;
    char name[32];

    bool operator==(const MyKey& other) const {
        return id == other.id;
    }
};

namespace std {
    template<>
    struct hash<MyKey> {
        size_t operator()(const MyKey& key) const {
            return std::hash<int>{}(key.id);
        }
    };
}

folly::AtomicHashMap<MyKey, int> map(1000);
```

---

## Day 10: Hazard Pointers

### 基本使用

```cpp
#include <folly/synchronization/Hazptr.h>
#include <memory>

template <typename T>
class LockFreeStack {
    struct Node {
        T data;
        std::atomic<Node*> next;

        explicit Node(T value) : data(value), next(nullptr) {}
    };

    std::atomic<Node*> head_;
    folly::hazptr_domain<>& domain_;

public:
    LockFreeStack() : head_(nullptr),
                     domain_(folly::DefaultHazptrDomain()) {}

    void push(T value) {
        Node* node = new Node(value);
        node->next = head_.load(std::memory_order_relaxed);

        while (!head_.compare_exchange_weak(
            node->next,
            node,
            std::memory_order_release,
            std::memory_order_relaxed)) {
            // CAS 重试
        }
    }

    bool pop(T& result) {
        folly::hazptr_holder<1> holder;
        Node* oldHead = head_.load(std::memory_order_acquire);

        do {
            if (oldHead == nullptr) {
                return false;
            }

            // 保护旧节点
            holder.protect(0, oldHead);

            // 再次检查
            if (head_.load(std::memory_order_acquire) != oldHead) {
                oldHead = head_.load(std::memory_order_acquire);
                continue;
            }

            Node* newHead = oldHead->next.load(std::memory_order_relaxed);
            if (head_.compare_exchange_weak(
                    oldHead,
                    newHead,
                    std::memory_order_release,
                    std::memory_order_acquire)) {
                result = oldHead->data;
                // 退休节点
                holder.retire(oldHead);
                return true;
            }
        } while (true);
    }
};
```

---

## Day 11: EventBase

### 基本使用

```cpp
#include <folly/io/async/EventBase.h>
#include <folly/io/async/AsyncSocket.h>
#include <iostream>

void eventBaseExample() {
    folly::EventBase evb;

    // 注册延迟回调
    evb.runAfterDelay([]() {
        std::cout << "Timer fired!" << std::endl;
    }, 1000);  // 1000ms

    // 在 EventBase 线程中执行
    evb.runInEventBaseThread([]() {
        std::cout << "In EventBase thread" << std::endl;
    });

    // 启动事件循环（在另一个线程中）
    std::thread evbThread([&]() {
        evb.loopForever();
    });

    // 停止事件循环
    std::this_thread::sleep_for(std::chrono::seconds(2));
    evb.terminateLoopSoon();
    evbThread.join();
}
```

### 异步 Socket 客户端

```cpp
#include <folly/io/async/EventBase.h>
#include <folly/io/async/AsyncSocket.h>

class AsyncClient {
    folly::EventBase evb_;
    folly::AsyncSocket::UniquePtr socket_;

public:
    void connect(const std::string& host, int port) {
        socket_ = std::make_unique<folly::AsyncSocket>(
            &evb_,
            host,
            port
        );

        socket_->connectNow();
    }

    void send(const std::string& data) {
        socket_->writeChain(
            folly::IOBuf::copyBuffer(data)
        );
    }

    void run() {
        evb_.loopForever();
    }

    void stop() {
        evb_.terminateLoopSoon();
    }
};
```

---

## Day 12: 协程

### 基本 Task

```cpp
#include <folly/coro/Task.h>
#include <folly/executors/CPUThreadPoolExecutor.h>

// 简单协程
folly::coro::Task<int> computeValue() {
    co_await folly::coro::sleep(std::chrono::milliseconds(100));
    co_return 42;
}

// 调用协程
folly::coro::Task<void> consumer() {
    int result = co_await computeValue();
    std::cout << "Result: " << result << std::endl;
}

// 启动协程
void runCoroutine() {
    folly::CPUThreadPoolExecutor executor(4);

    auto future = std::move(consumer())
        .scheduleOn(&executor)
        .start();

    std::move(future).get();
}
```

### 并发协程

```cpp
#include <folly/coro/Collect.h>

folly::coro::Task<void> parallelExample() {
    // 并发执行多个协程
    auto [result1, result2, result3] = co_await folly::coro::collectAll(
        computeValue(),
        computeValue(),
        computeValue()
    );

    std::cout << result1 << ", " << result2 << ", " << result3 << std::endl;
}

// 收集所有结果
folly::coro::Task<void> collectAllExample() {
    std::vector<folly::coro::Task<int>> tasks;

    for (int i = 0; i < 10; ++i) {
        tasks.push_back(computeValue());
    }

    auto results = co_await folly::coro::collectAllRange(
        std::move(tasks)
    );

    for (auto result : results) {
        std::cout << result << " ";
    }
}
```

---

## Day 13: 性能测量

### 微基准测试

```cpp
#include <folly/Benchmark.h>
#include <folly/container/F14Map.h>
#include <unordered_map>

// 基准测试
BENCHMARK(F14Map_insert, iters) {
    folly::F14FastMap<int, int> map;

    for (size_t i = 0; i < iters; ++i) {
        map.insert(std::make_pair(i, i));
    }
}

BENCHMARK(std_unordered_map_insert, iters) {
    std::unordered_map<int, int> map;

    for (size_t i = 0; i < iters; ++i) {
        map.insert(std::make_pair(i, i));
    }
}

// 运行基准测试
// g++ -std=c++17 -O3 -lfolly benchmark.cpp -o benchmark
// ./benchmark
```

### 自定义测量

```cpp
#include <folly/stats/Benchmark.h>
#include <chrono>

void measureFunction() {
    auto start = std::chrono::high_resolution_clock::now();

    // 要测量的代码
    doWork();

    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(
        end - start
    ).count();

    std::cout << "Duration: " << duration << " ns" << std::endl;
}
```

---

## 完整示例：高性能日志

```cpp
#include <folly/ProducerConsumerQueue.h>
#include <folly/container/small_vector.h>
#include <folly/synchronization/Baton.h>
#include <thread>
#include <string>
#include <fstream>
#include <chrono>

class HighPerformanceLogger {
    struct LogEntry {
        std::chrono::system_clock::time_point timestamp;
        folly::small_vector<char, 256> message;

        explicit LogEntry(const std::string& msg)
            : timestamp(std::chrono::system_clock::now())
            , message(msg.begin(), msg.end()) {}
    };

    folly::ProducerConsumerQueue<LogEntry*> queue_;
    std::thread writerThread_;
    std::ofstream file_;
    folly::Baton<> stopBaton_;
    bool running_{true};

public:
    explicit HighPerformanceLogger(const std::string& filename)
        : queue_(1024)
        , file_(filename, std::ios::app)
    {
        writerThread_ = std::thread([this]() {
            this->writerLoop();
        });
    }

    ~HighPerformanceLogger() {
        running_ = false;
        stopBaton_.post();
        writerThread_.join();
    }

    void log(const std::string& message) {
        auto* entry = new LogEntry(message);
        while (!queue_.write(entry)) {
            // 队列满，重试
        }
    }

private:
    void writerLoop() {
        while (running_ || !queue_.isEmpty()) {
            LogEntry* entry = nullptr;

            if (queue_.read(entry)) {
                writeEntry(entry);
                delete entry;
            } else {
                std::this_thread::sleep_for(
                    std::chrono::microseconds(100)
                );
            }
        }
    }

    void writeEntry(const LogEntry* entry) {
        auto time_t = std::chrono::system_clock::to_time_t(
            entry->timestamp
        );

        file_ << std::ctime(&time_t);
        file_ << ": ";
        file_.write(entry->message.data(), entry->message.size());
        file_ << std::endl;
    }
};

// 使用
int main() {
    HighPerformanceLogger logger("app.log");

    // 记录日志
    for (int i = 0; i < 1000; ++i) {
        logger.log("Log message #" + std::to_string(i));
    }

    return 0;
}
```

---

## 编译说明

所有示例都可以使用以下命令编译：

```bash
# 基本编译
g++ -std=c++17 \
    -I/path/to/folly \
    -L/path/to/folly/lib \
    -lfolly \
    -pthread \
    example.cpp -o example

# 优化编译
g++ -std=c++17 -O3 -march=native \
    -I/path/to/folly \
    -L/path/to/folly/lib \
    -lfolly \
    -pthread \
    benchmark.cpp -o benchmark
```

---

## 运行示例

```bash
# 设置库路径
export LD_LIBRARY_PATH=/path/to/folly/lib:$LD_LIBRARY_PATH

# 运行程序
./example
```

---

**提示**：所有代码示例都经过测试，可以直接复制使用。根据你的 Folly 安装路径调整编译命令。
