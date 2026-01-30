# Folly 深度学习课程 - 第 13 天（增强版）

# 第 13 天：性能测量与优化技巧 - 实战 profiling

## 学习目标
- 掌握 folly/Benchmark.h 的实际使用方法
- 学习性能分析工具（perf, cachegrind, flamegraph）的使用
- 理解性能测量的统计学方法
- 实战优化案例：从分析到改进

## 核心内容

### 13.1 微基准测试框架

#### folly/Benchmark.h 架构

**folly/Benchmark.h:44-48**

```cpp
FOLLY_GFLAGS_DECLARE_bool(benchmark);          // 是否运行 benchmark
FOLLY_GFLAGS_DECLARE_uint32(bm_result_width_chars);  // 输出宽度
FOLLY_GFLAGS_DECLARE_int32(bm_min_iters);     // 最小迭代次数
FOLLY_GFLAGS_DECLARE_int64(bm_max_iters);     // 最大迭代次数
```

#### 基本使用方法

**示例 1：简单 benchmark**

```cpp
#include <folly/Benchmark.h>
#include <folly/FBVector.h>

BENCHMARK(Vector_push_back, iters) {
    folly::fbvector<int> vec;
    for (size_t i = 0; i < iters; ++i) {
        vec.push_back(i);
    }
}

BENCHMARK_DRAW_LINE()  // 输出分隔线

// main 函数
int main(int argc, char** argv) {
    gflags::ParseCommandLineFlags(&argc, &argv, true);
    folly::runBenchmarks();
    return 0;
}
```

**编译和运行**：

```bash
# 编译
g++ -std=c++20 -O3 -march=native \
    -I/path/to/folly \
    benchmark.cpp -lfolly -lgflags -lglog -lpthread \
    -o benchmark

# 运行
./benchmark --benchmark

# 输出示例：
# ============================================================================
# Vector_push_back                                 5.00 ns        200 M/s
# ============================================================================
```

#### 高级功能：自定义计数器

**folly/Benchmark.h:67-95**

```cpp
class UserMetric {
 public:
  enum class Type { CUSTOM, TIME, METRIC };
  std::variant<int64_t, double> value;
  Type type{Type::CUSTOM};
};

using UserCounters = std::unordered_map<std::string, UserMetric>;
```

**使用示例**：

```cpp
BENCHMARK(HashMap_with_counters, iters) {
    folly::F14FastMap<int, int> map;

    // 自定义计数器
    UserCounters counters;
    counters["allocations"] = UserMetric(0);
    counters["collisions"] = UserMetric(0);

    for (size_t i = 0; i < iters; ++i) {
        map[i] = i * 2;
    }

    // 返回计数器
    return {
        std::chrono::high_resolution_clock::now() - start,
        static_cast<unsigned int>(iters),
        counters
    };
}
```

### 13.2 BenchmarkSuspender：排除无关代码

#### 使用场景

**folly/Benchmark.h:127-200**

```cpp
template <typename Clock>
struct BenchmarkSuspender : BenchmarkSuspenderBase {
    BenchmarkSuspender();  // 暂停计时
    ~BenchmarkSuspender();  // 恢复计时

    void dismiss();  // 手动恢复
    void rehire();   // 重新暂停

    template <class F>
    auto dismissing(F f) -> invoke_result_t<F> {
        SCOPE_EXIT { rehire(); };
        dismiss();
        return f();  // f() 的执行时间不计入 benchmark
    }
};
```

**实际应用**：

```cpp
BENCHMARK(With_setup_cost, iters) {
    folly::BenchmarkSuspender<> suspender;

    // 暂停计时：昂贵的初始化
    std::vector<int> data = generateLargeDataset();

    suspender.dismiss();  // 恢复计时

    // 这段代码被计时
    for (size_t i = 0; i < iters; ++i) {
        process(data);
    }
}

// 或者使用 lambda
BENCHMARK(With_suspender_lambda, iters) {
    folly::BenchmarkSuspender<>.dismissing([&] {
        // 这个 lambda 里的代码不计入时间
        initializeGlobalData();
    });

    // 测量实际操作
    for (size_t i = 0; i < iters; ++i) {
        doWork();
    }
}
```

