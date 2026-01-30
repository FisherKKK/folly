# Folly 快速参考指南

## 常用组件速查表

### 容器（Container）

| 组件 | 头文件 | 用途 | 性能 |
|------|--------|------|------|
| `F14FastMap` | `folly/container/F14Map.h` | 通用哈希表 | ⭐⭐⭐⭐⭐ |
| `F14NodeMap` | `folly/container/F14Map.h` | 引用稳定哈希表 | ⭐⭐⭐⭐ |
| `small_vector` | `folly/container/small_vector.h` | 小数组优化 | ⭐⭐⭐⭐⭐ |
| `F14FastSet` | `folly/container/F14Set.h` | 哈希集合 | ⭐⭐⭐⭐⭐ |

### 内存管理（Memory）

| 组件 | 头文件 | 用途 | 性能 |
|------|--------|------|------|
| `SysArena` | `folly/memory/Arena.h` | 批量分配 | ⭐⭐⭐⭐⭐ |
| `ThreadLocalPtr` | `folly/memory/ThreadLocalPtr.h` | 线程本地存储 | ⭐⭐⭐⭐ |
| `Synchronized` | `folly/Synchronized.h` | 线程安全对象 | ⭐⭐⭐⭐ |

### 同步（Synchronization）

| 组件 | 头文件 | 用途 | 性能 |
|------|--------|------|------|
| `Baton<>` | `folly/synchronization/Baton.h` | 一次性同步 | ⭐⭐⭐⭐⭐ |
| `AtomicHashMap` | `folly/synchronization/AtomicHashMap.h` | 并发哈希表 | ⭐⭐⭐⭐ |
| `Hazptr` | `folly/synchronization/Hazptr.h` | 无锁回收 | ⭐⭐⭐⭐⭐ |

### 异步（Async）

| 组件 | 头文件 | 用途 | 性能 |
|------|--------|------|------|
| `EventBase` | `folly/io/async/EventBase.h` | 事件循环 | ⭐⭐⭐⭐⭐ |
| `AsyncSocket` | `folly/io/async/AsyncSocket.h` | 异步Socket | ⭐⭐⭐⭐⭐ |
| `Task` | `folly/coro/Task.h` | 协程任务 | ⭐⭐⭐⭐⭐ |

### 并发（Concurrency）

| 组件 | 头文件 | 用途 | 性能 |
|------|--------|------|------|
| `CPUThreadPoolExecutor` | `folly/executors/CPUThreadPoolExecutor.h` | CPU线程池 | ⭐⭐⭐⭐ |
| `IOThreadPoolExecutor` | `folly/executors/IOThreadPoolExecutor.h` | I/O线程池 | ⭐⭐⭐⭐ |
| `Future` | `folly/futures/Future.h` | Future/Promise | ⭐⭐⭐⭐ |

---

## 代码片段速查

### F14Map 使用

```cpp
#include <folly/container/F14Map.h>

// 创建
folly::F14FastMap<std::string, int> map;

// 插入
map["hello"] = 42;
map.insert({"world", 43});

// 查找
auto it = map.find("hello");
if (it != map.end()) {
    std::cout << it->second << std::endl;
}

// 异构查找
folly::StringPiece key = "hello";
map.find(key);  // 无需构造 std::string
```

### small_vector 使用

```cpp
#include <folly/container/small_vector.h>

// 创建（前 8 个元素在栈上）
folly::small_vector<int, 8> vec;

// 使用（像 std::vector）
vec.push_back(1);
vec.push_back(2);
vec.emplace_back(3);

// 迭代
for (int x : vec) {
    std::cout << x << std::endl;
}
```

### Arena 使用

```cpp
#include <folly/memory/Arena.h>

// 创建 Arena
folly::SysArena arena;

// 分配
void* ptr1 = arena.allocate(64);
void* ptr2 = arena.allocate(128);

// 使用
// ... 使用 ptr1, ptr2 ...

// 无需单独释放
// Arena 析构时统一释放所有内存
```

### Baton 使用

```cpp
#include <folly/synchronization/Baton.h>

// 创建
folly::Baton<> baton;

// 线程 1：等待
baton.wait();  // 阻塞直到 post()

// 线程 2：唤醒
baton.post();  // 唤醒等待的线程
```

