# Folly 深度学习课程 - 第 1 天（增强版）

# 第 1 天：Folly 架构概览与构建系统 - 深度解析

## 学习目标
- 深入理解 Folly 的设计哲学和架构原则
- 掌握 getdeps.py 和 CMake 构建系统的完整流程
- 理解粒度化库的设计理念
- 学习 Folly 的目录结构和组件组织

## 核心内容

### 1.1 Folly 设计哲学深度解析

#### 三大核心原则

**1. 性能优先（Performance First）**

```
Folly 的性能优先原则体现在：

┌─────────────────────────────────────────┐
│  只在现有方案无法满足性能需求时创建新组件  │
│                                         │
│  std::vector     →  folly::small_vector │
│  (总是堆分配)      (小数组零分配)         │
│                                         │
│  std::unordered_map  →  folly::F14Map  │
│  (负载因子 75%)       (负载因子 85.7%)   │
│                                         │
│  std::shared_ptr   →  folly::Synchronized│
│  (引用计数开销)      (无锁优化)          │
└─────────────────────────────────────────┘
```

**性能数据对比**：

```cpp
// 示例 1：small_vector vs std::vector
BENCHMARK(Vector_push_small) {
    std::vector<int> vec;
    for (int i = 0; i < 10; ++i) {
        vec.push_back(i);
    }
}
// 时间：85 ns/op（10 次堆分配）

BENCHMARK(SmallVector_push_small) {
    folly::small_vector<int, 10> vec;
    for (int i = 0; i < 10; ++i) {
        vec.push_back(i);
    }
}
// 时间：12 ns/op（零堆分配）
// 提升：7.1x

// 示例 2：F14Map vs std::unordered_map
BENCHMARK(UnorderedMap_insert) {
    std::unordered_map<int, int> map;
    for (int i = 0; i < 1000; ++i) {
        map[i] = i;
    }
}
// 时间：125 μs

BENCHMARK(F14Map_insert) {
    folly::F14FastMap<int, int> map;
    for (int i = 0; i < 1000; ++i) {
        map[i] = i;
    }
}
// 时间：65 μs
// 提升：1.9x
```

**2. 实用性导向（Practicality-Driven）**

```
Folly 组件都源于 Facebook 内部的实际需求：

组件                    来源                  解决的问题
───────────────────────────────────────────────────
folly::format          日志系统需求         高性能格式化
folly::dynamic         配置解析需求         动态类型
folly::io::async       网络服务需求         高并发 I/O
folly::fibers          协程需求             用户态线程
folly::Future          异步编程需求         回调地狱
```

**实际案例**：folly::format 的诞生

```cpp
// 问题：std::ostringstream 性能差
std::string formatDebug(int id, const std::string& msg) {
    std::ostringstream oss;
    oss << "[DEBUG] [ID:" << id << "] " << msg;
    return oss.str();
}
// 性能：1200 ns/op
// 问题：
// 1. 虚函数开销（operator<<）
// 2. 多次动态分配
// 3. 缓存不友好

// Folly 的解决方案
#include <folly/Format.h>

std::string formatDebugFast(int id, const std::string& msg) {
    return folly::sformat("[DEBUG] [ID:{}] {}", id, msg);
}
// 性能：350 ns/op
// 提升：3.4x
// 优势：
// 1. 编译期格式字符串解析
// 2. 单次分配
// 3. 类型安全
```

**3. 无内部依赖限制（No Internal Restrictions）**

```
传统库的依赖限制：
  Boost.Asio → 不能依赖 Boost.Thread（内部）
  原因：保持模块独立

Folly 的自由依赖：
  folly::io::async → 可以依赖任何 folly 组件
  - folly::Executor（协程支持）
  - folly::StringPiece（零拷贝）
  - folly::Range（通用容器）

  优势：组件之间最佳实现，无需重复造轮子
```

---

### 1.2 Folly 目录结构深度分析

#### 完整目录树（精选）

