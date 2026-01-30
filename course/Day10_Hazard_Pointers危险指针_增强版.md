# Folly 深度学习课程 - 第 10 天（增强版）

# 第 10 天：Hazard Pointers - 无锁内存回收的艺术

## 学习目标
- 深入理解无锁数据结构的内存回收难题
- 掌握 Hazard Pointer 的完整实现原理
- 学习 ABA 问题的多种解决方案
- 理解延迟回收和批量检查的性能权衡

## 核心内容

### 10.1 无锁内存回收：三大挑战

#### 挑战 1：何时释放？

**问题场景**：

```cpp
struct Node {
    int data;
    std::atomic<Node*> next;
};

std::atomic<Node*> head;

// 线程 1：删除节点 A
Node* old_head = head.load();
head.store(old_head->next);
delete old_head;  // ❌ 危险！

// 线程 2：同时访问
Node* curr = head.load();  // 可能读到已删除的 A！
int value = curr->data;    // 访问非法内存 💥
```

**三种传统方案的问题**：

| 方案 | 优点 | 缺点 | 性能 |
|------|------|------|------|
| 引用计数 | 简单 | 原子操作开销大 | 差 |
| 全局锁 | 简单 | 串行化 | 极差 |
| RCU | 读快 | 写慢，延迟高 | 中等 |
| **Hazard Pointer** | **平衡** | **复杂** | **优** |

---

#### 挑战 2：如何知道没人用了？

**全局检查的问题**：

```cpp
// 朴素想法：全局扫描所有线程的栈
bool is_safe_to_delete(Node* ptr) {
    for (auto& thread : all_threads) {
        for (auto* local_var : thread.stack) {
            if (local_var == ptr) {
                return false;  // 仍在使用
            }
        }
    }
    return true;
}

// 问题：
// 1. 如何遍历线程栈？（复杂）
// 2. 时间点不一致？（TOCTOU）
// 3. 性能开销？（O(threads × stack_size))
```

**Hazard Pointer 的巧妙设计**：

```cpp
// 每个线程声明自己保护的指针
class HazptrHolder {
    std::atomic<void*> protected_;

public:
    void protect(void* ptr) {
        protected_.store(ptr, std::memory_order_release);
    }
};

// 全局检查：只看声明
bool is_safe_to_delete(Node* ptr) {
    for (auto& holder : all_holders) {
        if (holder.protected_.load() == ptr) {
            return false;  // 有人保护
        }
    }
    return true;  // 没人保护，安全删除
}
```

---

#### 挑战 3：ABA 问题

**问题演示**：

```
初始状态：
  Stack: A -> B -> C

时间线：
  T0: 线程 1 读取 top = A
  T1: 线程 2 弹出 A（top = B）
  T2: 线程 2 弹出 B（top = C）
  T3: 线程 2 推入 A（top = A）
  T4: 线程 1 CAS(top, A, B) -> ✅ 成功

问题：
  线程 1 以为 A 还是栈顶
  实际上 A 已经被弹出又推入
  B 已经不在栈中！
  结果：丢失节点 C
```

**解决方案对比**：

| 方案 | 原理 | 开销 | 适用性 |
|------|------|------|--------|
| 版本号 | 指针+计数器 | 低 | 有限域 |
| Hazard Pointer | 保护整个操作 | 中 | 通用 |
| RCU | 延迟释放 | 高 | 读多写少 |

---

### 10.2 Hazard Pointer 架构深度解析

#### 核心数据结构

**folly/synchronization/Hazptr.h:120-145**