### 13.3 性能分析工具链

#### 工具 1：perf（Linux 性能计数器）

**安装**：

```bash
# Ubuntu/Debian
sudo apt-get install linux-tools-common linux-tools-generic

# 验证
perf --version
```

**常用命令**：

```bash
# 1. 记录性能事件
perf record -F 99 -g -- ./your_program

# 参数说明：
# -F 99     : 采样频率 99 Hz（每秒 99 次）
# -g        : 记录调用栈
# --        : 后面是程序参数

# 2. 查看报告（交互式）
perf report

# 3. 查看特定函数
perf report --stdio --sort=overhead --symbol-filter=your_function

# 4. 统计事件
perf stat -e cycles,instructions,cache-misses,branch-misses ./your_program

# 输出示例：
#  1,234,567,890      cycles
#    987,654,321      instructions     #    0.80  insn per cycle
#     12,345,678      cache-misses     #    1.25 % of all cache ops
#      5,678,901      branch-misses    #    2.34 % of all branches
```

**实战案例：查找热点函数**：

```bash
# 1. 运行 benchmark 并记录
perf record -F 99 -g ./benchmark --benchmark

# 2. 查看报告
perf report --stdio | head -50

# 输出示例：
# # Overhead  Command  Shared Object      Symbol
# # ........  .......  .................  ............................
# #
#     25.30%  benchmark  benchmark         [.] std::vector<int>::push_back
#     18.45%  benchmark  benchmark         [.] folly::F14Table::find
#     12.23%  benchmark  benchmark         [.] std::hash<int>::operator()
#      8.90%  benchmark  libc-2.31.so      [.] memcpy
#      ...

# 结论：push_back 和 F14Table::find 是热点
```

#### 工具 2：perf annotate（汇编级分析）

```bash
# 注释汇编代码
perf annotate -M intel --stdio your_function

# 输出示例：
# Percent |      Source code & Disassembly of libtest.so
#         :
#         :      void hotFunction() {
#    5.00 :    mov    eax, DWORD PTR [rdi]
#    3.50 :    test   eax, eax
#         :    je     .L2
#   15.20 :    mov    ecx, OFFSET_FLAT needles  ← 热点指令
#    8.90 :    mov    edx, 1000
#    2.30 :    call   binary_search
#         :    ...

# 分析：
# - 15.20% 的时间花在加载 needles 指针
# - 可能是缓存未命中导致
```

#### 工具 3：cachegrind（缓存分析）

**安装**：

```bash
sudo apt-get install valgrind kcachegrind
```

**使用**：

```bash
# 1. 运行 cachegrind
valgrind --tool=cachegrind ./benchmark --benchmark

# 输出文件：cachegrind.out.<pid>

# 2. 使用 cg_annotate 查看详细报告
cg_annotate cachegrind.out.<pid> | head -100

# 输出示例：
# Ir        I1mr  ILmr        Dr      D1mr    DLmr        Dw      D1mr    DLmr
# ...............................................................................
# program_total:
# 12,345,678 123,456 12,345 5,678,901 234,567 23,456 3,456,789 123,456 12,345
#
# file:function
# ...............................................................................
# benchmark.cpp:hotFunction
# 1,234,567  23,456  2,345   567,890  12,345   1,234   234,567  5,678    567

# 3. 使用 GUI 工具 kcachegrind
kcachegrind cachegrind.out.<pid>
```

**解读结果**：

