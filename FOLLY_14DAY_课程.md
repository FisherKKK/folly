# Folly 深度学习课程：高性能 C++ 编程的 14 天之旅

## 课程简介

本课程将带你深入探索 Facebook 开源的高性能 C++ 库 **Folly** (Facebook Open-source Library) 的底层实现和性能优化技巧。通过 14 天的系统学习，你将掌握：

- Folly 的核心架构设计理念
- 高性能数据结构的实现原理
- 内存分配和缓存优化策略
- 并发编程和同步原语
- 异步 I/O 和协程框架
- 平台特定的优化技巧

**前置知识要求：**
- 熟悉 C++17/20 基础语法
- 了解数据结构与算法基础
- 有一定的多线程编程经验
- 了解基本的计算机体系结构（缓存、内存对齐等）

---

## 第 1 天：Folly 架构概览与构建系统

### 学习目标
- 理解 Folly 的设计哲学和架构原则
- 掌握 Folly 的构建系统
- 了解 Folly 与标准库和 Boost 的关系

### 核心内容

#### 1.1 Folly 的设计哲学

**Folly 不是要取代标准库，而是补充它。**

Folly 的三个核心原则：

1. **性能优先**：只在现有方案（std、Boost）无法满足性能需求时才创建新组件
2. **实用性导向**：解决 Facebook 内部实际遇到的性能瓶颈
3. **无内部依赖限制**：Folly 模块可以使用任何其他 Folly 组件

#### 1.2 平坦命名空间结构

Folly 采用独特的"平坦"目录结构：

```
folly/
├── container/          # 高性能容器
│   ├── F14Map.h
│   ├── small_vector.h
│   └── ...
├── synchronization/    # 同步原语
│   ├── Baton.h
│   ├── AtomicHashMap.h
│   └── ...
├── io/
│   └── async/         # 异步 I/O
│       ├── EventBase.h
│       └── AsyncSocket.h
├── coro/              # C++20 协程
├── memory/            # 内存管理
└── executors/         # 线程池
```

**关键点**：所有公共头文件都在 `folly/` 目录下，直接映射到 `folly::` 命名空间。

#### 1.3 构建系统深度解析

Folly 使用 CMake 构建系统，有 **108 个粒度化库**：

```cmake
# 示例：定义一个 Folly 库
folly_add_library(
  container
  HEADERS
    folly/container/F14Map.h
    folly/container/small_vector.h
  SRCS
    folly/container/F14Map.cpp
  EXPORTED_DEPS
    folly:memory
    folly:lang
  EXTERNAL_DEPS
    boost
)
```

**关键设计**：
- **OBJECT 库**：源文件只编译一次，复用于多个目标
- **粒度化链接**：可以只链接需要的组件
- **EXCLUDE_FROM_MONOLITH**：排除从主 libfolly.a（用于 benchmark）

#### 1.4 构建和测试

```bash
# 使用 getdeps.py 构建（推荐）
python3 ./build/fbcode_builder/getdeps.py --allow-system-packages build

# 直接使用 CMake
mkdir _build && cd _build
cmake .. -DBUILD_TESTS=ON
make -j$(nproc)

# 运行测试
ctest
```

### 性优启示 #1：构建系统优化
Folly 的构建系统本身就是一个性能优化的例子：
- **编译一次**：源文件编译为 OBJECT 库后复用
- **按需链接**：只链接实际使用的组件
- **并行构建**：充分利用多核

### 课后作业
1. 编译 Folly 并查看生成了多少个静态库文件
2. 查看 `folly/CMakeLists.txt`，找出最大的 5 个库
3. 理解为什么 Folly 选择不提供 ABI 兼容性保证

---

## 第 2 天：分支预测与编译器优化提示

### 学习目标
- 理解分支预测对性能的影响
- 掌握 Folly 的分支预测宏
- 学习编译器优化属性的使用

### 核心内容

#### 2.1 为什么分支预测很重要？

现代 CPU 使用**流水线**执行指令。分支预测失败会导致：
1. 流水线清空（10-20 个周期损失）
2. CPU 无法乱序执行
3. 性能严重下降

**示例**：搜索操作中的分支

```cpp
// 不好的代码
bool find(const std::vector<int>& data, int target) {
    for (int x : data) {
        if (x == target) {  // 分支预测困难
            return true;
        }
    }
    return false;
}
```

#### 2.2 FOLLY_LIKELY / FOLLY_UNLIKELY 宏

Folly 提供了分支预测提示（定义在 `folly/Likely.h`）：

```cpp
#define FOLLY_LIKELY(...) FOLLY_BUILTIN_EXPECT((__VA_ARGS__), 1)
#define FOLLY_UNLIKELY(...) FOLLY_BUILTIN_EXPECT((__VA_ARGS__), 0)
```

**使用场景**：

```cpp
#include <folly/Likely.h>

// 场景 1：错误处理是冷路径
void processData(Data* data) {
    if (FOLLY_UNLIKELY(data == nullptr)) {
        throw std::invalid_argument("null data");
    }
    // 热路径：编译器会优化这部分代码
    // ...
}

// 场景 2：常见情况优先
void handleRequest(Request* req) {
    if (FOLLY_LIKELY(req->isValid())) {
        // 快速路径
        processValidRequest(req);
    } else {
        // 慢速路径
        handleInvalidRequest(req);
    }
}
```

**汇编对比**：

```asm
; 不使用分支预测
test   rax, rax
je     .L_error_handler
; ...

; 使用 FOLLY_LIKELY
test   rax, rax
; 编译器会将 fast path 的代码线性排列
; 减少跳转指令
```

#### 2.3 强制内联与禁止内联

```cpp
// folly/Portability.h
#define FOLLY_ALWAYS_INLINE __attribute__((always_inline)) inline
#define FOLLY_NOINLINE __attribute__((noinline))
```

**使用场景**：

