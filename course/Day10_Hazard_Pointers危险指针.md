# Folly 深度学习课程 - 第 10 天

# 第 10 天：Hazard Pointers（危险指针）

## 学习目标
- 理解无锁数据结构的内存回收问题
- 掌握 Hazard Pointer 的实现原理
- 学习 ABA 问题的解决方案

## 核心内容

### 10.1 无锁内存回收的挑战

**问题：如何安全释放无锁结构中的节点？**

```cpp
struct Node {
    int data;
    Node* next;
};

std::atomic<Node*> head;

// 线程 1：删除节点
Node* old_head = head.load();
head.store(old_head->next);
delete old_head;  // 危险！其他线程可能还在使用

// 线程 2：同时读取
Node* curr = head.load();
int value = curr->data;  // 可能访问已释放的内存！
```

**传统方案的问题**：
- **引用计数**：需要原子操作，开销大
- **RCU（Read-Copy-Update）**：复杂，延迟释放
- **Hazard Pointer**：平衡性能和复杂性

### 10.2 Hazard Pointer 的设计

**核心思想**：线程声明要保护的指针，其他线程延迟释放

```cpp
#include <folly/synchronization/Hazptr.h>

struct Node {
    int data;
    std::atomic<Node*> next;
};

std::atomic<Node*> head;

// 读取操作
void traverse() {
    hazptr_local<1> h;  // 本地 hazard pointer

    Node* curr;
    do {
        curr = head.load(std::memory_order_acquire);
        h.protect(0, curr);  // 保护 curr
    } while (curr != head.load(std::memory_order_acquire));

    // 现在安全地使用 curr
    while (curr) {
        process(curr->data);
        curr = curr->next;
    }
}

// 删除操作
void remove(int target) {
    hazptr_local<1> h;

    Node* pred = nullptr;
    Node* curr = nullptr;

    do {
        pred = nullptr;
        curr = head.load(std::memory_order_acquire);

        h.protect(0, curr);  // 保护 curr

        // 查找目标节点
        while (curr && curr->data != target) {
            pred = curr;
            curr = curr->next;
            h.protect(0, curr);  // 更新保护
        }

        if (!curr) return;  // 未找到

    } while (!pred && !head.compare_exchange_strong(curr, curr->next));

    // 从链表移除
    if (pred) {
        pred->next.store(curr->next, std::memory_order_release);
    }

    // 延迟释放
    curr->retire();  // 标记为可释放，但不是立即
}
```

### 10.3 Hazard Pointer 的实现

**全局对象池**：

```cpp
class HazptrObject {
    std::atomic<void*> reclaim_;  // 回收函数
    std::atomic<HazptrObject*> next_;

public:
    template <typename T>
    void retire() {
        // 设置回收函数
        reclaim_.store((void*)&delete_reclaim<T>, std::memory_order_release);

        // 加入待回收列表
        HazptrDomain::default_domain().retire(this);
    }

private:
    template <typename T>
    static void delete_reclaim(void* ptr) {
        delete static_cast<T*>(ptr);
    }
};
```

**线程本地 hazard pointers**：

```cpp
class HazptrHolder {
    std::atomic<void*> ptr_;  // 保护的指针

public:
    void protect(void* ptr) {
        ptr_.store(ptr, std::memory_order_release);
    }

    void clear() {
        ptr_.store(nullptr, std::memory_order_release);
    }
};

thread_local std::array<HazptrHolder, kMaxHazptrs> holders_;
```

**回收检查**：

```cpp
bool try_reclaim(HazptrObject* obj) {
    // 检查所有线程的 hazard pointers
    for (auto& holders : all_thread_holders_) {
        for (auto& holder : holders) {
            if (holder.ptr() == obj) {
                return false;  // 仍在使用
            }
        }
    }

    // 安全释放
    obj->reclaim();
    return true;
}
```

### 10.4 批量回收

**问题**：每次删除都检查太慢

**解决方案**：批量检查

```cpp
class HazptrDomain {
    std::atomic<HazptrObject*> pending_list_;

public:
    void retire(HazptrObject* obj) {
        // 加入待回收列表
        obj->next_ = pending_list_.load(std::memory_order_relaxed);
        pending_list_.store(obj, std::memory_order_release);

        // 每 N 个对象触发一次批量回收
        if (count_++ % kBatchSize == 0) {
            try_reclaim_batch();
        }
    }

private:
    void try_reclaim_batch() {
        auto* list = pending_list_.exchange(nullptr);

        while (list) {
            auto* obj = list;
            list = obj->next_;

            if (try_reclaim(obj)) {
                // 成功回收
            } else {
                // 仍在使用，放回列表
                obj->next_ = pending_list_.load(std::memory_order_relaxed);
                pending_list_.store(obj, std::memory_order_release);
            }
        }
    }
};
```

### 10.5 ABA 问题

**问题**：指针改变后又改回原值

```cpp
// 初始状态
// Stack: A -> B -> C

// 线程 1 读取 top = A

// 线程 2 修改
// pop A:  top = B
// pop B:  top = C
// push A: top = A -> C

// 线程 1 尝试弹出
// CAS(top, A, B)
// 成功！但 A 已经不在栈顶了
```

**Hazard Pointer 的解决方案**：

```cpp
bool pop(Node*& out) {
    hazptr_local<1> h;

    Node* top;
    Node* next;

    do {
        top = head.load(std::memory_order_acquire);
        h.protect(0, top);  // 保护 top

        if (!top) return false;

        next = top->next;

        // 再次检查（top 可能已改变）
        if (head.load(std::memory_order_acquire) != top) {
            continue;  // 重试
        }

    } while (!head.compare_exchange_weak(top, next));

    out = top;
    return true;
}
```

**关键点**：
- **保护整个操作**：hazard pointer 保护整个 CAS 过程
- **双重检查**：CAS 前后都验证 top 未改变
- **避免 ABA**：即使指针值相同，也检测到改变

### 10.6 性能优化

**优化 1：线程本地批量回收**

```cpp
thread_local std::vector<HazptrObject*> local_retire_list_;

void retire(HazptrObject* obj) {
    local_retire_list_.push_back(obj);

    if (local_retire_list_.size() >= kLocalBatchSize) {
        // 批量提交到全局域
        HazptrDomain::default_domain().retire_batch(local_retire_list_);
        local_retire_list_.clear();
    }
}
```

**优化 2：分代回收**

```cpp
class HazptrDomain {
    std::atomic<uint64_t> global_epoch_;
    thread_local uint64_t local_epoch_;

    void reclaim() {
        uint64_t epoch = global_epoch_.fetch_add(1);

        // 等待所有线程到达新 epoch
        for (auto& e : all_thread_epochs_) {
            while (e.load() < epoch) {
                // 自旋等待
            }
        }

        // 现在安全回收旧对象
        reclaim_old_objects(epoch);
    }
};
```

## 性优启示 #10：安全与性能的平衡

Hazard Pointers 展示了无锁编程的复杂性：
1. **延迟回收**：平衡安全性和及时性
2. **批量操作**：减少检查开销
3. **线程本地**：减少全局竞争

## 课后作业

1. 实现 Hazard Pointer 的简化版本
2. 比较不同回收策略的性能
3. 分析 ABA 问题的各种解决方案

---

**第 10 天完。明天见！**