```
Ir     : 指令读取次数
I1mr   : L1 指令缓存未命中
ILmr   : 最后一级指令缓存未命中
Dr     : 数据读取次数
D1mr   : L1 数据缓存未命中
DLmr   : 最后一级数据缓存未命中
Dw     : 数据写入次数
D1mr/DLmr (write) : 写入缓存未命中

关键指标：
- D1mr / Dr = L1 数据缓存未命中率
- DLmr / Dr = LLC 数据缓存未命中率
- 目标：< 5% 未命中率
```

#### 工具 4：Flame Graph（火焰图）

**生成火焰图**：

```bash
# 1. 安装 FlameGraph
git clone https://github.com/brendangregg/FlameGraph
cd FlameGraph

# 2. 采集性能数据
perf record -F 99 -a -g -- sleep 30  # 运行 30 秒

# 3. 生成火焰图
perf script | ./stackcollapse-perf.pl | ./flamegraph.pl > flamegraph.svg

# 4. 查看火焰图
firefox flamegraph.svg
```

**解读火焰图**：

```
     ▼ CPU 火焰图
     ^
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
     |
    (pdf) svg [☖]  ▄

横轴：样本数量（不是时间！）
纵轴：调用栈深度
颜色：随机（暖色调表示热点）
宽度：函数占用的 CPU 时间比例

优化目标：
- 找到宽的平顶函数（热点）
- 避免宽的柱子（可优化）
- 关注用户空间函数（非内核）
```

### 13.4 实战优化案例

#### 案例 1：优化 F14 查找

**初始代码**：

```cpp
// naive_f14_lookup.cpp
BENCHMARK(Naive_lookup, iters) {
    folly::F14FastMap<int, std::string> map;

    // 填充数据
    for (int i = 0; i < 10000; ++i) {
        map[i] = "value_" + std::to_string(i);
    }

    // 查找
    uint64_t sum = 0;
    for (size_t i = 0; i < iters; ++i) {
        auto it = map.find(i % 10000);
        if (it != map.end()) {
            sum += it->second.size();
        }
    }

    folly::doNotOptimize(sum);
}
```

**性能分析**：

```bash
# 1. 运行 perf
perf record -F 99 -g ./naive_f14_lookup --benchmark

# 2. 查看热点
perf report --stdio | grep -A 5 "Naive_lookup"

# 输出：
# 30.50%  naive_f14_lookup  naive_f14_lookup  [.] std::string::operator[]
# 25.30%  naive_f14_lookup  naive_f14_lookup  [.] folly::F14Table::find
# 15.20%  naive_f14_lookup  libc-2.31.so      [.] __memcpy_avx_unaligned
# 12.10%  naive_f14_lookup  naive_f14_lookup  [.] std::string::~string
```

**问题分析**：

1. **字符串拷贝**：`operator[]` 可能触发字符串操作
2. **缓存未命中**：`__memcpy_avx_unaligned` 占 15%
3. **析构开销**：每次迭代都创建临时 string

**优化方案 1：使用引用**：

```cpp
BENCHMARK(Optimized_lookup_v1, iters) {
    folly::F14FastMap<int, std::string> map;

    for (int i = 0; i < 10000; ++i) {
        map[i] = "value_" + std::to_string(i);
    }

    uint64_t sum = 0;
    for (size_t i = 0; i < iters; ++i) {
        auto it = map.find(i % 10000);
        if (it != map.end()) {
            const std::string& str = it->second;  // ✅ 引用，避免拷贝
            sum += str.size();
        }
    }

    folly::doNotOptimize(sum);
}
```

**性能提升**：

```
实现                  时间 (ns/op)  相对速度    主要改进
Naive_lookup         120           1.00x (基线)
Optimized_v1         85            1.41x       避免字符串拷贝
Optimized_v2         72            1.67x       预分配容量
Optimized_v3         58            2.07x       使用 F14NodeMap
```

**优化方案 2：使用异构查找**：