```cpp
// 小函数：强制内联消除函数调用开销
FOLLY_ALWAYS_INLINE int add(int a, int b) {
    return a + b;
}

// 大函数或调试用：禁止内联
FOLLY_NOINLINE void debugTrace() {
    // 这个函数不会被内联
}
```

#### 2.4 目标架构优化

```cpp
#define FOLLY_TARGET_ATTRIBUTE(target) __attribute__((__target__(target)))

// 只在支持 AVX2 的 CPU 上使用
FOLLY_TARGET_ATTRIBUTE("avx2")
void processVectorAVX2(float* data, size_t size) {
    // AVX2 指令
}
```

### 性优启示 #2：分支预测策略
1. **标记错误路径**：错误检查通常是不常见的
2. **标记热路径**：将最常见的执行路径线性化
3. **配置文件导向优化（PGO）**：使用真实数据收集分支统计

```bash
# GCC/Clang PGO 编译
gcc -fprofile-generate ./program
./program  # 运行典型 workload
gcc -fprofile-use -O3 ./program
```

### 课后作业
1. 编写一个微基准测试，比较使用 `FOLLY_LIKELY` 前后的性能差异
2. 阅读 `folly/Likely.h`，理解 `__builtin_expect` 的工作原理
3. 使用 `objdump -d` 查看编译器如何优化带有分支预测的代码

---

## 第 3 天：内存对齐与缓存友好设计

### 学习目标
- 理解内存对齐的重要性
- 掌握缓存行（Cache Line）概念
- 学习避免伪共享（False Sharing）的技巧

### 核心内容

#### 3.1 内存对齐基础

**为什么需要对齐？**
- 未对齐的访问可能需要多次内存访问
- 某些指令（如 SIMD）要求严格对齐
- 原子操作通常需要对齐

**Folly 的对齐工具**：

```cpp
#include <folly/lang/Align.h>

// 获取类型的对齐要求
constexpr size_t align = folly::align_of<int>::value;

// 对齐指针
void* aligned_ptr = folly::align_up(ptr, 64);

// 分配对齐内存
void* mem = folly::aligned_malloc(1024, 64);
folly::aligned_free(mem);
```

#### 3.2 缓存行优化

**关键概念**：
- **缓存行大小**：通常是 64 字节（x86-64）
- **伪共享**：多个线程修改同一缓存行的不同数据

```cpp
// 不好的设计：伪共享
struct BadCounter {
    std::atomic<int> thread1_count;  // 偏移 0
    std::atomic<int> thread2_count;  // 偏移 4 - 同一缓存行！
};

// 好的设计：避免伪共享
struct GoodCounter {
    alignas(64) std::atomic<int> thread1_count;
    char padding1[64 - sizeof(std::atomic<int>)];

    alignas(64) std::atomic<int> thread2_count;
    char padding2[64 - sizeof(std::atomic<int>)];
};
```

**Folly 的缓存行工具**：

```cpp
#include <folly/lang/Align.h>

// 获取缓存行大小
constexpr size_t kCacheLineSize = folly::kCachelineLineSize;  // 通常是 64

// 缓存行对齐的类
struct FOLLY_ALIGNAS(kCacheLineSize) AlignedStruct {
    int data[16];
};
```

#### 3.3 小缓冲区优化（Small Buffer Optimization, SBO）

Folly 的 `small_vector` 实现了 SBO：

```cpp
#include <folly/container/small_vector.h>

// small_vector 在栈上存储小数组，避免堆分配
folly::small_vector<int, 8> vec;  // 前 8 个元素在栈上

vec.push_back(1);   // 无堆分配
vec.push_back(2);   // 无堆分配
// ...
vec.push_back(9);   // 第 9 个元素时才分配堆内存
```

**SBO 的优势**：
1. **减少堆分配**：小数组零开销
2. **提高缓存局部性**：栈上数据访问更快
3. **减少内存碎片**：避免大量小分配

**实现原理**（简化）：

```cpp
template <typename T, size_t N>
class small_vector {
    union {
        struct {
            T* data_;
            size_t size_;
            size_t capacity_;
        } heap_;  // 堆模式

        struct {
            unsigned char buffer_[N * sizeof(T)];
            size_t size_;
        } stack_;  // 栈模式
    };

    bool is_heap_allocated() const {
        return size_ > N;
    }
};
```

#### 3.4 数据结构布局优化

**原则 1：将常用数据放在一起**

```cpp
// 不好的布局
struct BadLayout {
    bool flag1;     // 偏移 0
    char padding[7];
    int value;      // 偏移 8
    bool flag2;     // 偏移 12
    char padding2[7];
    long id;        // 偏移 16-24
};

// 好的布局
struct GoodLayout {
    long id;        // 8 字节，偏移 0
    int value;      // 4 字节，偏移 8
    bool flag1;     // 1 字节，偏移 12
    bool flag2;     // 1 字节，偏移 13
    // padding 6 字节
};
```

**原则 2：按访问模式排序**

```cpp
// 热数据（频繁访问）在前，冷数据（不常访问）在后
struct CacheFriendly {
    // 热数据
    int frequently_accessed;
    int also_often_used;

    // 冷数据
    int rarely_accessed;
    int debug_info;
};
```

### 性优启示 #3：缓存是关键
现代 CPU 的性能瓶颈通常是**内存访问**，而非计算：
1. **L1 缓存**：~4 周期访问
2. **L2 缓存**：~12 周期访问
3. **L3 缓存**：~40 周期访问
4. **主内存**：~200+ 周期访问

**策略**：
- 将相关数据紧凑排列
- 使用 SBO 避免间接访问
- 对齐到缓存行边界
- 避免伪共享

### 课后作业
1. 编写微基准测试，测量伪共享的性能影响
2. 实现 SBO 的简化版 `small_vector`
3. 使用 `perf` 工具分析程序的缓存命中率

---

## 第 4 天：F14 哈希表深度剖析（上）