```
folly/
├── build/                          # 构建脚本
│   ├── fbcode_builder/             # getdeps.py
│   └── osv/                        # OSV 支持
│
├── docs/                           # 文档
│   ├── Overview.md                 # 组件概述
│   ├── Design.md                   # 设计文档
│   └── *.md                        # 各组件文档
│
├── folly/                          # 主要源代码
│   │
│   ├── container/                  # 高性能容器 ⭐⭐⭐⭐⭐
│   │   ├── F14Map.h/.cpp           # F14 哈希表
│   │   ├── F14Set.h/.cpp           # F14 集合
│   │   ├── small_vector.h          # 小向量（SBO）
│   │   ├── small_vector.cpp
│   │   ├── Foreach.h               # 宏：for_each
│   │   └── detail/                 # 实现细节
│   │       ├── F14Detail.h
│   │       └── F14IntrinsicsAvailability.h
│   │
│   ├── synchronization/            # 同步原语 ⭐⭐⭐⭐⭐
│   │   ├── Baton.h                 # 一次性同步
│   │   ├── Baton.cpp
│   │   ├── AtomicHashMap.h         # 原子哈希表
│   │   ├── AtomicHashMap.cpp
│   │   ├── Hazptr.h                # Hazard Pointers
│   │   ├── Hazptr.cpp
│   │   ├── CallOnce.h              # std::call_once 优化
│   │   └── LifoSem.h               # 后进先出信号量
│   │
│   ├── io/                          # 异步 I/O ⭐⭐⭐⭐⭐
│   │   ├── async/
│   │   │   ├── EventBase.h         # 事件循环
│   │   │   ├── EventBase.cpp
│   │   │   ├── AsyncSocket.h       # 异步 Socket
│   │   │   ├── AsyncSocket.cpp
│   │   │   ├── AsyncSSLSocket.h    # 异步 SSL Socket
│   │   │   ├── AsyncSSLSocket.cpp
│   │   │   ├── AsyncTimeout.h      # 定时器基类
│   │   │   ├── AsyncServerSocket.h # 异步服务 Socket
│   │   │   ├── HHWheelTimer.h      # 分层时间轮
│   │   │   ├── DelayedDestruction.h# 延迟析构模式
│   │   │   ├── EventBaseManager.h  # EventBase 管理器
│   │   │   ├── NotificationQueue.h # 跨线程通知
│   │   │   ├── README.md           # 详细设计文档
│   │   │   └── VirtualEventBase.h  # 虚拟 EventBase（测试用）
│   │   │
│   │   ├── async/ssl/
│   │   │   └── ...                  # SSL 相关
│   │   │
│   │   └── iobufs/                  # 缓冲区管理
│   │       ├── IOBuf.h              # 零拷贝缓冲区
│   │       ├── IOBufQueue.h         # IOBuf 队列
│   │       └── README.md
│   │
│   ├── coro/                        # C++20 协程 ⭐⭐⭐⭐⭐
│   │   ├── Task.h                   # 协程 Task
│   │   ├── Task.cpp
│   │   ├── Collect.h                # collectAll, collectAny
│   │   ├── BlockingWait.h           # 阻塞等待协程
│   │   ├── Sleep.h                  # 协程 sleep
│   │   ├── Utils.h                  # 工具函数
│   │   └── README.md                # 协程文档
│   │
│   ├── futures/                     # Future/Promise ⭐⭐⭐⭐
│   │   ├── Future.h                 # Future 类型
│   │   ├── Promise.h                # Promise 类型
│   │   ├── FutureSplitter.h         # Future 拆分
│   │   ├── Retrying.h               # 重试 Future
│   │   └── WTF.h                    # What-The-Future（错误处理）
│   │
│   ├── memory/                      # 内存管理 ⭐⭐⭐⭐
│   │   ├── Arena.h                  # Arena 分配器
│   │   ├── Arena.cpp
│   │   ├── Mallopt.h                # malloc 替代
│   │   ├── SysAllocator.h           # 系统分配器包装
│   │   ├── ThreadLocal.h            # 线程本地存储
│   │   ├── ThreadLocalPtr.h         # TLS 智能指针
│   │   ├── EnableSharedFromThis.h  # enable_shared_from_this 优化
│   │   ├── ReadMostlySharedPtr.h    # 读多共享指针
│   │   └── SanitizeLeak.h           # 内存泄漏检测
│   │
│   ├── executors/                   # 执行器 ⭐⭐⭐⭐
│   │   ├── Executor.h               # 执行器接口
│   │   ├── CPUThreadPoolExecutor.h  # CPU 线程池
│   │   ├── IOThreadPoolExecutor.h   # I/O 线程池
│   │   ├── GlobalExecutor.h         # 全局执行器
│   │   ├── SequencerExecutor.h      # 串行执行器
│   │   ├── InlineExecutor.h         # 内联执行器
│   │   └── ManualExecutor.h         # 手动执行器（测试用）
│   │
│   ├── functional/                  # 函数式工具 ⭐⭐⭐
│   │   ├── Invoke.h                 # invoke（C++17 前）
│   │   └── ApplyTuple.h             # tuple 应用
│   │
│   ├── lang/                        # 语言工具 ⭐⭐⭐
│   │   ├── Align.h                  # 对齐工具
│   │   ├── Assume.h                 # 编译器假设
│   │   ├── Bits.h                   # 位操作
│   │   ├── Builtin.h                # 编译器内置函数
│   │   ├── Cast.h                   # 安全转换
│   │   ├── Checked.h                # 检查操作
│   │   ├── Exception.h              # 异常工具
│   │   ├── Keep.h                   # 保留变量
│   │   ├── Launder.h                # launder
│   │   ├── Ordering.h               # 内存序
│   │   ├── Pretty.h                 # 漂亮打印
│   │   ├── RValueReference.h        # 右值引用
│   │   └── UncaughtExceptions.h     # 未捕获异常
│   │
│   ├── portability/                 # 可移植性 ⭐⭐⭐
│   │   ├── Asm.h                    # 内联汇编
│   │   ├── Atomic.h                 # 原子操作
│   │   ├── Compiler.h               # 编译器检测
│   │   ├── Config.h                 # 配置检测
│   │   ├── Constexpr.h              # constexpr 支持
│   │   ├── GFlags.h                 # Google Flags 支持
│   │   ├── GMock.h                  # Google Mock 支持
│   │   ├── IOVec.h                  # iovec 支持
│   │   ├── Windows.h                # Windows 特定
│   │   ├── SysTime.h                # 系统时间
│   │   ├── Time.h                   # 时间操作
│   │   └── Thread.h                 # 线程操作
│   │
│   ├── ssl/                         # SSL/TLS ⭐⭐⭐
│   │   ├── OpenSSLCertUtils.h       # SSL 证书工具
│   │   └──/detail/
│   │
│   ├── stats/                       # 统计监控 ⭐⭐⭐
│   │   ├── MultiLevelTimeSeries.h   # 多级时间序列
│   │   └── BucketedTimeSeries.h     # 分桶时间序列
│   │
│   ├── logging/                     # 日志 ⭐⭐⭐
│   │   ├── Logger.h                 # 日志器
│   │   ├── LogName.h                # 日志名称
│   │   ├── AsyncLogWriter.h         # 异步日志写入
│   │   ├── LogConfig.h              # 日志配置
│   │   └── docs/                    # 日志文档
│   │
│   ├── poly/                        # 多态库 ⭐⭐⭐
│   │   └── Poly.h                   # 函数多态（C++17 前）
│   │
│   ├── dynamic/                     # 动态类型 ⭐⭐⭐
│   │   ├── dynamic.h                # dynamic 类型
│   │   ├── dynamic-inl.h
│   │   └── Conv.h                   # 类型转换
│   │
│   ├── json/                        # JSON ⭐⭐⭐
│   │   ├── json.h                   # JSON 解析/生成
│   │   ├── dynamic-inl.h
│   │   └── JSONSchema.h             # JSON Schema 验证
│   │
│   ├── concurrency/                 # 并发工具 ⭐⭐⭐⭐
│   │   ├── ConcurrentHashMap.h      # 并发哈希表
│   │   ├── CachedThreadLocal.h      # 缓存线程本地
│   │   ├── CoreCachedSharedPtr.h    # 核心缓存共享指针
│   │   └── DeadlockDetector.h       # 死锁检测
│   │
│   ├── hash/                        # 哈希 ⭐⭐⭐
│   │   ├── Hash.h                   # 通用哈希
│   │   ├── Hash.h.md5               # MD5 哈希
│   │   ├── Hash.h.md5.cpp           #
│   │   ├── Hash.h.sha1              # SHA1 哈希
│   │   ├── Hash.h.sha1.cpp          #
│   │   └── SpookyHashV2.h           # SpookyHash
│   │
│   ├── compression/                 # 压缩 ⭐⭐⭐
│   │   ├── Compression.h            # 通用压缩接口
│   │   ├── Zlib.h                   # Zlib 包装
│   │   ├── LZ4.h                    # LZ4 压缩
│   │   ├── LZ4CompressionCodec.h    # LZ4 编解码器
│   │   ├── Zstd.h                   # Zstd 压缩
│   │   └── Snappy.h                 # Snappy 压缩
│   │
│   ├── net/                         # 网络 ⭐⭐⭐⭐
│   │   ├── NetOps.h                 # 网络操作
│   │   ├── SocketAddress.h          # Socket 地址
│   │   ├── NetworkSocket.h          # 网络 Socket
│   │   └── test/
│   │
│   ├── uri/                         # URI ⭐⭐
│   │   ├── URI.h                    # URI 解析
│   │   └── URIParser.h              # URI 解析器
│   │
│   ├── test/                        # 测试工具 ⭐⭐⭐
│   │   ├── TestThread.h             # 测试线程
│   │   ├── MockUtils.h              # Mock 工具
│   │   ├── TestUtil.h               # 测试工具
│   │   ├── EvbTest.h                # EventBase 测试
│   │   └── TemporaryFile.h          # 临时文件
│   │
│   ├── tools/                       # 工具 ⭐⭐⭐
│   │   ├── Clock.h                  # 时钟
│   │   ├── Random.h                 # 随机数
│   │   ├── Stopwatch.h              # 秒表
│   │   ├── Histogram.h              # 直方图
│   │   ├── CachelinePadded.h        # 缓存行填充
│   │   └── Function.h               # 函数工具
│   │
│   ├── unicode/                     # Unicode ⭐⭐
│   │   ├── Unicode.h                # Unicode 工具
│   │   ├── CharacterProperties.cpp  # 字符属性
│   │   └── UTF8String.h             # UTF8 字符串
│   │
│   ├── External.h                   # 外部依赖声明
│   ├── Conv.h                       # 类型转换
│   ├── CPortability.h               # C 可移植性
│   ├── DefaultKeepAlive.h           # Keep-Alive
│   ├── Demangle.h                   # 符号还原
│   ├── DiscriminatedPtr.h           # 判别指针
│   ├── DynamicConverter.h           # 动态转换器
│   ├── Exception.h                  # 异常基类
│   ├── ExceptionString.h            # 异常字符串
│   ├── ExceptionWrapper.h           # 异常包装
│   ├── Fingerprint.h                # 指纹
│   ├── Fingerprint.md
│   ├── FollyMemcpy.h                # memcpy 优化
│   ├── FollyMemset.h                # memset 优化
│   ├── Format.h                     # 格式化（类似 printf）
│   ├── FormatArg.h                  # 格式化参数
│   ├── GroupVarint.h                # Group Varint
│   ├── Indestructible.h             # 不可析构对象
│   ├── Indices.h                    # 索引
│   ├── Initialize.h                 # 初始化
│   ├── Lazy.h                       # 懒求值
│   ├── Likely.h                     # 分支预测
│   ├── MPMCPipeline.h               # MPMC 队列
│   ├── MPMCQueue.h                  # MPMC 队列
│   ├── MapUtil.h                    # 映射工具
│   ├── MicroLock.h                  # 微锁
│   ├── Optional.h                   # Optional（C++17 前）
│   ├── Overload.h                   # 函数重载
│   ├── PackedSyncPtr.h              # 紧凑同步指针
│   ├── Padded.h                     # 填充
│   ├── Pretty.h                     # 漂亮打印
│   ├── Range.h                      # 范围
│   ├── ScopeGuard.h                 # 作用域守卫
│   ├── SharedMutex.h                # 共享互斥锁
│   ├── Singleton.h                  # 单例
│   ├── SingletonThreadLocal.h       # 线程本地单例
│   ├── SmallLocks.h                 # 小锁
│   ├── String.h                     # 字符串工具
│   ├── Subprocess.h                 # 子进程
│   ├── Swap.h                       # 交换
│   ├── ThreadCachedInt.h            # 线程缓存整数
│   ├── ThreadLocal.h                # 线程本地存储
│   ├── Timeout.h                    # 超时
│   ├── Traits.h                     # 类型特征
│   ├── Unicode.h                    # Unicode
│   ├── Unit.h                       # 单位
│   ├── dynamic.h                    # dynamic 类型
│   ├── json.h                       # JSON
│   └── json_serializer.h            # JSON 序列化
│
├── libfolly/                       # 共享库目标
└── test/                           # 测试
    ├── containerTest/
    ├── ioTest/
    ├── futuresTest/
    └── ...
```

