# Folly 常见问题 (FAQ)

## 概述

本文档收集了 Folly 使用中最常见的问题和解决方案。

---

## 📦 安装和构建

### Q1: Folly 支持哪些平台？

**A**: Folly 支持：
- **Linux**: x86-64, ARM64 (主要支持平台)
- **macOS**: x86-64, ARM64 (Apple Silicon)
- **Windows**: 实验性支持，功能有限

**推荐**: Linux (Ubuntu 20.04+, CentOS 8+)

### Q2: 最低编译器要求是什么？

**A**:
- **GCC**: >= 9.0 (推荐 11.0+)
- **Clang**: >= 10.0 (推荐 13.0+)
- **MSVC**: >= 19.28 (Visual Studio 2019)

**C++ 标准**: C++17 (推荐 C++20)

### Q3: 如何解决依赖问题？

**A**: 使用 getdeps.py 自动管理依赖：

```bash
# 安装所有依赖
python3 ./build/fbcode_builder/getdeps.py install-system-deps --recursive

# 构建时会自动下载依赖
python3 ./build/fbcode_builder/getdeps.py build folly
```

**主要依赖**:
- Boost
- libevent
- gflags
- glog
- OpenSSL
- double-conversion

### Q4: 构建时间太长怎么办？

**A**:
1. **使用 ccache**
   ```bash
   sudo apt install ccache
   export CC="gcc"
   export CXX="g++"
   ```

2. **使用 Ninja**
   ```bash
   cmake -GNinja ..
   ninja -j$(nproc)
   ```

3. **只构建需要的组件**
   ```bash
   cmake -DFOLLY_BUILD_SHARED_LIBS=OFF ..
   ```

4. **使用更少的并行任务**
   ```bash
   make -j4  # 而不是 make -j$(nproc)
   ```

### Q5: 如何检查 Folly 是否正确安装？

**A**:
```bash
# 检查头文件
ls /usr/local/include/folly/

# 检查库文件
ls /usr/local/lib/libfolly.*

# 测试程序
echo '#include <folly/F14Map.h>
int main() { folly::F14FastMap<int, int> m; return 0; }' > test.cpp
g++ -std=c++17 test.cpp -lfolly -o test && ./test
```

---

## 🚀 使用问题

### Q6: F14Map 和 std::unordered_map 如何选择？

**A**: 选择指南：

| 场景 | 推荐 | 原因 |
|------|------|------|
| 通用高性能 | F14FastMap | 快 2-3x，省 40% 内存 |
| 需要引用稳定 | F14NodeMap | 迭代器不失效 |
| 小对象（< 24B）| F14ValueMap | 无堆分配 |
| 大对象 | F14VectorMap | 内存紧凑 |
| ABI 稳定性 | std::unordered_map | 标准库保证 |

### Q7: small_vector 的内联大小如何设置？

**A**:
```cpp
// 1. 分析常见大小
// 统计数据：90% 的情况 < 8 个元素
folly::small_vector<int, 8> vec;  // 好

// 2. 考虑对象大小
// 对象太大不宜内联
folly::small_vector<BigData, 2> vec;  // 最多 2 个

// 3. 测试性能
// 对比不同大小
folly::small_vector<int, 4> vec4;
folly::small_vector<int, 8> vec8;
folly::small_vector<int, 16> vec16;
```

**建议**: 根据实际使用情况设置，默认 8 是好的起点。

### Q8: Arena 分配的内存何时释放？

**A**: Arena 析构时：
```cpp
{
    folly::SysArena arena;
    void* ptr1 = arena.allocate(100);
    void* ptr2 = arena.allocate(200);
    // 使用 ptr1, ptr2
}  // ← Arena 析构，一次性释放所有内存
```

**重要**:
- 无法单独释放某个分配
- 所有内存同时释放
- 适合相同生命周期的对象

### Q9: Baton 可以重复使用吗？