### 学习目标
- 理解 F14 哈希表的设计理念
- 掌握 SIMD 向量过滤技术
- 学习双重哈希冲突解决策略

### 核心内容

#### 4.1 F14 命名由来

**F14 = Filtering 14 keys**

F14 使用 14-way 探测哈希表，通过 SIMD 指令可以同时过滤 14 个键。

**关键创新**：
- **块（Chunk）结构**：每个哈希表位置存储最多 14 个键
- **SIMD 过滤**：使用向量指令并行比较
- **高负载因子**：12/14 ≈ 85.7%（远高于传统哈希表的 50-75%）

#### 4.2 为什么 14？

这是数学和工程的平衡：

**生日悖论反应用**：

```
房间人数  生日相同概率（1/365）  同一周概率（1/52）
23        50%
8（传统单槽）

160       -                    8人同一周 50%
（F14的14-way chunk）
```

**实际效果**（在 12/14 负载因子下）：
- **查找命中**：期望探测长度 1.04
- **查找未命中**：期望探测长度 1.275，P99 = 4

#### 4.3 SIMD 向量过滤

**标签（Tag）系统**：

```cpp
// F14 为每个键计算 1 字节的标签
// 标签格式：7 位熵 + 1 个设置位（确保非零）

struct Chunk {
    alignas(16) uint8_t tags[16];  // 14 个标签 + 2 字节元数据
    Key keys[14];
    Value values[14];
};
```

**过滤过程**（x86-64 SSE2）：

```cpp
bool findInChunk(Chunk* chunk, uint8_t target_tag, const Key& key) {
    // 1. 加载 16 字节标签向量
    __m128i tag_vector = _mm_load_si128((__m128i*)chunk->tags);

    // 2. 并行比较目标标签与所有 14 个标签
    __m128i target_tag_vec = _mm_set1_epi8(target_tag);
    __m128i cmp_result = _mm_cmpeq_epi8(tag_vector, target_tag_vec);

    // 3. 生成掩码标识哪些槽可能匹配
    uint16_t mask = _mm_movemask_epi8(cmp_result);

    // 4. 过滤掉元数据字节和空槽
    mask &= 0x3FFF;  // 只保留低 14 位

    // 5. 对候选槽进行精确比较
    while (mask) {
        int slot = __builtin_ctz(mask);  // 找到第一个设置位
        if (chunk->keys[slot] == key) {
            return true;  // 找到匹配
        }
        mask &= (mask - 1);  // 清除最低位
    }

    return false;
}
```

**性能优势**：
- **并行比较**：一次 SIMD 指令比较 14 个标签
- **减少精确比较**：大多数查找只进行 1 次精确键比较
- **缓存友好**：标签向量总是对齐到 16 字节

#### 4.4 双重哈希探测

**探测序列**：

```cpp
template <typename Key>
class F14Table {
    size_t hash1(const Key& key) const {
        return std::hash<Key>{}(key);
    }

    size_t hash2(const Key& key) const {
        // 第二哈希函数：使用不同的哈希算法或常数
        return hash1(key) * 0x9e3779b97f4a7c15ULL >> shift;
    }

    size_t probe_sequence(size_t h1, size_t h2, size_t index) const {
        // 双重哈希：h1 + index * h2
        return (h1 + index * h2) & capacity_mask;
    }
};
```

**为什么不用线性探测？**

线性探测的问题：
- **聚类（Clustering）**：连续被占用的槽形成聚类
- **缓存竞争**：探测序列集中在缓存行

双重哈希：
- **分散探测**：探测序列更均匀
- **减少聚类**：即使高负载因子也能保持短探测链

#### 4.5 溢出计数（Overflow Counts）

**问题**：传统探测哈希表使用墓碑（Tombstone）处理删除

**墓碑的问题**：
- 需要定期清理
- 在插入-删除密集负载下性能下降

**F14 的解决方案：溢出计数**

```cpp
struct Chunk {
    uint8_t tags[16];  // 低 7 位：标签，高 1 位：溢出计数
    // ...
    uint8_t overflow_count;  // 此块溢出的键数量
};
```

**工作原理**：
1. **插入时**：如果块已满，增加溢出计数
2. **删除时**：递减溢出计数
3. **探测时**：如果溢出计数为 0，可以提前停止探测

**优势**：
- **自动清理**：无需显式清理墓碑
- **提前退出**：减少不必要的探测
- **引用计数墓碑**：精确跟踪有多少键被此块溢出

### 性优启示 #4：SIMD 的威力
F14 展示了如何有效利用 SIMD：
1. **数据并行**：设计能并行处理的数据结构
2. **紧凑存储**：充分利用 SIMD 寄存器宽度
3. **可移植性**：使用 SSE2（x86）和 NEON（ARM）

### 课后作业
1. 编写 F14 标签过滤的简化实现
2. 比较线性探测 vs 双重哈希在不同负载因子下的性能
3. 阅读 `folly/container/F14Map.h` 源码，理解不同的存储策略

---

## 第 5 天：F14 哈希表深度剖析（下）

### 学习目标
- 理解 F14 的四种存储策略
- 掌握异构查找技术
- 学习内存优化技巧

### 核心内容

#### 5.1 四种 F14 变体

F14 通过**策略模式**支持不同的存储方式：

##### F14NodeMap：间接存储

```cpp
template <typename Key, typename Value>
class F14NodeMap {
    // 类似 std::unordered_map：每个节点单独分配
    struct Node {
        Key key;
        Value value;
        Node* next;  // 链表（用于溢出）
    };

    std::vector<Node*> buckets;  // 指向节点
};
```

**特点**：
- ✅ **引用稳定性**：迭代器和引用永不失效
- ✅ **内存效率**（大对象）：不浪费空间
- ❌ **额外间接**：需要指针解引用
- **适用场景**：大键值对，需要引用稳定性

##### F14ValueMap：内联存储

