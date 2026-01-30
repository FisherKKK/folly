# Folly 生产环境代码审查清单

## 概述

本清单提供生产环境中使用 Folly 的最佳实践和检查项，帮助确保代码质量、性能和可维护性。

---

## 🎯 使用前检查

### 1. 组件选择

- [ ] **是否真的需要 Folly 组件？**
  - 标准库是否足够？
  - Folly 组件是否提供明确优势？
  - 团队是否熟悉该组件？

- [ ] **选择了合适的 Folly 变体？**
  - F14FastMap vs F14NodeMap vs F14ValueMap？
  - small_vector 的内联大小是否合适？
  - 是否需要线程安全版本？

- [ ] **评估了依赖成本？**
  - 编译时间影响
  - 二进制大小影响
  - 部署复杂度

---

## 📦 数据结构使用

### F14Map/F14Set

- [ ] **选择了正确的变体**
  - F14FastMap：通用场景
  - F14NodeMap：需要引用稳定
  - F14ValueMap：小对象优化
  - F14VectorMap：大对象优化

- [ ] **正确处理了移动语义**
  ```cpp
  // 好：使用 insert()
  map.insert(std::make_pair(key, value));

  // 避免：不必要的拷贝
  map[key] = value;  // 如果 key 不存在会构造默认值
  ```

- [ ] **利用了异构查找**
  ```cpp
  // 好：直接用字符串字面量查找
  folly::F14FastMap<std::string, int> map;
  map.find("hello");  // 无需构造 std::string

  // 差：不必要的 string 构造
  std::string key = "hello";
  map.find(key);
  ```

- [ ] **考虑了内存占用**
  ```cpp
  // 检查内存使用
  std::cout << "Size: " << map.size() << std::endl;
  std::cout << "Capacity: " << map.bucket_count() << std::endl;
  ```

### small_vector

- [ ] **设置了合理的内联大小**
  ```cpp
  // 好：根据实际使用情况
  folly::small_vector<int, 8> vec;  // 通常 8 个元素

  // 差：过大或过小
  folly::small_vector<int, 1000> vec;  // 浪费栈空间
  folly::small_vector<int, 1> vec;     # 优化效果差
  ```

- [ ] **理解了迭代器失效**
  ```cpp
  folly::small_vector<int, 4> vec = {1, 2, 3};
  auto it = vec.begin();

  vec.push_back(4);  // 可能安全（如果容量未超）
  vec.resize(100);   // it 失效（从栈转移到堆）
  ```

- [ ] **避免存储大对象**
  ```cpp
  // 差：大对象不适合内联
  folly::small_vector<BigData, 4> vec;

  // 好：使用指针或智能指针
  folly::small_vector<std::unique_ptr<BigData>, 4> vec;
  ```

### Arena

- [ ] **正确管理了生命周期**
  ```cpp
  // 好：Arena 在合适的作用域
  {
      folly::SysArena arena;
      // 使用 arena 分配
      void* ptr = arena.allocate(1024);
      // 使用 ptr
  }  // Arena 自动释放

  // 差：悬挂指针
  void* danglingPtr;
  {
      folly::SysArena arena;
      danglingPtr = arena.allocate(1024);
  }  // Arena 释放
  // danglingPtr 现在无效！
  ```

- [ ] **批量使用，避免碎片**
  ```cpp
  // 好：批量分配
  folly::SysArena arena;
  for (int i = 0; i < 1000; ++i) {
      void* ptr = arena.allocate(64);
  }

  // 差：混合使用 Arena 和 malloc
  folly::SysArena arena;
  void* ptr1 = arena.allocate(64);
  void* ptr2 = malloc(64);  // 破坏批量优势
  ```

- [ ] **线程安全考虑**
  ```cpp
  // Arena 不是线程安全的
  folly::SysArena arena;

  // 好：每个线程有自己的 Arena
  thread_local folly::SysArena threadLocalArena;

  // 差：多线程共享 Arena
  // 需要外部同步
  ```

---

## 🔒 并发和同步

### Baton

- [ ] **正确使用了一次性语义**
  ```cpp
  folly::Baton<> baton;

  // 好：一次性同步
  std::thread waiter([&]() {
      baton.wait();  // 等待
  });

  std::thread poster([&]() {
      baton.post();  // 唤醒
  });

  // 差：尝试重复使用
  baton.reset();  // 需要显式重置
  baton.wait();   // 现在可以再次使用
  ```

