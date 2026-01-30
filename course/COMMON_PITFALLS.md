# Folly 常见错误和陷阱

## 概述

本文档列出使用 Folly 时的常见错误、陷阱和最佳实践，帮助你避免这些坑。

---

## 🔴 严重错误

### 错误 1: 释放 Arena 后继续使用指针

**问题代码**:
```cpp
void* dangerous() {
    folly::SysArena arena;
    int* ptr = static_cast<int*>(arena.allocate(sizeof(int)));
    *ptr = 42;
    return ptr;  // ❌ 危险！
}

void use() {
    int* ptr = dangerous();
    std::cout << *ptr << std::endl;  // ← 崩溃！Arena 已释放
}
```

**正确做法**:
```cpp
// 方式 1: 不要返回 Arena 分配的指针
void safe() {
    folly::SysArena arena;
    int* ptr = static_cast<int*>(arena.allocate(sizeof(int)));
    *ptr = 42;
    // 在 Arena 生命周期内使用 ptr
    std::cout << *ptr << std::endl;
}  // Arena 析构，ptr 也随之失效

// 方式 2: 使用智能指针管理外部内存
struct ExternalDeleter {
    void operator()(void* p) const {
        free(p);  // 或其他释放方式
    }
};

std::unique_ptr<int, ExternalDeleter> safe2() {
    auto* ptr = malloc(sizeof(int));
    return std::unique_ptr<int, ExternalDeleter>(static_cast<int*>(ptr));
}
```

---

### 错误 2: small_vector 迭代器失效

**问题代码**:
```cpp
void iteratorInvalidation() {
    folly::small_vector<int, 4> vec = {1, 2, 3};
    auto it = vec.begin();

    vec.push_back(4);  // 可能安全

    vec.resize(100);   // ❌ 从栈转移到堆，it 失效！

    std::cout << *it << std::endl;  // ← 未定义行为
}
```

**正确做法**:
```cpp
void safeIteration() {
    folly::small_vector<int, 4> vec = {1, 2, 3};

    // 方式 1: 每次使用前重新获取迭代器
    vec.push_back(4);
    auto it = vec.begin();  // 重新获取
    std::cout << *it << std::endl;

    // 方式 2: 避免在可能增长的操作后使用迭代器
    for (size_t i = 0; i < vec.size(); ++i) {
        std::cout << vec[i] << std::endl;  // 使用索引
    }
}
```

---

### 错误 3: 跨线程使用 EventBase

**问题代码**:
```cpp
 folly::EventBase evb;
std::thread t1([&]() { evb.loop(); });

// ❌ 危险：跨线程直接调用
std::thread t2([&]() {
    evb.runInEventBaseThread([]() {
        // 可能在错误的线程执行
    });
});
```

**正确做法**:
```cpp
// 方式 1: 使用 runInEventBaseThread（安全）
folly::EventBase evb;
std::thread t1([&]() { evb.loop(); });

evb.runInEventBaseThread([]() {
    // 这在 EventBase 线程中执行
});

// 方式 2: 每个线程自己的 EventBase
std::vector<std::thread> threads;
std::vector<folly::EventBase*> evbs;

for (int i = 0; i < 4; ++i) {
    evbs.push_back(new folly::EventBase());
    threads.emplace_back([evb = evs.back()]() {
        evb->loopForever();
    });
}
```

---

### 错误 4: Hazard Pointers 未保护就使用

**问题代码**:
```cpp
template <typename T>
class LockFreeStack {
    std::atomic<Node*> head_;

public:
    void push(Node* node) {
        node->next = head_.load();
        while (!head_.compare_exchange_weak(node->next, node)) {
            // CAS 重试
        }
    }

    Node* pop() {
        Node* oldHead = head_.load();
        // ❌ 未保护 oldHead
        Node* newHead = oldHead->next;  // oldHead 可能已被释放！
        head_.store(newHead);
        return oldHead;
    }
};
```

**正确做法**:
```cpp
template <typename T>
class LockFreeStack {
    std::atomic<Node*> head_;
    folly::hazptr_domain<> domain_;

public:
    void push(Node* node) {
        node->next = head_.load();
        while (!head_.compare_exchange_weak(node->next, node)) {
            // CAS 重试
        }
    }

    Node* pop() {
        folly::hazptr_holder<1> holder;
        Node* oldHead = head_.load();

        do {
            if (oldHead == nullptr) return nullptr;

            // ✅ 保护旧节点
            holder.protect(0, oldHead);

            // 再次检查
            if (head_.load() != oldHead) {
                oldHead = head_.load();
                continue;
            }

            Node* newHead = oldHead->next;
            if (head_.compare_exchange_strong(oldHead, newHead)) {
                return oldHead;
            }
        } while (true);
    }
};
```