```cpp
template <typename Key, typename Value>
class F14ValueMap {
    struct Chunk {
        Key keys[14];
        Value values[14];  // 值直接存储在块中
    };

    std::vector<Chunk> chunks;
};
```

**特点**：
- ✅ **零间接**：所有数据连续存储
- ✅ **缓存友好**：高空间局部性
- ❌ **移动元素**：重哈希时移动所有元素
- **适用场景**：小对象（< 24 字节）

##### F14VectorMap：向量存储

```cpp
template <typename Key, typename Value>
class F14VectorMap {
    struct Chunk {
        uint8_t tags[14];
        uint32_t indexes[14];  // 索引到值向量
    };

    std::vector<Chunk> chunks;
    std::vector<std::pair<Key, Value>> values;  // 连续值数组
};
```

**特点**：
- ✅ **紧凑存储**：哈希数组只存索引
- ✅ **迭代快速**：值向量连续存储
- ❌ **额外索引**：需要维护索引映射
- **适用场景**：大对象，需要快速迭代

##### F14FastMap：自动选择

```cpp
template <typename Key, typename Value, typename Hash, typename Equal, typename Alloc>
class F14FastMap :
    public std::conditional_t<
        (sizeof(Key) + sizeof(Value) < 24),
        F14ValueMap<Key, Value, Hash, Equal, Alloc>,
        F14VectorMap<Key, Value, Hash, Equal, Alloc>
    > {
    // 小对象用 ValueMap，大对象用 VectorMap
};
```

**选择策略**：
- `sizeof(Key) + sizeof(Value) < 24` → F14ValueMap
- 否则 → F14VectorMap

#### 5.2 异构查找（Heterogeneous Lookup）

**问题**：查找时需要构造临时对象

```cpp
std::unordered_map<std::string, int> map;
map.find("hello");  // 需要构造 std::string！
```

**F14 的解决方案**：

```cpp
#include <folly/container/F14Map.h>
#include <folly/functional/Invoke.h>

// 定义透明的哈希和相等函数
using StringHash = folly::transparent<folly::Hasher<folly::StringPiece>>;
using StringEqual = folly::transparent<std::equal_to<folly::StringPiece>>;

// 使用透明哈希
folly::F14FastMap<std::string, int, StringHash, StringEqual> map;

// 现在可以直接用 StringPiece 查找
folly::StringPiece key = "hello";
map.find(key);  // 无需构造 std::string
```

**如何工作**：

```cpp
// 透明哈希函数
template <typename Hasher>
struct transparent {
    // is_transparent 标记类型启用异构查找
    using is_transparent = void;

    template <typename T>
    auto operator()(const T& key) const {
        return Hasher{}(key);
    }
};
```

**性能提升**：
- **避免临时对象**：直接使用 `std::string_view` 或 `folly::StringPiece`
- **减少分配**：不需要构造临时 `std::string`
- **类型灵活**：支持多种兼容的键类型

#### 5.3 内存优化技巧

##### 小表优化

F14 为小表优化了内存使用：

```cpp
// 容量序列：2, 6, 14, ...
// 前 3 个容量都使用 1 个 chunk（16 字节元数据）

// 容量 2：只有 2 个槽可用
// 容量 6：6 个槽可用
// 容量 14：满 chunk
```

**好处**：小哈希表（最常见）的内存开销极小

##### 容量预留优化

```cpp
folly::F14FastMap<int, int> map;
map.reserve(1000);  // 精确分配 1000 的容量

// F14 会：
// 1. 尽量精确匹配请求的容量
// 2. 避免过度分配
// 3. 对齐到内部 chunk 结构
```

##### 清理策略

```cpp
map.clear();
// F14ValueMap/VectorMap：
// - 如果容量 > 100，释放所有内存
// - 避免留下大表导致迭代缓慢

// F14NodeMap：
// - 只释放节点，保留桶数组
```

#### 5.4 调试模式下的随机化

F14 在 Debug/ASAN 模式下引入随机性：

```cpp
#ifdef FOLLY_SANITIZE_ADDRESS
// ASAN 模式：随机触发额外的重哈希
// 暴露潜在的引用稳定性问题
#endif

#ifdef NDEBUG
// Release 模式：确定性行为
#else
// Debug 模式：随机化插入顺序
// 暴露对迭代顺序的错误假设
#endif
```

**好处**：在测试阶段发现生产中可能出现的 bug

### 性优启示 #5：灵活的策略设计
F14 的设计展示了如何平衡不同需求：
1. **性能 vs 稳定性**：ValueMap（快）vs NodeMap（稳定）
2. **内存 vs 速度**：VectorMap（省内存）vs ValueMap（快）
3. **自动化选择**：FastMap 根据类型大小自动选择

### 课后作业
1. 比较四种 F14 变体在不同键值对大小下的性能
2. 实现异构查找的简化版本
3. 测试 F14 与 `std::unordered_map` 在不同负载因子下的性能

---

## 第 6 天：Small Vector 与 SBO 深度剖析

### 学习目标
- 理解小缓冲区优化（SBO）的设计原理
- 掌握 `small_vector` 的实现细节
- 学习平台特定的优化技巧

### 核心内容

#### 6.1 SBO 的动机

**问题**：标准 `std::vector` 的问题

```cpp
std::vector<int> vec;
vec.push_back(1);   // 堆分配！
vec.push_back(2);   // 即使只有 2 个元素
```

**代价**：
- 小数组也需要堆分配（malloc 开销）
- 缓存不友好（堆上的数据分散）
- 内存碎片（大量小分配）

#### 6.2 small_vector 的设计

**核心思想**：利用对象的栈空间存储元素

```cpp
template <typename T, size_t N = 1>
class small_vector {
    union Storage {
        struct Heap {
            T* data_;
            size_t size_;
            size_t capacity_;
        } heap_;

        struct Stack {
            unsigned char buffer_[N * sizeof(T)];
            size_t size_;
        } stack_;
    } storage_;

    bool is_heap() const {
        return size() > N;
    }
};
```

