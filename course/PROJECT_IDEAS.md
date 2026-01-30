# Folly 实战项目 ideas

## 概述

本指南提供一系列实战项目，帮助你将 Folly 知识应用到实际场景中。项目按难度分类，从简单到复杂，涵盖 Folly 的各个方面。

---

## 📊 项目难度

- ⭐ 简单：适合初学者，1-2 天完成
- ⭐⭐ 中等：需要一定经验，3-5 天完成
- ⭐⭐⭐ 困难：需要深入理解，1-2 周完成
- ⭐⭐⭐⭐ 挑战：综合项目，2-4 周完成

---

## 🎯 推荐路径

1. **初学者**：项目 1-3 → 项目 7-9
2. **进阶者**：项目 4-6 → 项目 10-12
3. **高级者**：项目 13-15

---

## 📚 基础项目

### 项目 1: 高性能日志收集器 ⭐

**目标**: 使用 Folly 组件构建一个高效的日志收集系统

**使用组件**:
- `folly::small_vector` - 减少小日志的内存分配
- `folly::ProducerConsumerQueue` - 无锁队列
- `folly::Synchronized` - 线程安全的日志缓冲区

**功能要求**:
1. 支持多线程写入日志
2. 缓冲日志批量写入文件
3. 支持日志级别过滤
4. 提供日志轮转功能

**技术要点**:
```cpp
// 使用 small_vector 减少内存分配
folly::small_vector<char, 256> buffer;
buffer.append(log_message.begin(), log_message.end());

// 使用无锁队列
folly::ProducerConsumerQueue<LogEntry> queue(1024);
queue.write(entry);

// 线程安全的日志缓冲区
folly::Synchronized<std::vector<LogEntry>> buffer;
buffer.withWLock([&](auto& buf) {
    buf.push_back(entry);
});
```

**性能目标**:
- 支持 100K 条/秒的日志写入
- 内存分配次数 < 10% 的日志条数

---

### 项目 2: 内存缓存系统 ⭐

**目标**: 实现一个高效的内存缓存，使用 Folly 的哈希表

**使用组件**:
- `folly::F14FastMap` - 高性能哈希表
- `folly::Synchronized` - 线程安全
- `folly::Arena` - 批量内存分配

**功能要求**:
1. 支持 Get/Put/Delete 操作
2. LRU 淘汰策略
3. 线程安全
4. 统计命中率

**技术要点**:
```cpp
class MemoryCache {
    folly::F14FastMap<std::string, CacheEntry> cache_;
    folly::Synchronized<LRUList> lru_list_;

    folly::Arena arena_;  // 用于批量分配

public:
    void put(std::string key, std::string value) {
        // 使用 Arena 分配
        auto* key_ptr = allocateInArena(key);
        auto* value_ptr = allocateInArena(value);

        cache_[*key_ptr] = {*value_ptr, std::chrono::system_clock::now()};
    }
};
```

**性能目标**:
- Get 操作 < 100ns (命中)
- 支持 1M keys
- 命中率 > 95%

---

### 项目 3: 异步 HTTP 服务器 ⭐⭐

**目标**: 使用 EventBase 构建简单的 HTTP 服务器

**使用组件**:
- `folly::EventBase` - 事件循环
- `folly::AsyncSocket` - 异步 Socket
- `folly::IOThreadPoolExecutor` - I/O 线程池

**功能要求**:
1. 处理 HTTP GET 请求
2. 支持 HTTP/1.1 持久连接
3. 返回静态文件
4. 支持并发连接

**技术要点**:
```cpp
class HTTPServer {
    folly::EventBase evb_;
    folly::AsyncSocket::UniquePtr socket_;

public:
    void start(int port) {
        // 监听端口
        auto serverSocket = folly::AsyncServerSocket::newSocket(&evb_);
        serverSocket->bind(port);
        serverSocket->listen(1024);
        serverSocket->startAccepting();

        // 启动事件循环
        evb_.loopForever();
    }
};
```

**性能目标**:
- 支持 10K 并发连接
- QPS > 50K (简单响应)
- 延迟 P99 < 1ms

---

## 🚀 进阶项目

### 项目 4: 分布式任务队列 ⭐⭐

**目标**: 构建一个分布式任务调度系统

**使用组件**:
- `folly::Executor` - 任务执行器
- `folly::CPUThreadPoolExecutor` - CPU 线程池
- `folly::futures::Future` - 异步任务链
- `folly::coro::Task` - 协程任务

