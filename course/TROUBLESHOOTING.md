# Folly 课程 - 故障排查指南

## 构建问题

### 问题 1：找不到 Folly 头文件

**症状**：
```
fatal error: folly/F14Map.h: No such file or directory
```

**解决方案**：

```bash
# 检查 Folly 是否已安装
ls /usr/local/include/folly/

# 如果不存在，重新构建
cd folly
python3 ./build/fbcode_builder/getdeps.py install-system-deps --recursive
python3 ./build/fbcode_builder/getdeps.py build folly --allow-system-packages

# 或使用 CMake 直接构建
mkdir _build && cd _build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make install
```

---

### 问题 2：链接错误 - undefined reference

**症状**：
```
undefined reference to `folly::someFunction'
```

**解决方案**：

```bash
# 检查是否链接了 folly 库
# CMakeLists.txt
target_link_libraries(your_target PRIVATE folly)

# 如果使用 pkg-config
pkg-config --libs folly
```

---

### 问题 3：getdeps.py 失败

**症状**：
```
Error: Failed to download dependency
```

**解决方案**：

```bash
# 检查网络连接
ping github.com

# 使用代理
export http_proxy=http://proxy.example.com:8080
export https_proxy=http://proxy.example.com:8080

# 或手动下载依赖
python3 ./build/fbcode_builder/getdeps.py download --no-build
```

---

## 编译警告

### 警告 1：deprecated declarations

**症状**：
```
warning: 'auto_ptr' is deprecated
```

**解决方案**：

```bash
# 添加编译选项禁用特定警告
-Wno-deprecated-declarations

# 或在代码中使用现代替代
# std::auto_ptr → std::unique_ptr
```

---

### 警告 2：unused variables

**症状**：
```
warning: unused variable 'x'
```

**解决方案**：

```cpp
// 使用 [[maybe_unused]]
[[maybe_unused]] int x = compute();

// 或使用 folly::doNotOptimize
#include <folly/Benchmark.h>
int x = compute();
folly::doNotOptimize(x);
```

---

## 运行时问题

### 问题 1：Segmentation fault

**症状**：
```
Segmentation fault (core dumped)
```

**调试步骤**：

```bash
# 1. 使用 gdb 调试
gdb ./program
(gdb) run
(gdb) backtrace  # 查看调用栈

# 2. 使用 valgrind 检测内存错误
valgrind --tool=memcheck ./program

# 3. 检查是否使用了已释放的内存
# 使用 AddressSanitizer
g++ -fsanitize=address -g program.cpp -o program
./program
```

---

### 问题 2：性能不如预期

**症状**：程序比标准库慢

**检查清单**：

```bash
# 1. 确认启用了优化
cmake .. -DCMAKE_BUILD_TYPE=Release

# 2. 检查编译器版本
g++ --version  # 应该 >= 9.0

# 3. 使用 perf 分析
perf record ./program
perf report

# 4. 检查是否正确使用了 Folly 组件
# 例如：small_vector 应该用于小数组
```

---

### 问题 3：内存泄漏

**症状**：程序内存持续增长

**调试步骤**：

```bash
# 1. 使用 valgrind 检测
valgrind --tool=memcheck --leak-check=full --show-leak-kinds=all ./program

# 2. 使用 AddressSanitizer
g++ -fsanitize=address -g program.cpp -o program
./program

# 3. 检查 Arena 使用
# Arena 会延迟释放，确保析构
```

---

## 平台特定问题

### Linux 特定

**问题**：libevent not found

```bash
# Ubuntu/Debian
sudo apt install libevent-dev

# CentOS/RHEL
sudo yum install libevent-devel

# 从源码安装
wget https://github.com/libevent/libevent/releases/download/v2.1.12-stable/libevent-2.1.12-stable.tar.gz
tar xzf libevent-2.1.12-stable.tar.gz
cd libevent-2.1.12-stable
./configure && make && sudo make install
```

---

### macOS 特定

**问题**：Boost not found

```bash
# 使用 Homebrew
brew install boost

# 设置 CMAKE_PREFIX_PATH
export CMAKE_PREFIX_PATH="/usr/local;$CMAKE_PREFIX_PATH"