- [ ] **避免了死锁**
  ```cpp
  // 危险：忘记 post()
  folly::Baton<> baton;
  std::thread t([&]() {
      baton.wait();  // 可能永久等待
  });
  // 如果这里抛出异常，baton.post() 不会执行！
  baton.post();

  // 安全：使用 RAII
  class BatonGuard {
      folly::Baton<>& baton_;
  public:
      ~BatonGuard() { baton_.post(); }
  };
  ```

- [ ] **考虑了超时**
  ```cpp
  // 好：使用超时避免死锁
  if (baton.try_wait_for(std::chrono::seconds(5))) {
      // 成功
  } else {
      // 超时处理
  }
  ```

### AtomicHashMap

- [ ] **理解了 Wait-Free 限制**
  ```cpp
  // Wait-Free：查找
  auto it = map.find(key);  // 不会阻塞

  // 不是 Wait-Free：插入和删除
  map.insert(std::make_pair(key, value));  // 可能 CAS 重试
  ```

- [ ] **预分配了足够空间**
  ```cpp
  // 好：预估大小
  folly::AtomicHashMap<int, int> map(10000);

  // 差：默认大小过小
  folly::AtomicHashMap<int, int> map(10);
  // 插入 1000 个元素时性能会下降
  ```

- [ ] **处理了竞争条件**
  ```cpp
  // 注意：insert 可能失败
  auto result = map.insert(std::make_pair(key, value));
  if (!result.second) {
      // 插入失败，key 已存在
  }
  ```

### Hazard Pointers

- [ ] **正确保护了指针**
  ```cpp
  folly::hazptr_holder<1> holder;
  Node* node = head_.load();

  // 好：先保护再使用
  holder.protect(0, node);
  if (node->data == target) {
      // 安全地使用 node
  }

  // 差：未保护就使用
  Node* node = head_.load();
  if (node->data == target) {  // node 可能已被释放！
  }
  ```

- [ ] **及时退休对象**
  ```cpp
  // 好：使用后立即退休
  holder.retire(oldNode);

  // 差：忘记退休
  delete oldNode;  // 危险！可能被其他线程使用
  ```

---

## ⚡ 异步和事件驱动

### EventBase

- [ ] **每个线程一个 EventBase**
  ```cpp
  // 好：每个 EventBase 在自己的线程
  folly::EventBase evb;
  std::thread t([&]() {
      evb.loopForever();
  });

  // 差：跨线程使用同一个 EventBase
  folly::EventBase evb;
  evb.runInEventBaseThread([]() {
      // 这在 EventBase 线程中执行
  });
  // 不要从多个线程直接调用 EventBase 方法
  ```

- [ ] **正确停止了 EventBase**
  ```cpp
  folly::EventBase evb;
  std::thread t([&]() {
      evb.loopForever();
  });

  // 好：优雅停止
  evb.runInEventBaseThread([&]() {
      evb.terminateLoopSoon();
  });
  t.join();

  // 差：暴力停止
  // t.detach();  // 资源泄漏
  ```

- [ ] **避免在回调中阻塞**
  ```cpp
  // 差：阻塞 EventBase 线程
  evb.runInEventBaseThread([]() {
      std::this_thread::sleep_for(std::chrono::seconds(10));
      // 阻塞了整个 EventBase！
  });

  // 好：使用异步操作
  evb.runInEventBaseThread([]() {
      startAsyncOperation();
  });
  ```

### 协程

- [ ] **正确调度了协程**
  ```cpp
  folly::CPUThreadPoolExecutor executor(4);

  // 好：指定 Executor
  auto future = task().scheduleOn(&executor).start();

  // 差：未指定 Executor
  auto future = task().start();
  // 可能没有执行器可用
  ```

- [ ] **处理了异常**
  ```cpp
  folly::coro::Task<void> taskWithException() {
    try {
        co_await mightThrow();
    } catch (const std::exception& e) {
        // 处理异常
    }
  }

  // 或者
  folly::coro::Task<void> taskWithException() {
        co_await mightThrow();
    }();  // 异常会存储在 Task 中
  }
  ```

- [ ] **避免了死锁**
  ```cpp
  // 危险：循环等待
  folly::coro::Task<void> task1() {
      co_await task2();  // 等待 task2
  }

  folly::coro::Task<void> task2() {
      co_await task1();  // 等待 task1 - 死锁！
  }
  ```

---

## 🎨 性能优化

### 分支预测

- [ ] **正确使用了 FOLLY_LIKELY/UNLIKELY**
  ```cpp
  // 好：标记常见路径
  if (FOLLY_LIKELY(success)) {
      // 快速路径
  } else {
      // 错误处理（不常见）
  }

  // 差：滥用
  if (FOLLY_UNLIKELY(x > 0)) {
      // 分支预测失败率并不高
  }
  ```