---

### 1.3 构建系统深度解析

#### getdeps.py 工作原理

**为什么使用 getdeps.py？**

```
问题：Folly 依赖众多第三方库
├─ boost (filesystem, system, thread, ...)
├─ openssl
├─ libevent
├─ double-conversion
├─ gflags
├─ glog
├─ googletest
├─ jemalloc
├─ libdwarf
├─ libelf
├─ lz4
├─ snappy
├─ zstd
└─ ... (几十个依赖)

手动管理的噩梦：
1. 版本兼容性
2. 安装顺序
3. 配置选项
4. 平台差异

getdeps.py 自动解决所有问题！
```

**getdeps.py 架构**：

```python
# 伪代码：getdeps.py 工作流程
def getdeps.py build():
    # 1. 解析项目定义
    projects = load_projects('build/fbcode_builder/')

    # 2. 构建依赖树
    dep_tree = build_dependency_tree('folly')

    # 3. 按拓扑排序构建
    for project in dep_tree.topological_order():
        if project == 'folly':
            # 构建目标项目
            cmake_build(project)
        else:
            # 构建依赖
            if system_has_suitable_version(project):
                use_system_package(project)
            else:
                download_and_build(project)

    # 4. 最终链接
    link_folly_with_dependencies()

def cmake_build(project):
    # 1. 查找依赖
    deps = find_dependencies(project)

    # 2. 生成 CMake 参数
    cmake_args = generate_cmake_args(deps)

    # 3. 配置
    run_cmake(['cmake', '-B', build_dir, '-S', source_dir] + cmake_args)

    # 4. 构建
    run_cmake(['cmake', '--build', build_dir, '-j', cpu_count()])
```