**内存布局**：

```
small_vector<int, 4> 的内存布局：
+------------------+----------------------+
| Stack Mode       | Heap Mode            |
+------------------+----------------------+
| buffer_[16 bytes]| data_* (8 bytes)     | 0-7
| size_ (4 bytes)  | size_ (4 bytes)      | 8-11
| capacity_ (4)    | capacity_ (4)        | 12-15
+------------------+----------------------+
```

#### 6.3 平台特定的优化

Folly 使用平台特定的打包优化：

```cpp
// folly/container/small_vector.h
#if (FOLLY_X64 || FOLLY_PPC64 || FOLLY_AARCH64 || FOLLY_RISCV64)
#define FOLLY_SV_PACK_ATTR FOLLY_PACK_ATTR  // 紧凑打包
#define FOLLY_SV_PACK_PUSH FOLLY_PACK_PUSH
#define FOLLY_SV_PACK_POP FOLLY_PACK_POP
#else
#define FOLLY_SV_PACK_ATTR  // 无打包
#define FOLLY_SV_PACK_PUSH
#define FOLLY_SV_PACK_POP
#endif

template <typename T, std::size_t N, class P>
class FOLLY_SV_PACK_ATTR small_vector {
    // ...
};
```

**效果**：
- **64 位平台**：紧凑打包，最小化填充
- **32 位平台**：正常对齐，避免未对齐访问问题

#### 6.4 生长策略

**小 → 大转换**：

```cpp
void push_back(const T& value) {
    if (size() < capacity()) {
        // 仍在栈模式或堆有空间
        construct_at_end(value);
    } else {
        // 需要增长
        // 如果当前在栈模式，转移到堆
        // 如果在堆模式，重新分配
        value_type* new_data = allocate_and_copy(new_capacity);
        destroy_and_dealloc();
        data_ = new_data;
        capacity_ = new_capacity;
        construct_at_end(value);
    }
    ++size_;
}
```

**增长因子**：

```cpp
// Folly 使用 1.5x 增长（类似 std::vector）
size_t new_capacity = std::max(size_t(2), capacity() + capacity() / 2);
```

#### 6.5 移动语义优化

**关键优化**：移动而非复制

```cpp
// 从栈转移到堆
void relocate_to_heap() {
    T* heap_data = allocate_heap(N * 2);  // 分配更大的堆内存

    // 使用移动构造函数
    for (size_t i = 0; i < size_; ++i) {
        new (&heap_data[i]) T(std::move(stack_buffer()[i]));
        stack_buffer()[i].~T();  // 析构栈上的对象
    }

    data_ = heap_data;
    capacity_ = N * 2;
}
```

**优势**：
- **O(1) 移动**：移动构造通常是指针/基本类型的复制
- **避免深层复制**：对于复杂类型很重要

#### 6.6 迭代器失效规则

**small_vector 的迭代器失效**：

```cpp
folly::small_vector<int, 4> vec;

// 场景 1：栈模式，有空间
vec.push_back(1);
vec.push_back(2);
auto it = vec.begin();
vec.push_back(3);  // 迭代器仍然有效（仍在栈上）

// 场景 2：栈 → 堆转换
vec.push_back(4);
vec.push_back(5);  // 触发栈 → 堆！it 失效！

// 场景 3：堆模式，重新分配
vec.reserve(100);  // it 失效！
```

**规则**：
- **栈模式 + 不溢出**：迭代器稳定
- **栈 → 堆转换**：所有迭代器失效
- **堆模式 + 重新分配**：所有迭代器失效
- **与 std::vector 相同**：一旦在堆上，行为相同

#### 6.7 SBO 的其他应用

**fbstring（Folly 的 string）**：

```cpp
#include <folly/FBString.h>

folly::fbstring str = "hello";  // SBO：存储在栈上
// 小字符串（< 23 字节）无堆分配

str = "a very long string that exceeds the small buffer optimization...";
// 触发堆分配
```

**FBString 的 SBO 布局**：

```cpp
class fbstring {
    union {
        struct {
            char* data_;
            size_t size_;
            size_t capacity_;
        } heap_;

        struct {
            char buffer_[23];
            unsigned char size_;  // 最高位标记模式
        } stack_;
    };
};
```

### 性优启示 #6：零开销抽象
SBO 展示了如何实现零开销抽象：
1. **快速路径优化**：小对象零开销
2. **透明转换**：自动在栈/堆之间切换
3. **类型安全**：不牺牲 C++ 的类型系统

### 课后作业
1. 实现 `small_vector` 的简化版本（支持 push_back 和 operator[]）
2. 比较不同内联大小（N=1, 4, 8, 16）的性能
3. 测试 SBO vs 堆分配的性能差异（使用微基准测试）

---

## 第 7 天：Arena 内存分配器

### 学习目标
- 理解 Arena 分配器的设计理念
- 掌握批量分配技术
- 学习内存池和重用策略

### 核心内容

#### 7.1 Arena 的动机

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

#### 7.2 Arena 的设计

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

#### 7.3 Arena 的实现

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

#### 7.4 块大小选择策略

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

#### 7.5 大对象优化

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

#### 7.6 Arena 的重用

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

#### 7.7 线程本地 Arena

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

### 性优启示 #7：批量分配的威力
Arena 展示了批量分配的优势：
1. **减少系统调用**：少量的大分配 vs 大量的小分配
2. **提高局部性**：相关对象存储在一起
3. **简化管理**：统一释放无需追踪

### 课后作业
1. 实现 `Arena` 的简化版本
2. 比较 Arena vs malloc 在密集分配场景下的性能
3. 设计一个支持线程本地缓存的 Arena

---

## 第 8 天：同步原语 - Baton

### 学习目标
- 理解轻量级同步原语的设计
- 掌握 Baton 的实现原理
- 学习 futex 和无锁技术

### 核心内容