```cpp
// 使用 StringPiece 避免临时 string
using TransparentMap = folly::F14FastMap<
    std::string,
    int,
    folly::transparent<folly::Hasher<folly::StringPiece>>
>;

TransparentMap map;

// 查找时无需构造临时 string
folly::StringPiece key = "hello";  // ✅ 零拷贝
auto it = map.find(key);
```

#### 案例 2：优化 vector 预分配

**问题代码**：

```cpp
BENCHMARK(Vector_no_reserve, iters) {
    std::vector<int> vec;

    // ❌ 没有 reserve，多次重新分配
    for (size_t i = 0; i < iters; ++i) {
        vec.push_back(i);
    }
}
```

**性能分析**：

```bash
# cachegrind 分析
valgrind --tool=cachegrind ./vector_benchmark

# 输出：
# Dr      D1mr    DLmr
# 8.5 MB  45,678  12,345   ← 大量缓存未命中
```

**优化方案**：

```cpp
BENCHMARK(Vector_with_reserve, iters) {
    std::vector<int> vec;
    vec.reserve(iters);  // ✅ 预分配

    for (size_t i = 0; i < iters; ++i) {
        vec.push_back(i);
    }
}
```

**性能对比**（1M 元素）：

```
实现                  时间 (ms)    内存分配次数
no_reserve            45          20 次
with_reserve          12          1 次
提升：                3.75x       20x
```

#### 案例 3：减少分支预测失败

**问题代码**：

```cpp
bool process(int value) {
    // ❌ 随机分支，难以预测
    if (value % 2 == 0) {
        return processEven(value);
    } else {
        return processOdd(value);
    }
}

BENCHMARK(Branch_unpredicted, iters) {
    int sum = 0;
    for (size_t i = 0; i < iters; ++i) {
        if (process(i)) {
            sum++;
        }
    }
}
```

**性能分析**：

```bash
perf stat -e branches,branch-misses ./branch_benchmark

# 输出：
# 50,000,000      branches
# 25,000,000      branch-misses  # 50% 未命中率！
```

**优化方案 1：分支提示**：

```cpp
bool process_optimized(int value) {
    // 假设偶数更常见（根据实际数据）
    if (FOLLY_LIKELY(value % 2 == 0)) {
        return processEven(value);
    } else {
        return processOdd(value);
    }
}
```

**优化方案 2：消除分支**：

```cpp
// 使用查表法或位运算
bool process_branchless(int value) {
    // ✅ 无分支版本
    return (value & 1) ? processOdd(value) : processEven(value);
}

// 或者使用函数指针表
bool (*processors[2])(int) = {processEven, processOdd};
bool process_dispatch(int value) {
    return processors[value & 1](value);  // 无分支
}
```

**性能提升**：

```
实现                  分支未命中率    时间 (ns/op)
unpredicted          50%            45
likely hint          50%            38  (15% 提升)
branchless           0%             25  (44% 提升)
```

### 13.5 常见性能陷阱

#### 陷阱 1：过早优化

```cpp
// ❌ 不必要的优化
int sum = 0;
for (int i = 0; i < n; ++i) {
    // 编译器已经会自动优化这个循环
    sum += data[i];
}

// ✅ 让编译器做它的工作
int sum = std::accumulate(data, data + n, 0);
```

**原则**：
1. 先测量，后优化
2. 优化真正的热点
3. 相信现代编译器

#### 陷阱 2：微优化忽略算法复杂度

```cpp
// ❌ O(n²) 算法，即使优化了常量
for (int i = 0; i < n; ++i) {
    for (int j = i + 1; j < n; ++j) {
        if (data[i] == data[j]) { /* ... */ }
    }
}

// ✅ O(n log n) 或 O(n) 算法
std::unordered_map<int, int> counts;
for (int i = 0; i < n; ++i) {
    counts[data[i]]++;
}
```

**性能对比**（n = 100000）：

```
算法           复杂度      实际时间
嵌套循环        O(n²)      12.5 秒
哈希表         O(n)       0.008 秒
提升：                    1562x
```

#### 陷阱 3：忽视内存布局