---

## ⚠️ 常见陷阱

### 陷阱 1: F14Map 的键需要可哈希

**问题代码**:
```cpp
struct BadKey {
    std::string data;
    // ❌ 没有 hash 函数
};

folly::F14FastMap<BadKey, int> map;  // 编译错误！
```

**正确做法**:
```cpp
// 方式 1: 提供哈希函数
struct Key {
    std::string data;
};

struct KeyHash {
    size_t operator()(const Key& key) const {
        return std::hash<std::string>{}(key.data);
    }
};

folly::F14FastMap<Key, int, KeyHash> map;

// 方式 2: 使用简单键
folly::F14FastMap<int, int> map;
folly::F14FastMap<std::string, int> map;
```

---

### 陷阱 2: 忘记 Baton::reset()

**问题代码**:
```cpp
void process() {
    static folly::Baton<> baton;

    // 第一次
    std::thread t([&]() { baton.wait(); });
    baton.post();
    t.join();

    // 第二次
    std::thread t2([&]() { baton.wait(); });  // ❌ 立即返回！
    baton.post();
    t2.join();
}
```

**正确做法**:
```cpp
void process() {
    static folly::Baton<> baton;

    // 第一次
    std::thread t([&]() { baton.wait(); });
    baton.post();
    t.join();

    // ✅ 重置
    baton.reset();

    // 第二次
    std::thread t2([&]() { baton.wait(); });
    baton.post();
    t2.join();
}
```

---

### 陷阱 3: AtomicHashMap 容量固定

**问题代码**:
```cpp
folly::AtomicHashMap<int, int> map(100);

// 插入超过容量
for (int i = 0; i < 1000; ++i) {
    map.insert(std::make_pair(i, i));  // ❌ 超过 100 会失败
}
```

**正确做法**:
```cpp
// ✅ 预估足够大的容量
folly::AtomicHashMap<int, int> map(10000);

// 或使用其他容器
folly::F14FastMap<int, int> map;  // 动态扩容
```

---

### 陷阱 4: 协程未调度

**问题代码**:
```cpp
folly::coro::Task<int> compute() {
    co_return 42;
}

void bad() {
    auto task = compute();
    // ❌ 忘记调度，协程从未执行
}
```

**正确做法**:
```cpp
folly::coro::Task<int> compute() {
    co_return 42;
}

folly::CPUThreadPoolExecutor executor(4);

void good() {
    // ✅ 调度协程
    auto future = compute().scheduleOn(&executor).start();

    // 或直接运行（在同一线程）
    auto future = compute().scheduleOn(folly::CPUThreadPoolExecutor(1)).start();
}
```

---

### 陷阱 5: 异构查找的类型匹配

**问题代码**:
```cpp
folly::F14FastMap<std::string, int> map;
map["hello"] = 42;

// ❌ 不能用不同类型查找（除非支持）
const char* key = "hello";
auto it = map.find(key);  // 可能失败！
```

**正确做法**:
```cpp
// ✅ 使用 StringPiece（支持异构查找）
folly::F14FastMap<std::string, int> map;
map["hello"] = 42;

folly::StringPiece key = "hello";
auto it = map.find(key);  // 成功！
```

---

## 🟡 性能陷阱

### 陷阱 6: 意外的拷贝

**问题代码**:
```cpp
void process(std::vector<int> vec) {  // ❌ 拷贝整个 vector
    // ...
}

std::vector<int> data = {1, 2, 3};
process(data);  // 拷贝
```

**正确做法**:
```cpp
// ✅ 使用引用或移动
void process(const std::vector<int>& vec) {  // 引用
    // ...
}

void process(std::vector<int>&& vec) {  // 移动
    // ...
}

// 或使用 Folly 容器
void process(folly::small_vector<int, 8> vec) {  // 小对象拷贝快
    // ...
}
```

---

### 陷阱 7: 频繁的小分配

**问题代码**:
```cpp
void processMany() {
    for (int i = 0; i < 100000; ++i) {
        auto* obj = new MyObject();  // ❌ 100K 次分配
        // 使用 obj
        delete obj;  // 100K 次释放
    }
}
```

**正确做法**:
```cpp
// ✅ 使用 Arena
void processMany() {
    folly::SysArena arena;
    for (int i = 0; i < 100000; ++i) {
        auto* obj = new (arena.allocate(sizeof(MyObject))) MyObject();
        // 使用 obj
    }
}  // 一次性释放
```

---

### 陷阱 8: 锁竞争