#### 8.1 为什么需要 Baton？

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

#### 8.2 Baton 的设计

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

#### 8.3 Baton 的实现

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

#### 8.4 Futex（Fast Userspace muTex）

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

#### 8.5 非阻塞版本

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

#### 8.6 Baton 的使用模式

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

#### 8.7 避免伪共享

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

### 性优启示 #8：极简设计
Baton 展示了如何设计高效的同步原语：
1. **最小化状态**：4 字节的状态机
2. **快速路径优化**：无系统调用的常见情况
3. **平台特定**：使用 futex 等 OS 原语

### 课后作业
1. 实现 `Baton` 的简化版本
2. 比较 `Baton` vs `std::condition_variable` 的性能
3. 设计一个支持超时的 `Baton`

---

## 第 9 天：原子哈希表（AtomicHashMap）

### 学习目标
- 理解无锁数据结构的设计挑战
- 掌握 AtomicHashMap 的实现策略
- 学习等待查找（Wait-Free）技术

### 核心内容

#### 9.1 为什么需要 AtomicHashMap？

**问题**：`std::unordered_map` 不是线程安全的

```cpp
std::unordered_map<int, int> map;

// 线程 1
map[1] = 100;

// 线程 2
map[2] = 200;  // 数据竞争！未定义行为
```

**解决方案**：
- **外部加锁**：`std::mutex` + `std::unordered_map`
- **并发哈希表**：`tbb::concurrent_hash_map`
- **AtomicHashMap**：Folly 的实现

#### 9.2 AtomicHashMap 的设计

**核心思想**：固定大小 + 原子操作

```cpp
#include <folly/synchronization/AtomicHashMap.h>

folly::AtomicHashMap<int, std::string> map(1024);  // 固定容量

// 线程安全的操作
map.insert(1, "hello");
map.insert(2, "world");

auto* result = map.find(1);
if (result) {
    std::cout << *result << std::endl;
}
```

**特点**：
- **查找无锁**：find() 是 wait-free
- **固定大小**：不支持动态增长
- **int32/int64 键**：优化的小整数键
- **高性能**：比 `tbb::concurrent_hash_map` 快 2-4 倍

#### 9.3 内部结构

**AHArray：核心数组**

```cpp
template <typename Key, typename Value>
class AtomicHashMap {
    struct Entry {
        std::atomic<Key> key_;
        Value value_;

        // 空键标记（用于已删除的槽）
        static constexpr Key kEmptyKey = Key(-1);
    };

    std::unique_ptr<Entry[]> entries_;
    size_t capacity_;
    size_t num_slots_;  // 实际使用的槽位数量
};
```

**查找算法**：

```cpp
Value* find(Key key) {
    size_t index = hash(key) & (capacity_ - 1);

    // 线性探测
    while (true) {
        Entry& entry = entries_[index];
        Key found_key = entry.key_.load(std::memory_order_relaxed);

        if (found_key == key) {
            // 找到匹配
            return &entry.value_;
        } else if (found_key == Entry::kEmptyKey) {
            // 空槽，键不存在
            return nullptr;
        }

        // 继续探测
        index = (index + 1) & (capacity_ - 1);
    }
}
```

**为什么 wait-free？**
- **无阻塞**：使用 `memory_order_relaxed` 读取键
- **无循环依赖**：不等待其他线程
- **固定步数**：最多探测 `capacity_` 次

#### 9.4 插入算法

**插入策略**：先探测，后 CAS

```cpp
bool insert(Key key, const Value& value) {
    size_t start_index = hash(key) & (capacity_ - 1);
    size_t index = start_index;

    // 第一轮：查找键或空槽
    size_t first_empty = -1;
    while (true) {
        Entry& entry = entries_[index];
        Key found_key = entry.key_.load(std::memory_order_relaxed);

        if (found_key == key) {
            // 键已存在（根据策略可能更新或返回）
            return false;
        } else if (found_key == Entry::kEmptyKey) {
            first_empty = index;
            break;  // 找到空槽
        }

        index = (index + 1) & (capacity_ - 1);
        if (index == start_index) {
            return false;  // 表已满
        }
    }

    // 第二轮：尝试插入
    index = first_index;
    while (true) {
        Entry& entry = entries_[index];
        Key expected = Entry::kEmptyKey;

        // CAS：尝试占据空槽
        if (entry.key_.compare_exchange_strong(
                expected, key,
                std::memory_order_release,
                std::memory_order_relaxed)) {
            // 成功占据
            entry.value_ = value;
            return true;
        }

        // CAS 失败：检查是否是我们要找的键
        if (expected == key) {
            return false;  // 其他线程已经插入
        }

        // 继续尝试下一个槽
        index = (index + 1) & (capacity_ - 1);
    }
}
```

#### 9.5 键锁定策略

**问题**：插入时的并发修改

**解决方案**：锁定键的范围

```cpp
struct Entry {
    std::atomic<Key> key_;
    std::atomic<uint8_t> lock_;  // 锁标志

    void lock() {
        uint8_t expected = 0;
        while (!lock_.compare_exchange_strong(
            expected, 1,
            std::memory_order_acquire)) {
            expected = 0;
            // 自旋等待
        }
    }

    void unlock() {
        lock_.store(0, std::memory_order_release);
    }
};
```

**插入带锁**：

```cpp
bool insert(Key key, const Value& value) {
    // ... 找到槽位

    entry.lock();
    SCOPE_EXIT { entry.unlock(); };

    // 再次检查（可能已改变）
    if (entry.key_.load(std::memory_order_relaxed) != Entry::kEmptyKey) {
        return false;
    }

    entry.key_.store(key, std::memory_order_release);
    entry.value_ = value;
    return true;
}
```

#### 9.6 增长策略：AHMap

**问题**：AtomicHashMap 大小固定

**解决方案**：多层 AHMap