**功能要求**:
1. 提交任务到队列
2. Worker 消费任务
3. 任务超时处理
4. 任务优先级
5. 任务结果回调

**技术要点**:
```cpp
class TaskQueue {
    folly::CPUThreadPoolExecutor executor_;
    folly::F14FastMap<TaskID, folly::SemiFuture<Result>> futures_;

public:
    folly::SemiFuture<Result> submit(Task task) {
        return folly::makeSemiFuture()
            .via(&executor_)
            .thenValue([task](auto&&) {
                return execute(task);
            });
    }
};

// 使用协程
folly::coro::Task<Result> processTask(Task task) {
    auto data = co_await fetchData(task.id);
    auto result = co_await compute(data);
    co_return result;
}
```

**性能目标**:
- 支持 100K 任务/秒
- 任务延迟 P99 < 10ms
- CPU 利用率 > 80%

---

### 项目 5: 实时数据流处理 ⭐⭐⭐

**目标**: 构建流式数据处理管道

**使用组件**:
- `folly::coro::AsyncGenerator` - 异步生成器
- `folly::IOThreadPoolExecutor` - I/O 线程池
- `folly::AtomicHashMap` - 快速查找

**功能要求**:
1. 实时数据摄入
2. 流式数据处理
3. 窗口聚合
4. 实时统计

**技术要点**:
```cpp
folly::coro::Task<void> processStream() {
    auto stream = co_await readStream();

    folly::AtomicHashMap<Key, Stats> stats(1000);

    for (auto&& item : stream) {
        auto it = stats.find(item.key);
        if (it != stats.end()) {
            it->second.count++;
            it->second.sum += item.value;
        } else {
            stats.insert(item.key, {1, item.value});
        }
    }
}
```

**性能目标**:
- 处理 1M 事件/秒
- 端到端延迟 < 100ms
- 内存占用 < 1GB

---

### 项目 6: 高性能 JSON 解析器 ⭐⭐⭐

**目标**: 使用 Folly 优化 JSON 解析

**使用组件**:
- `folly::StringPiece` - 零拷贝字符串视图
- `folly::small_vector` - 小数组优化
- `folly::F14FastMap` - 对象属性存储

**功能要求**:
1. 解析 JSON 字符串
2. 支持对象、数组、基本类型
3. 提供 DOM 风格 API
4. 支持序列化

**技术要点**:
```cpp
class JSONParser {
    folly::StringPiece input_;

    folly::StringPiece parseString() {
        // 使用 StringPiece 避免拷贝
        size_t start = input_.find('"');
        size_t end = input_.find('"', start + 1);
        return input_.subpiece(start, end - start + 1);
    }

    folly::F14FastMap<std::string, JSONValue> parseObject() {
        folly::F14FastMap<std::string, JSONValue> obj;
        // 解析键值对
        return obj;
    }
};
```

**性能目标**:
- 解析速度 > 100 MB/s
- 内存分配 < 解析大小的 50%
- 比 rapidjson 快 20%

---

## 🔥 高级项目

### 项目 7: 分布式键值存储 ⭐⭐⭐⭐

**目标**: 实现一个分布式 KV 存储

**使用组件**:
- `folly::EventBase` - 网络事件循环
- `folly::AsyncSocket` - 异步网络通信
- `folly::F14FastMap` - 本地存储
- `folly::Baton` - 同步原语
- `folly::Hazptr` - 无锁内存回收

**功能要求**:
1. Put/Get/Delete 操作
2. 数据分片 (Sharding)
3. 副本复制 (Replication)
4. 一致性哈希
5. 故障转移

**技术要点**:
```cpp
class DistributedKV {
    folly::F14FastMap<ShardID, folly::Synchronized<Node>> shards_;
    folly::EventBase evb_;

public:
    folly::Future<Value> Get(Key key) {
        ShardID shard = consistentHash(key);
        return shards_[shard].withRLock([&](auto& node) {
            return node.GetAsync(key);
        });
    }
};
```

**性能目标**:
- 支持 1M ops/sec
- 延迟 P99 < 5ms
- 可用性 99.9%

---

### 项目 8: RPC 框架 ⭐⭐⭐⭐

**目标**: 基于 Folly 构建 RPC 框架

**使用组件**:
- `folly::EventBase` - 事件循环
- `folly::AsyncSocket` - 异步 Socket
- `folly::coro::Task` - 协程
- `folly::dynamic` - 动态类型

**功能要求**:
1. 服务定义和生成
2. 序列化/反序列化
3. 异步调用
4. 负载均衡
5. 服务发现

