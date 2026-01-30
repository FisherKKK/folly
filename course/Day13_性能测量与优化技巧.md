# Folly 深度学习课程 - 第 13 天

# 第 13 天：性能测量与优化技巧

## 学习目标
- 掌握微基准测试的编写方法
- 学习性能分析工具的使用
- 理解常见的性能陷阱

## 核心内容

### 13.1 微基准测试

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

### 13.2 Google Benchmark

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

### 13.3 性能分析工具

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

### 13.4 常见性能陷阱

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

### 13.5 优化清单

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

### 13.6 性优化的科学方法

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

## 性优启示 #13：测量驱动的优化

性能优化是科学过程：
1. **测量先行**：不要猜测
2. **关注热点**：优化关键路径
3. **验证效果**：确保优化有效

## 课后作业

1. 为之前实现的组件编写微基准测试
2. 使用 perf 分析你的代码
3. 找出并优化一个性能瓶颈

---

**第 13 天完。明天最后一天！**