### EventBase 使用

```cpp
#include <folly/io/async/EventBase.h>

// 创建事件循环
folly::EventBase evb;

// 注册定时器
evb.runAfterDelay([] {
    std::cout << "Timer fired!" << std::endl;
}, 1000);  // 1000ms

// 注册回调
evb.runInEventBaseThread([] {
    std::cout << "In EventBase thread" << std::endl;
});

// 启动事件循环
evb.loopForever();
```

### 协程使用

```cpp
#include <folly/coro/Task.h>

// 定义协程
folly::coro::Task<int> compute() {
    co_await folly::coro::sleep(std::chrono::milliseconds(100));
    co_return 42;
}

// 使用协程
folly::coro::Task<void> run() {
    int result = co_await compute();
    std::cout << "Result: " << result << std::endl;
}

// 启动协程
folly::CPUThreadPoolExecutor executor(4);
auto future = run().scheduleOn(&executor).start();
std::move(future).get();
```

---

## 编译选项速查

### 基础优化

```bash
# O2 优化
-O2

# O3 优化（更激进）
-O3

# 启用 CPU 特定优化
-march=native

# 链接时优化
-flto

# 小代码大小
-Os
```

### PGO（配置文件导向优化）

```bash
# 第一步：生成配置文件
g++ -O3 -fprofile-generate ./program -o program_gen
./program_gen  # 运行典型 workload

# 第二步：使用配置文件优化
g++ -O3 -fprofile-use -o program_opt ./program_gen
./program_opt  # 最终版本
```

### Folly 特定宏

```cpp
// 分支预测
if (FOLLY_UNLIKELY(error)) {
    // 错误处理
}

// 强制内联
FOLLY_ALWAYS_INLINE int fast() {
    return x * 2;
}

// 禁止内联
FOLLY_NOINLINE void debug() {
    // 调试代码
}
```

---

## 性能分析命令

### perf

```bash
# CPU 性能分析
perf record ./program
perf report

# 火焰图
perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg

# 特定事件
perf stat -e branches,branch-misses,L1-dcache-load-misses ./program
```

### valgrind

```bash
# 内存泄漏检测
valgrind --tool=memcheck --leak-check=full ./program

# 缓存分析
valgrind --tool=cachegrind ./program
cg_annotate cachegrind.out.<pid>

# 调用图分析
valgrind --tool=callgrind ./program
kcachegrind callgrind.out.<pid>
```

### 自定义宏

```cpp
// 使用 folly/Benchmark.h 的实时版本
#include <folly/stats/Benchmark.h>

void criticalSection() {
    SCOPED_TIMER_SECTION(section_timer, "critical_section");

    // 关键代码
}  // 自动记录时间
```

---

## 常见问题速查

### 编译错误

**问题**：找不到 Folly 头文件
```bash
# 解决：设置 CMAKE_PREFIX_PATH
cmake .. -DCMAKE_PREFIX_PATH=/path/to/folly/install
```

**问题**：链接错误
```bash
# 解决：链接 folly 库
target_link_libraries(your_target PRIVATE folly)
```

### 性能问题

**问题**：程序比预期慢
```bash
# 1. 使用 perf 找到热点
perf record ./program

# 2. 检查是否启用了优化
cmake .. -DCMAKE_BUILD_TYPE=Release

# 3. 检查编译器版本
g++ --version
```

**问题**：内存占用高
```bash
# 1. 使用 valgrind 检查
valgrind --tool=massif ./program

# 2. 检查是否使用了 Arena
# 3. 检查是否有内存泄漏
valgrind --tool=memcheck ./program
```

---

## 调试技巧

### 日志宏

```cpp
#include <folly/logging.h>

// 不同级别
FB_LOG(INFO) << "Info message";
FB_LOG(WARNING) << "Warning message";
FB_LOG(ERROR) << "Error message";

// 带格式化
FB_LOG(INFO) << "Value: " << value;
```

### 断言

```cpp
#include <folly/Conv.h>

// 运行时断言
DCHECK_GT(value, 0) << "Value must be positive";

// 编译时断言
static_assert(sizeof(int) == 4, "int must be 4 bytes");
```