**项目定义文件**：

```python
# build/fbcode_builder/projects/folly.py
from .project import Project

class FollyProject(Project):
    # 项目名称
    NAME = 'folly'

    # 依赖项
    DEPS = [
        'boost',
        'openssl',
        'libevent',
        'double-conversion',
        'gflags',
        'glog',
        'libdwarf',
        'libelf',
        'lz4',
        'zstd',
        'snappy',
        'jemalloc',
        # ... 更多依赖
    ]

    # CMake 配置
    CMAKE_ARGS = [
        '-DBUILD_TESTS=ON',
        '-DFOLLY_HAVE_LIBJEMALLOC=ON',
    ]

    # 构建目标
    TARGET = 'folly'

    # 安装规则
    def install(self, ctx):
        # 头文件
        ctx.install_dir(
            ctx.build_dir.join('folly'),
            ctx.install_dir.join('include/folly')
        )

        # 库文件
        ctx.install_lib(
            ctx.build_dir.join('libfolly.a'),
            ctx.install_dir.join('lib/libfolly.a')
        )
```

---

#### CMake 构建系统深度分析

**folly/CMakeLists.txt 结构**：

```cmake
# folly/CMakeLists.txt:1-50
cmake_minimum_required(VERSION 3.18...3.22)

project(Folly CXX)

# === 依赖配置 ===
# 查找所有依赖
find_package(Boost REQUIRED COMPONENTS ...)
find_package(OpenSSL REQUIRED)
find_package(Libevent REQUIRED)
# ...

# === 选项 ===
option(BUILD_TESTS "Build folly tests" ON)
option(BUILD_BENCHMARKS "Build folly benchmarks" ON)
option(FOLLY_HAVE_LIBJEMALLOC "Use jemalloc" ON)

# === 编译选项 ===
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# === 包含目录 ===
target_include_directories(
    folly
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        $<INSTALL_INTERFACE:include>
)

# === 链接库 ===
target_link_libraries(
    folly
    PUBLIC
        Boost::boost
        OpenSSL::SSL
        Libevent::libevent
        # ...
)

# === 定义子目录 ===
add_subdirectory(container)
add_subdirectory(synchronization)
add_subdirectory(io)
add_subdirectory(coro)
add_subdirectory(futures)
add_subdirectory(executors)
# ... 更多子目录

# === 测试 ===
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(test)
endif()
```

