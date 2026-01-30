# Folly 深度学习课程 - 第 7 天

# 第 7 天：Arena 内存分配器

## 学习目标
- 理解 Arena 分配器的设计理念
- 掌握批量分配技术
- 学习内存池和重用策略

## 核心内容

### 7.1 Arena 的动机

**问题**：频繁的 malloc/free 开销

```cpp
// 场景：解析 JSON
struct JSONValue {
    std::string key;
    std::string value;
    std::vector<JSONValue*> children;
};

// 每个字符串和向量都单独分配
// 大量的 malloc/free 调用
```

**代价**：
- **malloc 开销**：每次分配需要元数据和查找
- **碎片化**：小分配导致内存碎片
- **缓存不友好**：对象分散在堆上

### 7.2 Arena 的设计

**核心思想**：批量分配，统一释放

```cpp
#include <folly/memory/Arena.h>

folly::SysArena arena;

// 所有分配都从 Arena 获取
void* ptr1 = arena.allocate(64);
void* ptr2 = arena.allocate(128);
void* ptr3 = arena.allocate(32);

// 无需单独释放
// Arena 析构时统一释放所有内存
```

**优势**：
- **减少 malloc 调用**：批量分配大块
- **提高局部性**：相关对象存储在一起
- **简化生命周期**：无需追踪单个对象

### 7.3 Arena 的实现

**内部结构**：

```cpp
template <class Alloc>
class Arena {
    struct Block {
        Block* next_;
        size_t size_;
        char data_[1];  // 柔性数组

        char* start() { return data_; }
    };

    boost::intrusive::slist<
        Block,
        boost::intrusive::cache_last<true>
    > blocks_;

    Block* currentBlock_;
    char* ptr_;        // 当前分配位置
    char* end_;        // 当前块结束位置
    size_t totalAllocatedSize_;
    size_t bytesUsed_;
};
```

**分配算法**：

```cpp
void* allocate(size_t size) {
    size = roundUp(size, 8);  // 对齐

    bytesUsed_ += size;

    // 快速路径：当前块有空间
    if (FOLLY_LIKELY((size_t)(end_ - ptr_) >= size)) {
        char* r = ptr_;
        ptr_ += size;
        return r;
    }

    // 慢速路径：需要新块
    return allocateSlow(size);
}
```

**allocateSlow 实现**：

```cpp
void* allocateSlow(size_t size) {
    // 检查是否可以重用现有块
    if (canReuseExistingBlock(size)) {
        currentBlock_++;
        ptr_ = align(currentBlock_->start());
        end_ = currentBlock_->start() + blockSize_;
        return allocate(size);  // 重试快速路径
    }

    // 需要分配新块
    size_t blockSize = calculateBlockSize(size);
    Block* newBlock = allocateBlock(blockSize);
    blocks_.push_back(newBlock);
    currentBlock_ = newBlock;

    ptr_ = align(newBlock->start() + size);
    end_ = newBlock->start() + blockSize_;

    return newBlock->start();
}
```

### 7.4 块大小选择策略

**好的大小（goodSize）**：

```cpp
// ArenaAllocatorTraits 可以自定义
template <>
struct ArenaAllocatorTraits<MallocAllocator> {
    static size_t goodSize(const MallocAllocator&, size_t size) {
        // 向上舍入到 4KB 的倍数（典型页大小）
        return roundUp(size, 4096);
    }
};
```

**好处**：
- **减少系统调用**：4KB 对齐的块由 mmap 直接提供
- **减少碎片**：块大小对齐
- **提高利用率**：多个小分配共享一个大块

### 7.5 大对象优化

**问题**：大对象浪费块空间

**解决方案**：大对象单独分配

```cpp
void* allocate(size_t size) {
    // 大对象（> 块大小的 1/4）单独分配
    if (size > blockSize_ / 4) {
        LargeBlock* large = allocateLarge(size);
        largeBlocks_.push_back(large);
        return large->data();
    }

    // 小对象从当前块分配
    return allocateFromBlock(size);
}
```

**好处**：
- **避免浪费**：大对象不占用普通块空间
- **快速分配**：小对象不受大对象影响

### 7.6 Arena 的重用

**场景**：持久化的 Arena

```cpp
class PersistentArena {
    folly::SysArena arena_;

public:
    template <typename T, typename... Args>
    T* create(Args&&... args) {
        void* mem = arena_.allocate(sizeof(T));
        return new (mem) T(std::forward<Args>(args)...);
    }

    void clear() {
        arena_.clear();  // 重置 Arena，保留块
        // 后续分配重用现有块
    }
};
```

**clear() 实现**：

```cpp
void clear() {
    bytesUsed_ = 0;
    freeLargeBlocks();  // 释放大对象块

    if (blocks_.empty()) {
        return;
    }

    // 重置到第一个块
    currentBlock_ = blocks_.begin();
    ptr_ = align(currentBlock_->start());
    end_ = currentBlock_->start() + blockSize_;
}
```

### 7.7 线程本地 Arena

**跨线程的 Arena**：

```cpp
class ThreadLocalArena {
    folly::SysArena arena_;

public:
    void* allocate(size_t size) {
        // 简单实现：使用全局 Arena + 锁
        std::lock_guard<std::mutex> lock(mutex_);
        return arena_.allocate(size);
    }
};

// 更好的方案：线程本地缓存
class ThreadLocalArenaWithCache {
    struct ThreadLocalCache {
        char buffer[4096];
        char* ptr;
        char* end;
    };

    thread_local ThreadLocalCache cache_;
    folly::SysArena sharedArena_;

    void* allocate(size_t size) {
        if (size <= (cache_.end - cache_.ptr)) {
            void* r = cache_.ptr;
            cache_.ptr += size;
            return r;
        }
        return allocateFromShared(size);
    }
};
```

## 性优启示 #7：批量分配的威力

Arena 展示了批量分配的优势：
1. **减少系统调用**：少量的大分配 vs 大量的小分配
2. **提高局部性**：相关对象存储在一起
3. **简化管理**：统一释放无需追踪

## 课后作业

1. 实现 `Arena` 的简化版本
2. 比较 Arena vs malloc 在密集分配场景下的性能
3. 设计一个支持线程本地缓存的 Arena

---

**第 7 天完。明天见！**