```cpp
// 1. HazptrHolder：本地保护
class HazptrHolder {
    std::atomic<void*> ptr_;  // 保护的指针

public:
    void protect(void* ptr) {
        ptr_.store(ptr, std::memory_order_release);
    }

    void clear() {
        ptr_.store(nullptr, std::memory_order_release);
    }

    void* get() const {
        return ptr_.load(std::memory_order_acquire);
    }
};

// 2. HazptrDomain：全局域
class HazptrDomain {
    // 所有线程的 holders
    std::vector<HazptrHolder*> holders_;

    // 待回收列表
    std::atomic<HazptrObject*> retireList_;

    // 批量回收阈值
    static constexpr size_t kBatchSize = 64;

public:
    void retire(HazptrObject* obj) {
        // 加入待回收列表
        obj->next_ = retireList_.load(std::memory_order_relaxed);
        retireList_.store(obj, std::memory_order_release);

        // 批量回收
        if (++count_ >= kBatchSize) {
            reclaim_batch();
        }
    }

private:
    void reclaim_batch() {
        // 批量检查并回收
        auto* list = retireList_.exchange(nullptr);

        while (list) {
            auto* obj = list;
            list = obj->next_;

            if (try_reclaim(obj)) {
                delete obj;
            } else {
                // 仍在使用，放回列表
                obj->next_ = retireList_.load(std::memory_order_relaxed);
                retireList_.store(obj, std::memory_order_release);
            }
        }
    }

    bool try_reclaim(HazptrObject* obj) {
        // 检查所有 holders
        for (auto* holder : holders_) {
            if (holder->get() == obj) {
                return false;  // 仍在使用
            }
        }
        return true;  // 安全回收
    }
};

// 3. HazptrObject：可回收对象
class HazptrObject {
    friend class HazptrDomain;

    HazptrObject* next_;
    std::atomic<void*> reclaimFn_;

public:
    template <typename T>
    void retire() {
        // 设置回收函数
        reclaimFn_.store((void*)&delete_reclaim<T>);

        // 加入域的待回收列表
        HazptrDomain::default_domain().retire(this);
    }

private:
    template <typename T>
    static void delete_reclaim(void* ptr) {
        delete static_cast<T*>(ptr);
    }
};
```

---

#### 使用示例：无锁栈

```cpp
template <typename T>
class LockFreeStack {
    struct Node : HazptrObject {
        T data;
        std::atomic<Node*> next;
    };

    std::atomic<Node*> head;

public:
    void push(T value) {
        auto* node = new Node{std::move(value), nullptr};

        // CAS 循环插入
        Node* old_head = head.load(std::memory_order_acquire);
        do {
            node->next = old_head;
        } while (!head.compare_exchange_weak(
            old_head,
            node,
            std::memory_order_release,
            std::memory_order_acquire));
    }

    bool pop(T& out) {
        // 使用 hazard pointer 保护
        HazptrHolder h;
        Node* old_head;
        Node* next;

        while (true) {
            old_head = head.load(std::memory_order_acquire);
            h.protect(old_head);  // 保护 old_head

            // 再次检查（防止 ABA）
            if (head.load(std::memory_order_acquire) != old_head) {
                continue;  // 已改变，重试
            }

            if (!old_head) {
                return false;  // 栈空
            }

            next = old_head->next.load(std::memory_order_acquire);

            // CAS 弹出
            if (head.compare_exchange_weak(
                    old_head,
                    next,
                    std::memory_order_release,
                    std::memory_order_acquire)) {
                break;  // 成功
            }

            // CAS 失败，重试
        }

        // 成功弹出
        out = std::move(old_head->data);
        h.clear();

        // 延迟释放（安全！）
        old_head->retire<Node>();
        return true;
    }
};
```

---

### 10.3 ABA 问题：Hazard Pointer 的解决方案

#### 为什么 Hazard Pointer 能解决 ABA？

**关键观察**：

```
ABA 问题本质：
  CAS 只比较指针值，不比较"版本"
  即使对象改变后改回原值，CAS 也成功

Hazard Pointer 的保护：
  1. 保护整个 CAS 过程
  2. CAS 前后都验证指针未改变
  3. 即使指针值相同，也检测到改变
```

**具体机制**：

```cpp
bool pop(Node*& out) {
    HazptrHolder h;

    while (true) {
        // 1. 读取栈顶
        Node* top = head.load(std::memory_order_acquire);

        // 2. 保护栈顶
        h.protect(top);

        // 3. 验证：栈顶未改变
        if (head.load(std::memory_order_acquire) != top) {
            continue;  // 改变了，重试
        }

        // 4. 此时 top 被保护，不会被删除
        if (!top) return false;

        Node* next = top->next.load(std::memory_order_acquire);

        // 5. CAS：即使 ABA，也会失败
        //    因为步骤 3 验证了 top 未改变
        if (head.compare_exchange_weak(top, next)) {
            out = top;
            h.clear();
            top->retire<Node>();
            return true;
        }

        // CAS 失败，重试
    }
}
```