**A**: 可以，但需要重置：
```cpp
folly::Baton<> baton;

// 第一次使用
std::thread t1([&]() { baton.wait(); });
baton.post();
t1.join();

// 重置
baton.reset();

// 第二次使用
std::thread t2([&]() { baton.wait(); });
baton.post();
t2.join();
```

**注意**: 如果忘记 reset，第二次 wait 会立即返回。

### Q10: EventBase 可以跨线程使用吗？

**A**: 不建议直接跨线程调用：

```cpp
// ❌ 差：多线程直接调用
folly::EventBase evb;
std::thread t1([&]() { evb.loop(); });
std::thread t2([&]() { evb.runInEventBaseThread(...); });  // 危险

// ✅ 好：使用 runInEventBaseThread
folly::EventBase evb;
std::thread t1([&]() { evb.loop(); });
evb.runInEventBaseThread([]() {
    // 这在 EventBase 线程中执行
});
```

**原则**: 每个 EventBase 在自己的线程中运行。

---

## ⚡ 性能问题

### Q11: 为什么我的 F14Map 比标准库慢？

**A**: 检查清单：

1. **编译优化**
   ```bash
   # 必须启用优化
   g++ -O3 -march=native ...
   ```

2. **数据规模**
   - F14 在大集合时优势明显
   - 小集合可能差异不大

3. **键类型**
   ```cpp
   // 好：简单键（快速哈希）
   folly::F14FastMap<int, int> map;

   // 差：复杂键（慢哈希）
   folly::F14FastMap<ComplexKey, int> map;
   ```

4. **基准测试方法**
   ```cpp
   // 正确：预热
   for (int i = 0; i < 1000; ++i) {
       map.insert(std::make_pair(i, i));
   }
   // 然后测量
   ```

### Q12: 如何测量 Arena 的性能优势？

**A**:
```cpp
#include <folly/Benchmark.h>
#include <folly/memory/Arena.h>

BENCHMARK(ArenaAllocation, iters) {
    folly::SysArena arena;
    for (size_t i = 0; i < iters; ++i) {
        arena.allocate(64);
    }
}

BENCHMARK(MallocAllocation, iters) {
    for (size_t i = 0; i < iters; ++i) {
        malloc(64);
        free(malloc(64));
    }
}

// 运行: ./benchmark
// 预期：Arena 快 10-50x
```

### Q13: 为什么协程没有性能提升？

**A**: 常见原因：

1. **没有并发**
   ```cpp
   // 差：串行执行
   auto r1 = co_await task1();
   auto r2 = co_await task2();

   // 好：并发执行
   auto [r1, r2] = co_await folly::coro::collectAll(task1(), task2());
   ```

2. **Executor 太小**
   ```cpp
   // 差：只有一个线程
   folly::CPUThreadPoolExecutor executor(1);

   // 好：多个线程
   folly::CPUThreadPoolExecutor executor(std::thread::hardware_concurrency());
   ```

3. **测量了错误的东西**
   - 测量延迟，而不是吞吐
   - 没有预热
   - 测试数据太小

---

## 🐛 调试问题

### Q14: 如何调试 Folly 程序？

**A**: 使用调试工具：

1. **AddressSanitizer** (内存错误)
   ```bash
   g++ -fsanitize=address -g -O1 program.cpp -lfolly
   ./program
   ```

2. **ThreadSanitizer** (数据竞争)
   ```bash
   g++ -fsanitize=thread -g -O1 program.cpp -lfolly
   ./program
   ```

3. **Valgrind** (内存泄漏)
   ```bash
   valgrind --tool=memcheck --leak-check=full ./program
   ```

4. **GDB** (调试器)
   ```bash
   gdb ./program
   (gdb) break main
   (gdb) run
   (gdb) backtrace
   ```

### Q15: 如何定位性能瓶颈？

**A**: 使用性能分析工具：

1. **perf** (CPU 性能)
   ```bash
   perf record ./program
   perf report
   ```