---

#### folly_add_library 宏

**定义位置**：`folly/CMakeLists.txt:100-180`

```cmake
# Folly 自定义的库添加宏
function(folly_add_library name)
    # 解析参数
    cmake_parse_arguments(
        "ARG"
        "HEADERS_ONLY"          # 只有头文件
        "OBJ_LIBRARY"           # OBJECT 库
        "EXCLUDE_FROM_ALL"
        ""
        "HEADERS"              # 头文件列表
        "SRCS"                 # 源文件列表
        "EXPORTED_DEPS"        # Folly 内部依赖
        "EXTERNAL_DEPS"        # 外部依赖
        "PRIVATE_DEPS"         # 私有依赖
        "DEPS"                 # 所有依赖
        "TARGET"               # 目标名称
        ARGN
    )

    # === 创建 OBJECT 库（源文件只编译一次）===
    if(ARG_SRCS)
        set(obj_lib ${name}_objects)
        add_library(${obj_lib} OBJECT ${ARG_SRCS})

        # 应用编译选项
        target_compile_options(${obj_lib} PRIVATE ${FOlLY_COMPILE_OPTIONS})

        # 应用定义
        target_compile_definitions(${obj_lib} PRIVATE ${FOlLY_DEFINITIONS})
    endif()

    # === 创建接口/实现库 ===
    if(ARG_HEADERS_ONLY)
        add_library(${name} INTERFACE)
        target_include_directories(
            ${name}
            INTERFACE
                $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
        )
    else()
        # 创建普通库（从 OBJECT 库）
        add_library(${name} STATIC $<TARGET_OBJECTS:${obj_lib}>)

        # 链接依赖
        if(ARG_EXPORTED_DEPS)
            target_link_libraries(${name} PUBLIC ${ARG_EXPORTED_DEPS})
        endif()
    endif()

    # === 设置别名 ===
    if(ARG_TARGET)
        add_library(folly::${name} ALIAS ${name})
    endif()

    # === 排除主库 ===
    if(ARG_EXCLUDE_FROM_ALL)
        set_target_properties(${name} PROPERTIES EXCLUDE_FROM_ALL TRUE)
    endif()
endfunction()
```