```cpp
template <typename Key, typename Value>
class AHMap {
    std::vector<std::unique_ptr<AtomicHashMap<Key, Value>>> levels_;

public:
    AHMap(size_t initial_capacity) {
        levels_.push_back(
            std::make_unique<AtomicHashMap<Key, Value>>(initial_capacity)
        );
    }

    Value* find(Key key) {
        // 在所有层中查找
        for (auto& level : levels_) {
            if (Value* result = level->find(key)) {
                return result;
            }
        }
        return nullptr;
    }

    void insert(Key key, const Value& value) {
        // 尝试在顶层插入
        if (!levels_.back()->insert(key, value)) {
            // 顶层满了，增长
            grow();
            levels_.back()->insert(key, value);
        }
    }

private:
    void grow() {
        size_t new_capacity = levels_.back()->capacity() * 2;
        levels_.push_back(
            std::make_unique<AtomicHashMap<Key, Value>>(new_capacity)
        );
    }
};
```

#### 9.7 性能优化技巧

**优化 1：SIMD 扫描**

```cpp
// 批量检查多个槽的键
__m256i keys = _mm256_loadu_si256((__m256i*)&entries_[index]);
__m256i target = _mm256_set1_epi32(key);
__m256i cmp = _mm256_cmpeq_epi32(keys, target);
uint32_t mask = _mm256_movemask_epi8(cmp);

if (mask) {
    // 找到可能的匹配
}
```

**优化 2：缓存行对齐**

```cpp
struct FOLLY_ALIGNAS(64) Entry {
    std::atomic<Key> key_;
    Value value_;
};
```

**优化 3：预取**

```cpp
Value* find(Key key) {
    size_t index = hash(key) & (capacity_ - 1);

    // 预取下一个可能的槽
    __builtin_prefetch(&entries_[(index + 1) & (capacity_ - 1)]);

    // ... 查找逻辑
}
```

### 性优启示 #9：无锁设计的权衡
AtomicHashMap 展示了无锁设计的挑战：
1. **固定大小**：为了无锁而牺牲动态性
2. **类型限制**：int32/int64 键的优化
3. **CAS 失败重试**：高竞争下性能下降

### 课后作业
1. 实现 `AtomicHashMap` 的简化版本（支持 insert 和 find）
2. 比较不同并发级别下的性能
3. 设计一个支持动态增长的方案

---

## 第 10 天：Hazard Pointers（危险指针）

### 学习目标
- 理解无锁数据结构的内存回收问题
- 掌握 Hazard Pointer 的实现原理
- 学习 ABA 问题的解决方案

### 核心内容

#### 10.1 无锁内存回收的挑战

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

#### 10.2 Hazard Pointer 的设计

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

#### 10.3 Hazard Pointer 的实现

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

#### 10.4 批量回收

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

#### 10.5 ABA 问题

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

#### 10.6 性能优化

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

### 性优启示 #10：安全与性能的平衡
Hazard Pointers 展示了无锁编程的复杂性：
1. **延迟回收**：平衡安全性和及时性
2. **批量操作**：减少检查开销
3. **线程本地**：减少全局竞争

### 课后作业
1. 实现 Hazard Pointer 的简化版本
2. 比较不同回收策略的性能
3. 分析 ABA 问题的各种解决方案

---

## 第 11 天：EventBase 与异步 I/O

### 学习目标
- 理解事件驱动的编程模型
- 掌握 EventBase 的实现原理
- 学习异步 I/O 的性能优化

### 核心内容

#### 11.1 为什么需要异步 I/O？

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

#### 11.2 EventBase 的设计

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

#### 11.3 EventBase 的实现

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

#### 11.4 定时器实现

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

#### 11.5 跨线程调度

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

#### 11.6 性能优化

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

### 性优启示 #11：事件驱动设计
EventBase 展示了事件驱动编程的优势：
1. **单线程多任务**：减少线程开销
2. **非阻塞 I/O**：避免线程阻塞
3. **回调机制**：灵活的事件处理

### 课后作业
1. 实现简化的事件循环
2. 比较同步 vs 异步 I/O 的性能
3. 实现分层时间轮定时器

---

## 第 12 天：C++20 协程与 Task

### 学习目标
- 理解协程的基本概念
- 掌握 folly::coro::Task 的实现
- 学习协程的性能优化

### 核心内容

#### 12.1 为什么需要协程？

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

#### 12.2 C++20 协程基础

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

#### 12.3 folly::coro::Task

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

#### 12.4 co_await 机制

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

#### 12.5 协程与 Executor

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

#### 12.6 协程取消

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

#### 12.7 协程性能优化

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

### 性优启示 #12：协程的威力
协程提供了异步编程的优雅解决方案：
1. **线性代码**：避免回调地狱
2. **零开销抽象**：编译器优化
3. **灵活调度**：与 Executor 集成

### 课后作业
1. 实现简单的 Task 类型
2. 实现定时器 awaitable
3. 比较协程 vs 回调的性能

---

## 第 13 天：性能测量与优化技巧

### 学习目标
- 掌握微基准测试的编写方法
- 学习性能分析工具的使用
- 理解常见的性能陷阱

### 核心内容

#### 13.1 微基准测试

**使用 folly/Benchmark.h**：

```cpp
#include <folly/Benchmark.h>
#include <folly/init/Init.h>

BENCHMARK(vector_push_back) {
    std::vector<int> vec;
    vec.reserve(100);
    BENCHMARK_SUSPEND {
        vec.clear();
    }
    for (int i = 0; i < 100; ++i) {
        vec.push_back(i);
    }
}

// 带参数的基准测试
BENCHMARK_DRAW_LINE()

BENCHMARK_PARAM(map_insert, 10)
BENCHMARK_PARAM(map_insert, 100)
BENCHMARK_PARAM(map_insert, 1000)

template <size_t N>
void map_insert(size_t iters, size_t size) {
    folly::F14FastMap<int, int> map;

    for (size_t i = 0; i < iters; ++i) {
        map.clear();
        for (size_t j = 0; j < size; ++j) {
            map.insert({j, j});
        }
    }
}

int main(int argc, char** argv) {
    folly::init(&argc, &argv);
    folly::runBenchmarks();
    return 0;
}
```

