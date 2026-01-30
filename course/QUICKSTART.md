# Folly 5分钟快速入门

## 🎯 目标

在 5 分钟内：
1. 理解 Folly 是什么
2. 成功构建 Folly
3. 运行第一个示例
4. 了解核心组件

---

## ⏱️ 第 1 分钟：Folly 是什么？

**一句话**：Facebook 开源的高性能 C++ 库。

**核心优势**：
- ⚡ 比 STL 快 2-10 倍
- 📦 生产环境验证
- 🔧 实用工具集

**典型用途**：
```cpp
// 高性能哈希表（比 std::unordered_map 快 2-3x）
folly::F14FastMap<std::string, int> map;

// 小数组优化（快 7x）
folly::small_vector<int, 8> vec;

// 事件驱动（高性能网络）
folly::EventBase evb;

// 协程（简化异步代码）
folly::coro::Task<int> task();
```

---

## ⏱️ 第 2 分钟：构建 Folly

### 方式 1：使用 getdeps.py（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/facebook/folly.git
cd folly

# 2. 安装系统依赖
sudo python3 ./build/fbcode_builder/getdeps.py install-system-deps --recursive

# 3. 构建
python3 ./build/fbcode_builder/getdeps.py build folly --allow-system-packages
```

### 方式 2：使用 CMake

```bash
# 1. 安装依赖（Ubuntu/Debian）
sudo apt install \
    g++ \
    cmake \
    libboost-all-dev \
    libevent-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libssl-dev

# 2. 构建
mkdir _build && cd _build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# 3. 安装（可选）
sudo make install
```

### 验证安装

```bash
# 检查头文件
ls /usr/local/include/folly/

# 检查库文件
ls /usr/local/lib/libfolly.*
```

---

## ⏱️ 第 3 分钟：第一个示例

### Hello Folly

创建文件 `hello_folly.cpp`：

```cpp
#include <folly/FBString.h>
#include <folly/container/F14Map.h>
#include <iostream>

int main() {
    // 1. FBString - 高性能字符串
    folly::fbstring str = "Hello, Folly!";
    std::cout << str << std::endl;

    // 2. F14Map - 高性能哈希表
    folly::F14FastMap<std::string, int> wordCounts;
    wordCounts["hello"] = 1;
    wordCounts["folly"] = 2;

    // 3. 异构查找（无需构造 string）
    folly::StringPiece key = "hello";
    std::cout << "Count: " << wordCounts[key] << std::endl;

    return 0;
}
```

### 编译运行

```bash
# 编译
g++ -std=c++17 \
    -I/path/to/folly \
    -L/path/to/folly/lib \
    -lfolly \
    -pthread \
    hello_folly.cpp -o hello_folly

# 运行
export LD_LIBRARY_PATH=/path/to/folly/lib:$LD_LIBRARY_PATH
./hello_folly
```

**输出**：
```
Hello, Folly!
Count: 1
```

---

## ⏱️ 第 4 分钟：核心组件速览

### 1. 容器（Container）

```cpp
#include <folly/container/F14Map.h>
#include <folly/container/small_vector.h>

// F14 哈希表（快 2-3x，省 40% 内存）
folly::F14FastMap<int, std::string> map;

// 小向量优化（前 8 个元素在栈上）
folly::small_vector<int, 8> vec;
```

**何时使用**：
- 需要高性能哈希表 → F14Map
- 小数组（通常 < 8 个元素）→ small_vector

### 2. 内存（Memory）

```cpp
#include <folly/memory/Arena.h>

// Arena 批量分配（快 10x）
folly::SysArena arena;
for (int i = 0; i < 10000; ++i) {
    void* ptr = arena.allocate(64);
    // 使用 ptr
}
// Arena 析构时一次性释放
```

**何时使用**：
- 批量分配相同生命周期的对象
- 临时对象快速创建和销毁

### 3. 同步（Synchronization）

```cpp
#include <folly/synchronization/Baton.h>

// Baton 一次性同步（快 5-10x）
folly::Baton<> baton;

// 线程 1
baton.wait();  // 等待

// 线程 2
baton.post();  // 唤醒
```

**何时使用**：
- 一次性事件通知
- 替代 condition_variable

### 4. 异步（Async）

```cpp
#include <folly/io/async/EventBase.h>
#include <folly/coro/Task.h>