**问题代码**:
```cpp
std::mutex mutex;
std::unordered_map<int, int> map;

void threadFunc() {
    for (int i = 0; i < 10000; ++i) {
        std::lock_guard<std::mutex> lock(mutex);  // ❌ 锁竞争
        map[i] = i * 2;
    }
}
```

**正确做法**:
```cpp
// ✅ 使用并发容器
folly::AtomicHashMap<int, int> map(100000);

void threadFunc() {
    for (int i = 0; i < 10000; ++i) {
        map.insert(std::make_pair(i, i * 2));  // Wait-Free
    }
}

// 或使用分区锁
std::array<std::mutex, 16> mutexes;
std::array<std::unordered_map<int, int>, 16> maps;

void threadFunc() {
    for (int i = 0; i < 10000; ++i) {
        int shard = i % 16;
        std::lock_guard<std::mutex> lock(mutexes[shard]);
        maps[shard][i] = i * 2;
    }
}
```

---

## 🟢 最佳实践

### 实践 1: 使用类型别名提高可读性

```cpp
// ❌ 差：冗长的类型
folly::F14FastMap<std::string, std::vector<int>> map;

// ✅ 好：类型别名
using UserPosts = folly::F14FastMap<std::string, std::vector<int>>;
UserPosts userPosts;
```

---

### 实践 2: RAII 管理资源

```cpp
// ❌ 差：手动管理
FILE* f = fopen("file.txt", "r");
// 使用 f
if (error) {
    fclose(f);  // 容易忘记
    return;
}
fclose(f);

// ✅ 好：RAII
std::unique_ptr<FILE, decltype(&fclose)> file(fopen("file.txt", "r"), fclose);
// 使用 file.get()
```

---

### 实践 3: 使用 folly::Synchronized

```cpp
// ❌ 差：手动加锁
std::mutex mutex;
std::vector<int> vec;

void threadSafePush(int value) {
    std::lock_guard<std::mutex> lock(mutex);
    vec.push_back(value);
}

int threadSafePop() {
    std::lock_guard<std::mutex> lock(mutex);
    if (vec.empty()) return -1;
    int value = vec.back();
    vec.pop_back();
    return value;
}

// ✅ 好：使用 Synchronized
folly::Synchronized<std::vector<int>> vec;

void threadSafePush(int value) {
    vec.withWLock([&](auto& v) {
        v.push_back(value);
    });
}

int threadSafePop() {
    return vec.withWLock([&](auto& v) -> int {
        if (v.empty()) return -1;
        int value = v.back();
        v.pop_back();
        return value;
    });
}
```

---

### 实践 4: 编译时检查

```cpp
// ✅ 使用 static_assert
static_assert(sizeof(int) == 4, "int must be 4 bytes");

// ✅ 使用 concepts (C++20)
template <typename T>
concept Hashable = requires(T t) {
    { std::hash<T>{}(t) } -> std::convertible_to<std::size_t>;
};

template <Hashable T>
using FastMap = folly::F14FastMap<T, int>;
```

---

### 实践 5: 性能测试验证

```cpp
// ✅ 总是测量
BENCHMARK(MyOptimization, iters) {
    // 你的优化代码
}

BENCHMARK(OriginalVersion, iters) {
    // 原始代码
}

// 运行并对比
```

---

## 📋 检查清单

### 编译前检查

- [ ] 启用了优化 (-O2 或 -O3)
- [ ] 设置了正确的 C++ 标准 (-std=c++17 或 -std=c++20)
- [ ] 包含了必要的头文件
- [ ] 链接了正确的库

### 运行时检查

- [ ] 使用了 ASAN/TSAN 检测
- [ ] 使用了 Valgrind 检测内存泄漏
- [ ] 测试了不同数据规模
- [ ] 测试了多线程场景

### 性能检查

- [ ] 使用 perf 分析热点
- [ ] 使用 Benchmark 测试性能
- [ ] 对比了标准库实现
- [ ] 测量了实际负载

### 代码审查检查

- [ ] 没有内存泄漏
- [ ] 没有数据竞争
- [ ] 没有未定义行为
- [ ] 异常安全
- [ ] 迭代器正确使用

---

## 🔗 相关资源

- **FAQ**: FAQ.md
- **故障排查**: TROUBLESHOOTING.md
- **生产清单**: PRODUCTION_CHECKLIST.md
- **面试题**: INTERVIEW_QUESTIONS.md

---

**记住**: 避免错误的第一步是了解错误。希望这些例子能帮助你少走弯路！ 🚀

---

**更新日期**: 2024-01-30
**版本**: v1.0