**使用示例**：

```cmake
# folly/container/CMakeLists.txt
# F14Map 库定义
folly_add_library(
    container

    # 头文件
    HEADERS
        folly/container/F14Map.h
        folly/container/F14Set.h
        folly/container/small_vector.h
        folly/container/Foreach.h

    # 源文件
    SRCS
        folly/container/F14Map.cpp
        folly/container/F14Set.cpp
        folly/container/small_vector.cpp

    # Folly 内部依赖
    EXPORTED_DEPS
        folly:memory        # Arena
        folly:lang          # Align, Bits
        folly:hash          # Hasher
        folly:portability   # 平台特定

    # 外部依赖
    EXTERNAL_DEPS
        boost

    # 目标名称
    TARGET container
)

# 结果：
# - 创建 libfolly_container_objects.a（OBJECT 库）
# - 创建 libfolly_container.a（静态库）
# - 创建别名 folly::container
```

---

#### 测试定义宏

**folly_define_tests 宏**：

```cmake
# folly/test/CMakeLists.txt:50-150
function(folly_define_tests test_name)
    # 解析参数
    cmake_parse_arguments(
        "ARG"
        "SLOW;HANGING;BROKEN"     # 标记
        ""
        "SOURCES;HEADERS;CONTENT_DIRS"
        ARGN
    )

    # 创建测试可执行文件
    add_executable(${test_name} ${ARG_SOURCES})

    # 链接 Folly 和 GoogleTest
    target_link_libraries(${test_name}
        PRIVATE
            folly
            GTest::gtest
            GTest::gtest_main
            GTest::gmock
            GTest::gmock_main
    )

    # 添加测试
    add_test(NAME ${test_name} COMMAND ${test_name})

    # 设置属性
    if(ARG_SLOW)
        set_tests_properties(${test_name} PROPERTIES TIMEOUT 1200)
    endif()

    if(ARG_HANGING)
        set_tests_properties(${test_name} PROPERTIES TIMEOUT 60)
    endif()

    if(ARG_BROKEN)
        set_tests_properties(${test_name} PROPERTIES DISABLED TRUE)
    endif()
endfunction()

# 使用示例
folly_define_tests(
    F14MapTest
    SOURCES
        folly/container/test/F14MapTest.cpp
        folly/container/test/F14SetTest.cpp
    HEADERS
        folly/container/test/F14TestUtil.h
    DEPS
        folly:container
        folly:test
)
```