### 异常处理

```cpp
#include <folly/Exception.h>
#include <folly/Expected.h>

// 使用 Expected
folly::Expected<int, std::string> divide(int a, int b) {
    if (b == 0) {
        return folly::makeUnexpected<std::string>("Division by zero");
    }
    return a / b;
}

// 使用
auto result = divide(10, 2);
if (result.hasValue()) {
    std::cout << "Result: " << result.value() << std::endl;
} else {
    std::cout << "Error: " << result.error() << std::endl;
}
```

---

## 构建命令速查

### getdeps.py

```bash
# 构建默认配置
python3 ./build/fbcode_builder/getdeps.py build folly

# 允许使用系统包
python3 ./build/fbcode_builder/getdeps.py build folly --allow-system-packages

# 只下载源码
python3 ./build/fbcode_builder/getdeps.py download folly

# 查看构建目录
python3 ./build/fbcode_builder/getdeps.py show-build-dir

# 运行测试
python3 ./build/fbcode_builder/getdeps.py test folly
```

### CMake

```bash
# 配置
cmake .. -DBUILD_TESTS=ON -DBUILD_BENCHMARKS=ON

# 构建（Ninja）
ninja -j$(nproc)

# 构建（Make）
make -j$(nproc)

# 运行测试
ctest -j$(nproc)

# 运行特定测试
./folly/test/container_test/F14MapTest
```

---

## 平台特定说明

### Linux

```bash
# 安装依赖
sudo apt install libboost-all-dev libevent-dev libgflags-dev libgoogle-glog-dev

# 构建
mkdir _build && cd _build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### macOS

```bash
# 安装依赖
brew install boost libevent gflags glog

# 构建
mkdir _build && cd _build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.ncpu)
```

### Windows

```bash
# 使用 vcpkg 安装依赖
vcpkg install boost-libevent gflags glog

# 构建
mkdir _build && cd _build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

---

## 性能数据参考

### F14Map vs unordered_map

| 操作 | F14Map | unordered_map | 提升 |
|------|--------|---------------|------|
| 插入（10K） | 65 μs | 125 μs | 1.9x |
| 查找（命中） | 18 ns | 45 ns | 2.5x |
| 查找（未命中） | 22 ns | 35 ns | 1.6x |
| 内存（10K） | 120 KB | 200 KB | 1.7x |

### small_vector vs vector

| 场景 | small_vector | vector | 提升 |
|------|-------------|--------|------|
| 10 元素 | 12 ns | 85 ns | 7.1x |
| 100 元素 | 180 ns | 200 ns | 1.1x |
| 1000 元素 | 1.5 μs | 1.6 μs | 1.1x |

### Arena vs malloc

| 场景 | Arena | malloc | 提升 |
|------|-------|--------|------|
| 1K 次分配 | 180 ns | 850 ns | 4.7x |
| 10K 次分配 | 1.2 μs | 8.5 μs | 7.1x |
| 100K 次分配 | 9.5 μs | 85 μs | 8.9x |

---

## 资源链接

### 官方文档
- [Folly GitHub](https://github.com/facebook/folly)
- [Folly 文档](https://facebook.github.io/folly/)

### 社区
- [Stack Overflow](https://stackoverflow.com/questions/tagged/folly)
- [Reddit r/cpp](https://reddit.com/r/cpp)

### 工具
- [Compiler Explorer](https://godbolt.org/)
- [C++ Reference](https://en.cppreference.com/)
- [CppCon Videos](https://www.youtube.com/user/CppCon)

---

## 版本兼容性

### C++ 标准

| Folly 版本 | 最低 C++ 标准 | 推荐 C++ 标准 |
|-----------|--------------|--------------|
| 2024.x | C++17 | C++20 |
| 2023.x | C++17 | C++20 |
| 2022.x | C++14 | C++17 |

### 编译器

| 编译器 | 最低版本 | 推荐版本 |
|-------|---------|---------|
| GCC | 9.0 | 11.0+ |
| Clang | 10.0 | 13.0+ |
| MSVC | 19.28 | 19.35+ |

---

**更新日期**：2024-01-30

**版本**：v1.0