```cpp
// ❌ 缓存不友好的布局
struct BadLayout {
    std::string name;
    bool flag1;
    bool flag2;
    bool flag3;
    // ... 3 字节填充 ...
    int value;
};
// sizeof(BadLayout) = 8 + 1 + 1 + 1 + 3(padding) + 4 = 18 → 24 (对齐)

// ✅ 缓存友好的布局
struct GoodLayout {
    int value;          // 4 字节
    bool flag1;         // 1 字节
    bool flag2;         // 1 字节
    bool flag3;         // 1 字节
    // ... 1 字节填充 ...
    std::string name;   // 8 字节
};
// sizeof(GoodLayout) = 4 + 1 + 1 + 1 + 1(padding) + 8 = 16
```

### 13.6 性能优化的科学方法

#### ODO（Optimization-Driven Optimization）流程

```
1. Observe（观察）
   - 运行 benchmark
   - 使用 perf/cachegrind
   - 找到热点

2. Diagnose（诊断）
   - 分析热点原因
   - 理解性能瓶颈
   - 提出假设

3. Optimize（优化）
   - 实施改进
   - 保持正确性
   - 记录性能

4. 验证
   - 重新测量
   - 确认提升
   - 或回到步骤 1
```

#### 实战示例

**问题**：日志系统太慢（100K logs/s → 需要 10M logs/s）

**第 1 轮**：
- Observe：perf 显示 `snprintf` 占 60% 时间
- Diagnose：格式化字符串很慢
- Optimize：使用预格式化的模板
- Result：200K logs/s（2x 提升）

**第 2 轮**：
- Observe：`malloc` 占 40% 时间
- Diagnose：每个日志条目都分配内存
- Optimize：使用 Arena 批量分配
- Result：2M logs/s（10x 提升）

**第 3 轮**：
- Observe：mutex 锁竞争占 30% 时间
- Diagnose：多个线程争用全局锁
- Optimize：使用线程本地 buffer
- Result：10M logs/s（5x 提升，总计 100x）

### 13.7 性优启示 #13（增强版）：测量的艺术

性能优化的核心原则：

1. **测量优先**：不要猜测，用数据说话
2. **工具链**：perf → cachegrind → flamegraph
3. **热点驱动**：专注优化真正的瓶颈
4. **小步迭代**：每次改进一个瓶颈
5. **验证提升**：每次优化后重新测量
6. **理解代价**：优化的代码通常更复杂

## 课后作业（增强版）

1. **基准测试实践**：
   ```cpp
   // 选择一个你常用的数据结构
   // 编写 benchmark 测试不同场景
   // - 随机访问 vs 顺序访问
   // - 小数据 vs 大数据
   // - 单线程 vs 多线程
   ```

2. **性能分析**：
   ```bash
   # 使用 perf 分析你的 benchmark
   # 生成火焰图
   # 找到 3 个优化点
   # 实施改进并测量提升
   ```

3. **优化案例**：
   - 找到一个实际项目的性能问题
   - 使用工具分析原因
   - 实施优化
   - 记录提升（前后对比）

4. **深入研究**：
   - 阅读 perf 的官方文档
   - 学习 CPU 性能计数器
   - 研究 JIT/AOT 编译器的优化
   - 设计自己的性能测试框架

## 延伸阅读

- **文档**：`folly/Benchmark.h` - 完整 API 文档
- **工具**：
  - `perf` wiki：https://perf.wiki.kernel.org/
  - FlameGraph：https://github.com/brendangregg/FlameGraph
  - valgrind：https://valgrind.org/docs/manual/
- **书籍**：
  - "The Art of Computer Systems Performance Analysis" (Jain)
  - "Computer Architecture: A Quantitative Approach" (Hennessy & Patterson)
- **论文**：
  - "The Computer Architecture of a Benchmark" (码农)

---

**第 13 天完（增强版）。明天是最后一天！**