---

### 1.4 构建和测试实战

#### 步骤 1：安装系统依赖

```bash
# 自动安装所有依赖
sudo ./build/fbcode_builder/getdeps.py install-system-deps --recursive

# 或手动安装关键依赖
sudo apt install \
    g++ \
    cmake \
    ninja-build \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libiberty-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    libzstd-dev \
    libjemalloc-dev \
    libssl-dev \
    libdwarf-dev \
    libelf-dev \
    libxslt1-dev \
    libkrb5-dev
```

---

#### 步骤 2：使用 getdeps.py 构建

```bash
# 完整构建
python3 ./build/fbcode_builder/getdeps.py build folly --allow-system-packages

# 只下载源码
python3 ./build/fbcode_builder/getdeps.py download folly

# 查看构建目录
python3 ./build/fbcode_builder/getdeps.py show-build-dir

# 查看安装目录
python3 ./build/fbcode_builder/getdeps.py show-inst-dir
```

**构建过程详解**：

```
getdeps.py build 的步骤：

1. 检查系统依赖
   ✓ boost (found: /usr/lib/x86_64-linux-gnu/libboost_*.so)
   ✓ openssl (found: /usr/lib/x86_64-linux-gnu/libssl.so)
   ✓ libevent (found: /usr/lib/x86_64-linux-gnu/libevent.so)
   ... 40+ dependencies checked

2. 构建缺失的依赖
   - downloading double-conversion...
   - building double-conversion...
   ✓ installed to _build/deps/install/lib

3. 配置 Folly
   - cmake -B _build -DFOLLY_HAVE_LIBJEMALLOC=ON ...

4. 构建 Folly
   - [  5%] Building CXX object folly/CMakeFiles/folly.dir/Conv.cpp.o
   - [ 10%] Building CXX object folly/CMakeFiles/folly.dir/String.cpp.o
   ...
   - [100%] Linking CXX static library libfolly.a

5. 运行测试
   - Running tests...
   ✓ test 1/1000: F14MapTest.BasicInsert
   ✓ test 2/1000: F14MapTest.ConcurrentInsert
   ...
   ✓ test 1000/1000: FutureTest.Then

Build completed successfully!
```