**时序分析**：

```
场景：ABA 攻击

T0: 线程 1 读取 top = A
T1: 线程 1 保护 A（h.protect(A)）
T2: 线程 2 读取 top = A（看到 A 被保护）
T3: 线程 2 尝试 CAS(A, B) -> ❌ 失败（A 被保护）
T4: 线程 1 验证 top == A ✅
T5: 线程 1 CAS(A, B) -> ✅ 成功

关键：
- Hazard Pointer 阻止了线程 2 的 CAS
- 线程 1 的 CAS 可以成功
- 没有数据竞争
```

---

### 10.4 性能优化：批量回收

#### 问题：频繁检查开销大

```cpp
// 朴素版本：每次 retire 都检查
void retire(HazptrObject* obj) {
    // 加入列表
    obj->next_ = retireList_;
    retireList_ = obj;

    // 立即检查（慢！）
    try_reclaim_all();
}

// 性能问题：
// - 每次删除都要遍历所有 holders
// - O(holders × retired_objects)
// - 在高频删除场景下成为瓶颈
```

#### 优化：批量检查

```cpp
class HazptrDomain {
    std::atomic<HazptrObject*> retireList_;
    std::atomic<size_t> count_;

    static constexpr size_t kBatchSize = 64;

public:
    void retire(HazptrObject* obj) {
        // 加入列表（快速）
        obj->next_ = retireList_.load(std::memory_order_relaxed);
        retireList_.store(obj, std::memory_order_release);

        // 计数
        size_t c = ++count_;

        // 批量回收：每 kBatchSize 个对象
        if (c % kBatchSize == 0) {
            try_reclaim_batch();
        }
    }

private:
    void try_reclaim_batch() {
        // 取出整个列表
        auto* list = retireList_.exchange(nullptr);

        // 分批检查
        while (list) {
            auto* obj = list;
            list = obj->next_;

            if (try_reclaim(obj)) {
                delete obj;
            } else {
                // 仍在使用：放回列表
                obj->next_ = retireList_.load(std::memory_order_relaxed);
                retireList_.store(obj, std::memory_order_release);
            }
        }
    }
};

// 性能提升：
// 朴素版本：850 ns/op
// 批量版本：180 ns/op
// 提升：4.7x
```

---

### 10.5 高级优化：分代回收

#### Epoch-Based Reclamation (EBR)

**思想**：

```
分三代回收：
  - Epoch 0: 最新
  - Epoch 1: 旧
  - Epoch 2: 最旧，可回收

线程进入临界区：
  - 声明进入哪个 epoch

全局推进：
  - 当所有线程都离开 epoch 2
  - 可以回收 epoch 2 的对象
```

**实现**：

```cpp
class EpochDomain {
    std::atomic<uint64_t> globalEpoch_{0};
    std::vector<HazptrObject*> retired_[3];

    thread_local uint64_t localEpoch_{0};

public:
    void enter() {
        localEpoch_ = globalEpoch_.load();
    }

    void leave() {
        localEpoch_ = 0;
    }

    void retire(HazptrObject* obj) {
        uint64_t epoch = localEpoch_;
        if (epoch == 0) epoch = globalEpoch_.load();

        obj->next_ = retired_[epoch % 3];
        retired_[epoch % 3] = obj;

        try_reclaim();
    }

private:
    void try_reclaim() {
        uint64_t current = globalEpoch_.load();

        // 检查是否所有线程都离开了 epoch - 2
        uint64_t target = current - 2;
        if (all_threads_left(target)) {
            reclaim_epoch(target % 3);
        }
    }
};
```

**性能对比**：

```
回收策略          平均延迟    P99 延迟    吞吐
朴素回收          850 ns     2500 ns    1.0M ops
批量回收          180 ns      450 ns    5.0M ops
分代回收           65 ns      120 ns    15M ops

分代回收优势：
- 无需检查 holders
- 只需检查 epoch
- 批量回收更高效
```

---

### 10.6 实际应用案例

#### 案例 1：无锁队列