# 或在 CMake 中指定
cmake .. -DBOOST_ROOT=/usr/local
```

---

### Windows 特定

**问题**：CMake 配置失败

```bash
# 使用 vcpkg 管理依赖
vcpkg install boost-libevent gflags glog

# 指定工具链
cmake .. -DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake

# 使用 Visual Studio
cmake .. -G "Visual Studio 16 2019"
```

---

## 性能调优

### 问题 1：编译时间过长

**解决方案**：

```bash
# 使用 ccache
sudo apt install ccache
export CC="gcc"
export CXX="g++"

# 或在 CMake 中启用
cmake .. -DCMAKE_C_COMPILER_LAUNCHER=ccache \
          -DCMAKE_CXX_COMPILER_LAUNCHER=ccache

# 使用 Ninja
cmake .. -GNinja
ninja -j$(nproc)
```

---

### 问题 2：二进制文件过大

**解决方案**：

```bash
# 优化大小
cmake .. -DCMAKE_BUILD_TYPE=MinSizeRel

# 分离调试符号
cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo
strip program

# 或使用 LTO
cmake .. -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=TRUE
```

---

## 测试问题

### 问题 1：测试失败

**症状**：ctest 显示某些测试失败

**调试步骤**：

```bash
# 运行特定测试
./folly/test/container_test/F14MapTest

# 使用详细输出
./folly/test/container_test/F14MapTest --gtest_verbose

# 检查是否是环境问题
ulimit -c unlimited  # 允许生成 core dump
```

---

### 问题 2：基准测试不稳定

**症状**：每次运行结果不同

**解决方案**：

```bash
# 固定 CPU 频率
sudo cpupower frequency-set -g performance

# 禁用 CPU 节能
sudo tuned-adm profile throughput-performance

# 使用更多迭代
./benchmark --benchmark_min_time=10s --benchmark_repetitions=10

# 绑定到特定 CPU
taskset -c 0 ./benchmark
```

---

## 常见错误消息

### 错误 1：static_assert failed

**症状**：
```
static_assert failed "Folly requires C++17 or later"
```

**解决方案**：

```bash
# 检查 C++ 标准
g++ --version  # 应该支持 C++17

# 在 CMake 中指定
cmake .. -DCMAKE_CXX_STANDARD=17

# 或在编译命令中指定
g++ -std=c++17 ...
```

---

### 错误 2：template instantiation failed

**症状**：
```
error: template instantiation failed
```

**解决方案**：

```cpp
// 检查模板参数是否满足要求
// 例如：F14Map 要求键是可哈希的

// 提供哈希函数
struct MyHash {
    size_t operator()(const MyKey& key) const {
        return std::hash<int>{}(key.id);
    }
};

using MyMap = folly::F14FastMap<MyKey, int, MyHash>;
```

---

## 获取帮助

### 官方资源

- **GitHub Issues**：https://github.com/facebook/folly/issues
- **Folly Wiki**：https://github.com/facebook/folly/wiki
- **Stack Overflow**：https://stackoverflow.com/questions/tagged/folly

### 社区

- **Facebook Folly Group**：https://www.facebook.com/groups/folly.dev
- **Reddit r/cpp**：https://reddit.com/r/cpp
- **C++ Slack**：https://cpp.slack.com/

### 调试工具

```bash
# gdb - GNU 调试器
gdb ./program

# lldb - LLVM 调试器
lldb ./program

# valgrind - 内存调试
valgrind --tool=memcheck ./program

# perf - 性能分析
perf record ./program
```

---

## 预防措施

### 开发环境设置

```bash
# 1. 使用最新编译器
# GCC >= 11.0, Clang >= 13.0

# 2. 启用所有警告
cmake .. -Wall -Wextra -Wpedantic

# 3. 使用 AddressSanitizer
cmake .. -DCMAKE_CXX_FLAGS="-fsanitize=address -g"

# 4. 运行测试
cmake .. -DBUILD_TESTS=ON
make test
```

### 代码审查清单

- [ ] 是否正确使用了 Folly 组件
- [ ] 是否避免了不必要的拷贝
- [ ] 是否正确处理了异常
- [ ] 是否线程安全
- [ ] 是否有内存泄漏
- [ ] 是否有性能瓶颈

---

**更新日期**：2024-01-30

**版本**：v1.0