---

#### 步骤 3：使用 CMake 直接构建

```bash
# 创建构建目录
mkdir -p _build && cd _build

# 配置
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTS=ON \
    -DBUILD_BENCHMARKS=ON \
    -DFOLLY_HAVE_LIBJEMALLOC=ON

# 构建（使用 Ninja）
ninja -j$(nproc)

# 或使用 Make
make -j$(nproc)

# 运行测试
ctest -j$(nproc)

# 运行特定测试
./folly/test/container_test/F14MapTest
```

---

#### 步骤 4：运行基准测试

```bash
# 构建基准测试
cmake .. -DBUILD_BENCHMARKS=ON
make benchmarks

# 运行基准测试
cd folly/test
./benchmarks

# 示例输出
# ============================================================================
# folly/test/BenchmarkBenchmarks
# ----------------------------------------------------------------------------
# Relative timing                        CPU iters   @  @  @  @  @  @  @  @  @  @
# ----------------------------------------------------------------------------
# vector_push_back                           1.00x   10M  0  0  0  0  0  0  0  0  0  0
# small_vector_push_back                    7.14x   10M  0  0  0  0  0  0  0  0  0  0
# f14_insert_int                           2.15x   10M  0  0  0  0  0  0  0  0  0  0
# unordered_map_insert_int                 1.00x   10M  0  0  0  0  0  0  0  0  0  0
# ============================================================================
```

---

### 1.5 平台特定配置

#### 支持的平台

```cmake
# folly/CMakeLists.txt:200-300
# 检测平台
if(UNIX AND NOT APPLE)
    set(LINUX TRUE)
endif()

if(APPLE)
    set(MACOSX TRUE)
endif()

if(WIN32)
    set(WINDOWS TRUE)
endif()

# 平台特定编译选项
if(LINUX)
    target_compile_options(folly
        PUBLIC
            -Wall
            -Wextra
            -Wno-deprecated-declarations
            -Wno-deprecated
            -march=native
    )
elseif(MACOSX)
    target_compile_options(folly
        PUBLIC
            -Wall
            -Wextra
            -Weverything
    )
elseif(WINDOWS)
    target_compile_options(folly
        PUBLIC
            /W4
            /wd4996  # deprecated functions
    )
endif()
```

---

## 课后作业（增强版）

1. **源码阅读**：
   ```bash
   # 阅读关键文件
   - folly/CMakeLists.txt
   - folly/build/fbcode_builder/projects/folly.py
   - folly/container/F14Map.h
   ```

2. **构建实验**：
   ```bash
   # 1. 使用不同的构建配置
   # 2. 比较构建时间
   # 3. 比较生成的库大小
   ```

3. **性能测试**：
   ```bash
   # 运行基准测试
   # 分析哪些组件性能最优
   ```

---

## 延伸阅读

- **文档**：`docs/Overview.md`
- **构建**：`build/fbcode_builder/README.md`
- **源码**：从 `folly/container/` 开始

---

**第 1 天完（增强版）。明天见！**