**运行基准测试**：

```bash
./benchmark
# 输出：
# vector_push_back  1000 times in 1234 ns (1.2 ns / iter)
# map_insert(10)    1000 times in 5678 ns (5.7 ns / iter)
# map_insert(100)   1000 times in 12345 ns (12.3 ns / iter)
```

#### 13.2 Google Benchmark

**更强大的基准测试框架**：

```cpp
#include <benchmark/benchmark.h>

static void BM_VectorPushBack(benchmark::State& state) {
    for (auto _ : state) {
        std::vector<int> vec;
        for (int i = 0; i < state.range(0); ++i) {
            vec.push_back(i);
        }
        benchmark::DoNotOptimize(vec.data());
        benchmark::ClobberMemory();
    }
}
BENCHMARK(BM_VectorPushBack)->Range(1, 1000);

static void BM_HashMapLookup(benchmark::State& state) {
    folly::F14FastMap<int, int> map;
    for (int i = 0; i < 1000; ++i) {
        map[i] = i;
    }

    for (auto _ : state) {
        benchmark::DoNotOptimize(map.find(500));
    }
}
BENCHMARK(BM_HashMapLookup);

BENCHMARK_MAIN();
```

#### 13.3 性能分析工具

**perf：Linux 性能分析**

```bash
# 记录性能数据
perf record ./program

# 报告
perf report

# 热点函数
perf report --sort=overhead --stdio

# 火焰图
perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
```

**valgrind/cachegrind：缓存分析**

```bash
# 缓存命中率
valgrind --tool=cachegrind ./program

# 分析结果
cg_annotate cachegrind.out.<pid>
```

**callgrind：调用图分析**

```bash
valgrind --tool=callgrind ./program
kcachegrind callgrind.out.<pid>
```

#### 13.4 常见性能陷阱

**陷阱 1：过早优化**

```cpp
// 不好的优化
int add(int a, int b) {
    // 为了"性能"使用位运算
    return (a & b) + ((a ^ b) >> 1);
}

// 好的代码
int add(int a, int b) {
    return a + b;  // 编译器会优化的
}
```

**原则**：先测量，后优化

**陷阱 2：微优化浪费时间**

```cpp
// 不值得的优化
for (int i = 0; i < n; ++i) {
    // 预先计算的"优化"
    int x = (i << 3) + (i << 1);  // i * 10
}
```

**原则**：关注算法复杂度，而非微小的常数因子

**陷阱 3：忽略内存分配**

```cpp
// 不好的代码：循环内分配
void process(const std::vector<int>& data) {
    for (int value : data) {
        std::string temp = std::to_string(value);
        // 使用 temp
    }
}

// 好的代码：复用缓冲区
void process(const std::vector<int>& data) {
    std::string temp;
    for (int value : data) {
        temp = std::to_string(value);
        // 使用 temp
    }
}
```

**陷阱 4：不必要的拷贝**

```cpp
// 不好的代码
std::string process(std::string data) {  // 按值传递
    return data + " processed";
}

// 好的代码
std::string process(const std::string& data) {  // 按引用传递
    return data + " processed";
}

// 或使用移动
std::string process(std::string&& data) {
    return std::move(data) + " processed";
}
```

#### 13.5 优化清单

**编译器优化**：
- ✅ 使用 `-O2` 或 `-O3`
- ✅ 启用 LTO（链接时优化）：`-flto`
- ✅ 使用 PGO（配置文件导向优化）

**算法优化**：
- ✅ 选择正确的数据结构（F14 vs std::unordered_map）
- ✅ 避免不必要的查找（使用哈希表而非线性搜索）
- ✅ 预分配容器大小

**内存优化**：
- ✅ 使用 Arena 批量分配
- ✅ 使用 small_vector 避免小数组堆分配
- ✅ 避免内存碎片

**并发优化**：
- ✅ 使用无锁结构（AtomicHashMap）
- ✅ 避免伪共享
- ✅ 减少锁竞争

**I/O 优化**：
- ✅ 使用异步 I/O（EventBase）
- ✅ 批量处理操作
- ✅ 使用零拷贝技术

#### 13.6 性优化的科学方法

**1. 测量**

```cpp
auto start = std::chrono::high_resolution_clock::now();
// ... 代码 ...
auto end = std::chrono::high_resolution_clock::now();
auto duration = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start);
```

**2. 分析**

```bash
# 使用 perf 找到热点
perf record ./program
perf report
```

**3. 优化**

```cpp
// 根据分析结果优化热点代码
```

**4. 验证**

```bash
# 重新运行基准测试
./benchmark
```

**5. 迭代**

```cpp
// 继续优化下一个瓶颈
```

### 性优启示 #13：测量驱动的优化
性能优化是科学过程：
1. **测量先行**：不要猜测
2. **关注热点**：优化关键路径
3. **验证效果**：确保优化有效

### 课后作业
1. 为之前实现的组件编写微基准测试
2. 使用 perf 分析你的代码
3. 找出并优化一个性能瓶颈

---

## 第 14 天：综合项目与最佳实践

### 学习目标
- 将所学知识整合到一个实际项目中
- 理解 Folly 在生产环境中的使用
- 掌握高性能 C++ 编程的最佳实践

### 核心内容

#### 14.1 综合项目：高性能日志系统

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

#### 14.2 性能优化技术总结

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

#### 14.3 Folly 最佳实践

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

#### 14.4 生产环境考虑

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

#### 14.5 学习路径建议

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

#### 14.6 进一步学习资源

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

### 性优启示 #14：性能工程是实践学科
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

祝你学习愉快！高性能 C++ 编程的世界充满挑战和乐趣。继续探索，不断优化！