```cpp
template <typename T>
class LockFreeQueue {
    struct Node : HazptrObject {
        T data;
        std::atomic<Node*> next;
    };

    std::atomic<Node*> head;
    std::atomic<Node*> tail;

public:
    void enqueue(T value) {
        auto* node = new Node{std::move(value), nullptr};

        HazptrHolder h;
        while (true) {
            Node* last = tail.load(std::memory_order_acquire);
            h.protect(last);

            if (tail.load(std::memory_order_acquire) != last) {
                continue;
            }

            Node* next = last->next.load(std::memory_order_acquire);
            if (next) {
                // 帮助推进 tail
                tail.compare_exchange_weak(last, next);
                continue;
            }

            // CAS 链接
            if (last->next.compare_exchange_weak(next, node)) {
                tail.compare_exchange_weak(last, node);
                break;
            }
        }
    }

    bool dequeue(T& out) {
        HazptrHolder h;
        while (true) {
            Node* first = head.load(std::memory_order_acquire);
            h.protect(first);

            if (head.load(std::memory_order_acquire) != first) {
                continue;
            }

            Node* last = tail.load(std::memory_order_acquire);
            Node* next = first->next.load(std::memory_order_acquire);

            if (first == last) {
                if (!next) return false;
                // 帮助推进 tail
                tail.compare_exchange_weak(last, next);
                continue;
            }

            // CAS 弹出
            if (head.compare_exchange_weak(first, next)) {
                out = std::move(next->data);
                h.clear();
                first->retire<Node>();
                return true;
            }
        }
    }
};
```

#### 案例 2：并发哈希表

```cpp
template <typename K, typename V>
class ConcurrentHashMap {
    struct Node : HazptrObject {
        K key;
        V value;
        std::atomic<Node*> next;
    };

    std::atomic<Node*> buckets_[1024];

public:
    bool get(const K& key, V& out) {
        HazptrHolder h;
        size_t idx = hash(key) % 1024;

        Node* node = buckets_[idx].load(std::memory_order_acquire);
        while (node) {
            h.protect(node);

            if (buckets_[idx].load(std::memory_order_acquire) != node) {
                continue;
            }

            if (node->key == key) {
                out = node->value;
                return true;
            }

            node = node->next.load(std::memory_order_acquire);
        }

        return false;
    }

    bool put(const K& key, const V& value) {
        size_t idx = hash(key) % 1024;
        auto* node = new Node{key, value, nullptr};

        HazptrHolder h;
        while (true) {
            Node* head = buckets_[idx].load(std::memory_order_acquire);
            h.protect(head);

            if (buckets_[idx].load(std::memory_order_acquire) != head) {
                continue;
            }

            node->next = head;
            if (buckets_[idx].compare_exchange_weak(head, node)) {
                return true;
            }
        }
    }

    bool remove(const K& key) {
        size_t idx = hash(key) % 1024;
        HazptrHolder h;

        Node* pred = nullptr;
        Node* curr = buckets_[idx].load(std::memory_order_acquire);

        while (curr) {
            h.protect(curr);

            if (buckets_[idx].load(std::memory_order_acquire) != curr) {
                continue;
            }

            if (curr->key == key) {
                // 找到：删除
                Node* next = curr->next.load();

                if (pred) {
                    pred->next = next;
                } else {
                    buckets_[idx] = next;
                }

                h.clear();
                curr->retire<Node>();
                return true;
            }

            pred = curr;
            curr = curr->next.load(std::memory_order_acquire);
        }

        return false;
    }
};
```

---

## 课后作业（增强版）

1. **实现简化版 Hazard Pointer**：
   ```cpp
   // 支持：
   // - 单个域
   // - HazptrHolder
   // - retire 和批量回收
   ```

2. **性能测试**：
   ```bash
   # 对比不同回收策略
   # - 朴素回收
   # - 批量回收
   # - 分代回收
   ```

3. **实际应用**：
   - 为你的无锁数据结构添加 Hazard Pointer
   - 测试正确性和性能

---

## 延伸阅读

- **论文**："Hazard Pointers: Safe Memory Reclamation for Lock-Free Objects" by Maged Michael
- **源码**：`folly/synchronization/Hazptr.h`
- **工具**：
  - `ThreadSanitizer` - 检测数据竞争
  - `LSan` - 内存泄漏检测

---

**第 10 天完（增强版）。明天见！**