2. **perf top** (实时查看)
   ```bash
   sudo perf top
   ```

3. **火焰图** (可视化)
   ```bash
   perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
   ```

4. **valgrind/cachegrind** (缓存分析)
   ```bash
   valgrind --tool=cachegrind ./program
   cg_annotate cachegrind.out.<pid>
   ```

---

## 🔧 配置问题

### Q16: 如何在 CMake 中使用 Folly？

**A**:
```cmake
# 方式 1: find_package
find_package(folly REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE folly)
```

```cmake
# 方式 2: 手动指定
set(FOLLY_ROOT /path/to/folly)

add_executable(myapp main.cpp)
target_include_directories(myapp PRIVATE ${FOLLY_ROOT}/include)
target_link_libraries(myapp PRIVATE ${FOLLY_ROOT}/lib/libfolly.a)
```

### Q17: 如何在 Bazel 中使用 Folly？

**A**:
```python
# WORKSPACE
http_archive(
    name = "folly",
    urls = ["https://github.com/facebook/folly/archive/v2024.01.01.00.tar.gz"],
    strip_prefix = "folly-2024.01.01.00",
)

# BUILD
cc_library(
    name = "folly",
    visibility = ["//visibility:public"],
)
```

### Q18: 如何设置自定义编译选项？

**A**:
```cmake
# 启用特定组件
set(FOLLY_USE_JEMALLOC ON)

# 禁用某些组件
set(FOLLY_BUILD_SHARED_LIBS OFF)

# 自定义定义
add_definitions(-DFOLLY_USE_TLS=1)
```

---

## 💼 实战问题

### Q19: 如何在生产环境使用 Folly？

**A**: 最佳实践：

1. **静态链接**
   ```cmake
   # 推荐：静态链接
   target_link_libraries(myapp PRIVATE folly)

   # 不推荐：动态链接（ABI 不稳定）
   # target_link_libraries(myapp PRIVATE SHARED folly)
   ```

2. **版本固定**
   ```bash
   # 使用特定版本
   git checkout v2024.01.01.00
   ```

3. **充分测试**
   ```bash
   # 运行所有测试
   python3 ./build/fbcode_builder/getdeps.py test folly
   ```

4. **监控和日志**
   ```cpp
   // 添加日志
   FB_LOG(INFO) << "Using F14Map with " << map.size() << " entries";
   ```

### Q20: 如何处理 Folly 的异常？

**A**:
```cpp
#include <folly/Exception.h>
#include <folly/Expected.h>

// 方式 1: try-catch
try {
    follySomething();
} catch (const std::exception& e) {
    LOG(ERROR) << "Folly exception: " << e.what();
}

// 方式 2: Expected（推荐）
folly::Expected<int, std::string> mightFail() {
    if (error) {
        return folly::makeUnexpected<std::string>("Error message");
    }
    return 42;
}

auto result = mightFail();
if (result.hasValue()) {
    std::cout << result.value() << std::endl;
} else {
    std::cout << "Error: " << result.error() << std::endl;
}
```

### Q21: 如何迁移现有代码到 Folly？

**A**: 渐进式迁移策略：

1. **第一阶段：非关键路径**
   ```cpp
   // 从不重要的代码开始
   folly::F14FastMap<std::string, int> cache;  // 新代码
   std::unordered_map<std::string, int> old_map;  // 旧代码
   ```

2. **第二阶段：性能热点**
   ```cpp
   // 使用 perf 找到热点
   // 迁移这些部分
   folly::small_vector<int, 8> vec;  // 替换 std::vector
   ```

3. **第三阶段：全面迁移**
   ```cpp
   // 统一使用 Folly 组件
   ```

**注意**:
- 充分测试
- 性能对比
- 逐步替换

---

## 📚 学习问题

### Q22: 新手应该从哪里开始？

**A**: 推荐顺序：