**技术要点**:
```cpp
// 服务定义
class UserService {
public:
    virtual folly::coro::Task<User> GetUser(int64_t id) = 0;
    virtual folly::coro::Task<std::vector<User>> ListUsers() = 0;
};

// 服务端实现
class UserServiceImpl : public UserService {
public:
    folly::coro::Task<User> GetUser(int64_t id) override {
        co_return co_await db_.GetUser(id);
    }
};

// 客户端调用
folly::coro::Task<void> callRPC() {
    auto user = co_await client_->GetUser(123);
    std::cout << user.name << std::endl;
}
```

**性能目标**:
- QPS > 100K
- 延迟 P99 < 2ms
- 支持 10K 连接

---

### 项目 9: 内存数据库 ⭐⭐⭐⭐

**目标**: 实现内存数据库

**使用组件**:
- `folly::F14FastMap` - 主索引
- `folly::Arena` - 内存管理
- `folly::AtomicHashMap` - 并发索引
- `folly::Baton` - 同步点

**功能要求**:
1. 表结构定义
2. 插入/更新/删除
3. 主键索引
4. 二级索引
5. 事务支持（基本）

**技术要点**:
```cpp
class Table {
    folly::F14FastMap<int64_t, Row> primary_key_;
    folly::AtomicHashMap<std::string, int64_t*> secondary_index_;

    folly::SysArena arena_;

public:
    void Insert(Row row) {
        // 在 Arena 中分配
        auto* row_ptr = allocateInArena(row);

        // 更新索引
        primary_key_[row.id] = *row_ptr;
        secondary_index_.insert(row.name, &row_ptr->id);
    }
};
```

**性能目标**:
- 支持 100M rows
- 查询 < 1μs
- 插入 > 500K ops/sec

---

## 🎨 特定领域项目

### 项目 10: 日志分析引擎 ⭐⭐

**目标**: 实时日志分析和搜索

**使用组件**:
- `folly::ProducerConsumerQueue` - 日志队列
- `folly::StringPiece` - 零拷贝字符串
- `folly::F14FastMap` - 索引

**功能要求**:
1. 日志摄入
2. 全文索引
3. 搜索查询
4. 聚合统计

---

### 项目 11: 游戏服务器 ⭐⭐⭐

**目标**: 在线游戏后端

**使用组件**:
- `folly::EventBase` - 事件循环
- `folly::Baton` - 玩家同步
- `folly::F14FastMap` - 游戏状态

**功能要求**:
1. 玩家连接管理
2. 实时状态同步
3. 游戏逻辑处理
4. 房间管理

---

### 项目 12: 时间序列数据库 ⭐⭐⭐

**目标**: 存储和查询时序数据

**使用组件**:
- `folly::small_vector` - 压缩数据点
- `folly::F14FastMap` - 标签索引
- `folly::Arena` - 批量分配

**功能要求**:
1. 数据写入
2. 范围查询
3. 聚合计算
4. 降采样

---

## 📝 学习建议

### 项目选择

1. **初学者**: 从项目 1-3 开始
   - 日志收集器 - 熟悉基本组件
   - 内存缓存 - 掌握哈希表
   - HTTP 服务器 - 理解事件驱动

2. **进阶者**: 尝试项目 4-6
   - 任务队列 - 学习异步编程
   - 流处理 - 掌握协程
   - JSON 解析 - 性能优化

3. **高级者**: 挑战项目 7-9
   - 分布式 KV - 综合应用
   - RPC 框架 - 网络编程
   - 内存数据库 - 系统设计

### 开发流程

1. **设计阶段** (1 天)
   - 明确功能需求
   - 选择合适的 Folly 组件
   - 设计数据结构

2. **原型开发** (2-3 天)
   - 实现核心功能
   - 基本测试

3. **性能优化** (2-3 天)
   - 使用 folly::Benchmark 测试
   - perf 分析热点
   - 优化瓶颈

4. **完善功能** (2-3 天)
   - 错误处理
   - 边界条件
   - 文档编写

### 评估标准

每个项目完成后，检查：

- [ ] 功能完整性
- [ ] 性能达标
- [ ] 代码质量
- [ ] 测试覆盖
- [ ] 文档完整

---

## 🔗 相关资源

- **Folly 文档**: https://facebook.github.io/folly/
- **Folly 源码**: https://github.com/facebook/folly
- **课程内容**: 参见 Day14 综合项目

---

**开始你的 Folly 实战之旅吧！** 🚀