- [ ] **测量了实际效果**
  ```bash
  # 使用 perf 分析分支预测
  perf record -e branches,branch-misses ./program
  perf report
  ```

### 内存对齐

- [ ] **避免了伪共享**
  ```cpp
  // 好：使用 padding
  struct Counter {
      std::atomic<int> value;
      char padding[folly::hardware_destructive_interference_size];
  };

  // 差：紧凑布局导致伪共享
  struct BadCounter {
      std::atomic<int> value1;
      std::atomic<int> value2;  // 可能在同一缓存行
  };
  ```

- [ ] **使用了缓存友好的数据布局**
  ```cpp
  // 好：SOA（Structure of Arrays）
  struct Particles {
      std::vector<float> x, y, z;
      std::vector<float> vx, vy, vz;
  };

  // 差：AOS（Array of Structures）
  struct Particle {
      float x, y, z, vx, vy, vz;
  };
  std::vector<Particle> particles;
  ```

### 内存分配

- [ ] **减少了不必要的分配**
  ```cpp
  // 好：预留空间
  std::vector<int> vec;
  vec.reserve(1000);

  // 差：多次重新分配
  std::vector<int> vec;
  for (int i = 0; i < 1000; ++i) {
      vec.push_back(i);  // 可能多次重新分配
  }
  ```

- [ ] **使用了对象池**
  ```cpp
  // 好：复用对象
  class ObjectPool {
      std::vector<std::unique_ptr<MyObject>> pool_;

  public:
      MyObject* acquire() {
          if (!pool_.empty()) {
              auto obj = pool_.back().release();
              pool_.pop_back();
              return obj;
          }
          return new MyObject();
      }

      void release(MyObject* obj) {
          pool_.push_back(std::unique_ptr<MyObject>(obj));
      }
  };
  ```

---

## 🔍 错误处理

### 异常安全

- [ ] **提供了基本异常保证**
  ```cpp
  // 好：使用 RAII
  class ResourceManager {
      std::unique_ptr<Resource> resource_;
  public:
      void useResource() {
          // 即使抛出异常，resource 也会被正确释放
      }
  };

  // 差：手动管理
  class BadResourceManager {
      Resource* resource_;
  public:
      ~BadResourceManager() {
          delete resource_;  // 如果构造抛出异常？
      }
  };
  ```

- [ ] **正确处理了 Folly 异常**
  ```cpp
  #include <folly/Exception.h>

  try {
      // Folly 操作
  } catch (const std::exception& e) {
      LOG(ERROR) << "Folly exception: " << e.what();
  }
  ```

### 边界条件

- [ ] **处理了空容器**
  ```cpp
  folly::F14FastMap<int, int> map;

  // 好：检查空
  if (map.empty()) {
      // 处理空情况
  }

  // 差：假设非空
  auto& first = map.begin()->second;  // 未定义行为！
  ```

- [ ] **验证了输入**
  ```cpp
  // 好：验证输入
  void processInput(const std::string& input) {
      if (input.empty()) {
          throw std::invalid_argument("Input cannot be empty");
      }
      // 处理输入
  }

  // 差：假设输入有效
  void processInput(const std::string& input) {
      char first = input[0];  // 可能为空！
  }
  ```

---

## 📊 性能测试

### 基准测试

- [ ] **编写了微基准测试**
  ```cpp
  BENCHMARK(MyFunction, iters) {
      for (size_t i = 0; i < iters; ++i) {
          doSomething(i);
      }
  }

  BENCHMARK_DRAW_LINE();
  ```

- [ ] **对比了标准库**
  ```cpp
  BENCHMARK(FollyVersion, iters) {
      folly::F14FastMap<int, int> map;
      for (size_t i = 0; i < iters; ++i) {
          map.insert(std::make_pair(i, i));
      }
  }

  BENCHMARK(STDVersion, iters) {
      std::unordered_map<int, int> map;
      for (size_t i = 0; i < iters; ++i) {
          map.insert(std::make_pair(i, i));
      }
  }
  ```

### 性能分析

- [ ] **使用了性能分析工具**
  ```bash
  # CPU 性能分析
  perf record ./program
  perf report

  # 缓存分析
  valgrind --tool=cachegrind ./program
  cg_annotate cachegrind.out.<pid>
  ```

- [ ] **识别了热点**
  ```bash
  # 生成火焰图
  perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
  ```