1. **5分钟快速入门** ⭐
   ```bash
   cat QUICKSTART.md
   ```

2. **核心组件**
   - Day 1: 架构和构建
   - Day 4-5: F14 哈希表
   - Day 6: small_vector
   - Day 7: Arena

3. **实战练习**
   ```bash
   # 运行代码示例
   cat CODE_EXAMPLES.md

   # 完成习题
   cat EXERCISES.md
   ```

### Q23: 如何深入理解 Folly 实现？

**A**: 学习路径：

1. **阅读增强版课程** (Day01-14 增强版)

2. **阅读源码**
   ```bash
   # 从简单组件开始
   less folly/container/small_vector.h

   # 到复杂组件
   less folly/container/F14Map.h
   ```

3. **编译器探索**
   ```bash
   # 查看汇编代码
   g++ -S -O2 -std=c++17 test.cpp -o test.s
   cat test.s
   ```

4. **使用 Compiler Explorer**
   https://godbolt.org/ (实时查看汇编)

### Q24: 如何参与 Folly 开源社区？

**A**: 参与方式：

1. **报告 Bug**
   https://github.com/facebook/folly/issues

2. **贡献代码**
   ```bash
   # Fork 项目
   # 创建分支
   git checkout -b feature/my-feature

   # 提交 PR
   ```

3. **改进文档**
   - 修正错误
   - 添加示例
   - 翻译文档

4. **分享经验**
   - 技术博客
   - Stack Overflow
   - 会议演讲

---

## 🔍 故障排除

### Q25: "undefined reference to folly::*"

**A**: 链接错误

**解决**:
```bash
# 1. 检查是否链接了 folly
g++ ... -lfolly

# 2. 检查库路径
g++ -L/path/to/folly/lib ... -lfolly

# 3. 设置运行时库路径
export LD_LIBRARY_PATH=/path/to/folly/lib:$LD_LIBRARY_PATH
```

### Q26: "fatal error: folly/*.h: No such file"

**A**: 找不到头文件

**解决**:
```bash
# 1. 检查安装路径
ls /usr/local/include/folly/

# 2. 添加 include 路径
g++ -I/path/to/folly/include ...

# 3. 或设置 CMAKE_PREFIX_PATH
cmake -DCMAKE_PREFIX_PATH=/path/to/folly ..
```

### Q27: 程序崩溃或内存泄漏

**A**: 调试步骤

```bash
# 1. 使用 AddressSanitizer
g++ -fsanitize=address -g program.cpp -lfolly
./program

# 2. 使用 Valgrind
valgrind --tool=memcheck --leak-check=full ./program

# 3. 检查是否误用 Arena
# ❌ 错误：释放了 Arena 后还在使用指针
void* ptr;
{
    folly::SysArena arena;
    ptr = arena.allocate(100);
}  // Arena 析构
use(ptr);  // ← 崩溃！ptr 已无效
```

---

## 📖 更多资源

### 官方文档
- **GitHub**: https://github.com/facebook/folly
- **Wiki**: https://github.com/facebook/folly/wiki
- **API Docs**: https://facebook.github.io/folly/

### 社区
- **Stack Overflow**: https://stackoverflow.com/questions/tagged/folly
- **Reddit**: https://reddit.com/r/cpp
- **Discord**: Folly 社区服务器

### 课程资源
- **快速入门**: QUICKSTART.md
- **术语表**: GLOSSARY.md
- **面试题**: INTERVIEW_QUESTIONS.md
- **故障排查**: TROUBLESHOOTING.md

---

## ❓ 没有找到答案？

**更多帮助**：
1. 搜索课程文档
2. 查看 Folly 源码
3. 提交 GitHub Issue
4. 在 Stack Overflow 提问

**提问建议**：
- 提供最小可复现示例
- 说明编译器和版本
- 包含错误信息
- 描述已尝试的解决方法

---

**更新日期**: 2024-01-30
**版本**: v1.0