// EventBase 事件循环
folly::EventBase evb;
evb.runAfterDelay([]() {
    std::cout << "Timer fired!" << std::endl;
}, 1000);
evb.loopForever();

// 协程
folly::coro::Task<int> compute() {
    co_await folly::coro::sleep(100ms);
    co_return 42;
}
```

**何时使用**：
- 高性能网络服务
- 异步 I/O 操作

---

## ⏱️ 第 5 分钟：性能对比

### F14Map vs std::unordered_map

```cpp
#include <folly/container/F14Map.h>
#include <unordered_map>
#include <chrono>

// 基准测试
void benchmark() {
    const int N = 100000;

    // std::unordered_map
    auto start = std::chrono::high_resolution_clock::now();
    std::unordered_map<int, int> std_map;
    for (int i = 0; i < N; ++i) {
        std_map[i] = i * 2;
    }
    auto end = std::chrono::high_resolution_clock::now();
    auto std_time = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    // F14FastMap
    start = std::chrono::high_resolution_clock::now();
    folly::F14FastMap<int, int> f14_map;
    for (int i = 0; i < N; ++i) {
        f14_map[i] = i * 2;
    }
    end = std::chrono::high_resolution_clock::now();
    auto f14_time = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

    std::cout << "std::unordered_map: " << std_time.count() << " μs\n";
    std::cout << "F14FastMap: " << f14_time.count() << " μs\n";
    std::cout << "Speedup: " << (double)std_time.count() / f14_time.count() << "x\n";
}
```

**典型结果**：
```
std::unordered_map: 15000 μs
F14FastMap: 8000 μs
Speedup: 1.875x
```

---

## 📦 下一步

### 立即开始

1. **阅读学习指南**
   ```bash
   cat Day00_学习指南.md
   ```

2. **完成第一个完整项目**
   - Day 1: 构建系统
   - Day 4-5: F14 哈希表
   - Day 14: 综合项目

3. **查看代码示例**
   ```bash
   cat CODE_EXAMPLES.md
   ```

### 学习路径

**快速预览**（1 周）：
```
Day00 → Day01 → Day04 → Day07 → Day11 → Day14
```

**标准学习**（2-4 周）：
```
Day00 → Day01-14（基础版）→ 选择增强版深入
```

**深度学习**（4-6 周）：
```
Day00 → Day01-14（基础版+增强版）→ 源码阅读 → 实战项目
```

---

## 🔧 常见问题

### Q: 编译错误：找不到 folly 头文件

**A**：设置正确的 include 路径
```bash
g++ -I/path/to/folly/include ...
```

### Q: 链接错误：undefined reference

**A**：链接 folly 库
```bash
g++ ... -lfolly
```

### Q: 运行时错误：找不到共享库

**A**：设置库路径
```bash
export LD_LIBRARY_PATH=/path/to/folly/lib:$LD_LIBRARY_PATH
```

---

## 📚 推荐资源

### 官方文档
- **GitHub**：https://github.com/facebook/folly
- **文档**：https://facebook.github.io/folly/
- **Wiki**：https://github.com/facebook/folly/wiki

### 课程资源
- **学习指南**：Day00_学习指南.md
- **可视化**：VISUAL_GUIDE.md
- **代码示例**：CODE_EXAMPLES.md
- **习题集**：EXERCISES.md

### 外部资源
- **CppCon 演讲**：搜索 "Folly performance"
- **Compiler Explorer**：https://godbolt.org/（查看汇编代码）

---

## ✅ 检查清单

完成以下任务，表示你已经入门：

- [ ] 成功构建 Folly
- [ ] 运行了第一个示例
- [ ] 理解 F14Map 的优势
- [ ] 知道何时使用 small_vector
- [ ] 了解 EventBase 的用途
- [ ] 看过协程代码示例

---

## 🎉 恭喜！

你已经完成了 Folly 快速入门！

**下一步**：
1. 选择学习路径
2. 跟随 Day00 学习指南
3. 完成课后练习
4. 尝试实战项目

**祝学习愉快！** 🚀

---

**版本**：v1.0
**最后更新**：2024-01-30