---

## 🧪 测试

### 单元测试

- [ ] **编写了单元测试**
  ```cpp
  #include <folly/portability/GTest.h>

  TEST(MyTest, BasicOperation) {
      folly::F14FastMap<int, int> map;
      map.insert(std::make_pair(1, 100));

      EXPECT_EQ(map[1], 100);
      EXPECT_EQ(map.size(), 1);
  }
  ```

- [ ] **测试了边界条件**
  ```cpp
  TEST(MyTest, EmptyContainer) {
      folly::F14FastMap<int, int> map;
      EXPECT_TRUE(map.empty());
      EXPECT_EQ(map.size(), 0);
  }

  TEST(MyTest, LargeSize) {
      folly::F14FastMap<int, int> map;
      for (int i = 0; i < 1000000; ++i) {
          map.insert(std::make_pair(i, i));
      }
      EXPECT_EQ(map.size(), 1000000);
  }
  ```

### 并发测试

- [ ] **测试了并发访问**
  ```cpp
  TEST(ConcurrentTest, MultiThreadedAccess) {
      folly::AtomicHashMap<int, int> map(1000);

      std::vector<std::thread> threads;
      for (int i = 0; i < 10; ++i) {
          threads.emplace_back([&map, i]() {
              for (int j = 0; j < 100; ++j) {
                  map.insert(std::make_pair(i * 100 + j, j));
              }
          });
      }

      for (auto& t : threads) {
          t.join();
      }

      EXPECT_EQ(map.size(), 1000);
  }
  ```

---

## 📝 文档

### 代码注释

- [ ] **注释了复杂逻辑**
  ```cpp
  // 使用 F14ValueMap 因为我们存储的是小对象（< 24 字节）
  // 这避免了额外的堆分配，提升性能约 30%
  folly::F14ValueMap<SmallKey, SmallValue> map;
  ```

- [ ] **记录了性能特征**
  ```cpp
  // 注意：此操作是 O(n)，不适用于大容器
  // 考虑使用 F14FastMap 进行 O(1) 查找
  ```

### README 和示例

- [ ] **提供了使用示例**
  ```cpp
  /// 示例：
  ///   folly::F14FastMap<int, std::string> map;
  ///   map.insert(std::make_pair(1, "hello"));
  ///   auto it = map.find(1);
  class MyClass {
      // ...
  };
  ```

---

## 🔧 编译和部署

### 编译选项

- [ ] **使用了正确的优化级别**
  ```bash
  # Release 构建
  g++ -std=c++17 -O3 -march=native \
      -DNDEBUG \
      -lfolly \
      myapp.cpp -o myapp
  ```

- [ ] **启用了必要的 Folly 特性**
  ```cpp
  // 定义必要的宏
  #define FOLLY_NEED_VOICE_KERNEL_CONFIG_H 1
  ```

### 依赖管理

- [ ] **正确处理了 Folly 依赖**
  ```cmake
  find_package(folly REQUIRED)

  target_link_libraries(myapp PRIVATE folly)
  ```

- [ ] **版本兼容性检查**
  ```cpp
  #if FOLLY_VERSION < 20240000
      #error "Folly version too old"
  #endif
  ```

---

## 🚀 部署清单

- [ ] 所有测试通过
- [ ] 性能基准达标
- [ ] 内存泄漏检查通过（valgrind）
- [ ] 线程安全验证
- [ ] 文档完整
- [ ] 错误处理完善
- [ ] 日志和监控就绪

---

## 📋 代码审查模板

使用此模板进行代码审查：

```markdown
## 组件使用

- [ ] Folly 组件选择合理
- [ ] 使用了正确的变体
- [ ] 理解了组件的限制

## 正确性

- [ ] 无内存泄漏
- [ ] 无数据竞争
- [ ] 异常安全
- [ ] 边界条件处理

## 性能

- [ ] 编写了基准测试
- [ ] 性能分析完成
- [ ] 热点优化
- [ ] 内存使用合理

## 可维护性

- [ ] 代码注释清晰
- [ ] 文档完整
- [ ] 测试覆盖充分
- [ ] 日志合理

## 部署

- [ ] 编译配置正确
- [ ] 依赖管理清晰
- [ ] 监控就绪
- [ ] 回滚计划
```

---

**记住**：过早优化是万恶之源。在应用高级 Folly 特性之前，确保：
1. 代码正确且可维护
2. 有性能测试证明需要优化
3. 理解所使用的 Folly 组件的行为

**Happy Coding with Folly!** 🚀
