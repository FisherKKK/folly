# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Folly (Facebook Open-source Library) is a collection of C++20 components designed with practicality and efficiency in mind. It contains core library components used extensively at Facebook as dependencies for other open source C++ efforts.

**Key architectural principles:**
- Flat namespace structure - components are in `folly/` directory matching the namespace structure
- No internal dependency restrictions - folly modules may use any other folly components
- Performance-focused designs that may seem idiosyncratic compared to standard libraries
- Complements (rather than competes with) Boost and std - only embarks on new components when existing options don't meet performance needs

## Build System

### Primary Build Method: getdeps.py

The recommended way to build folly is using the `getdeps.py` script, which handles dependency management automatically:

```bash
# Build (using system dependencies if available)
python3 ./build/fbcode_builder/getdeps.py --allow-system-packages build

# Run tests
python3 ./build/fbcode_builder/getdeps.py --allow-system-packages test

# Install system dependencies (Linux/macOS)
sudo ./build/fbcode_builder/getdeps.py install-system-deps --recursive

# Show build/install directories
python3 ./build/fbcode_builder/getdeps.py show-build-dir
python3 ./build/fbcode_builder/getdeps.py show-inst-dir
```

The `build.sh` script (Linux/macOS) and `build.bat` (Windows) are wrappers around `getdeps.py`.

### Alternative: Direct CMake

When building with CMake directly, you must manually manage dependencies:

```bash
mkdir _build && cd _build
cmake .. -DBUILD_TESTS=ON
make
```

**Important:** Folly provides no ABI compatibility guarantees between commits. Always build as a static library.

### Running Individual Tests

With CMake builds (after `-DBUILD_TESTS=ON`):
```bash
# Run all tests
ctest

# Run specific test
./folly/test/container/test/container_fbvector_test
```

With getdeps.py builds, use the helper script in the build directory:
```bash
cd $(python3 ./build/fbcode_builder/getdeps.py show-build-dir)
ctest
```

## Architecture

### Granular Library Structure

Folly uses a modular CMake build system with ~108 granular libraries defined in `folly/CMakeLists.txt`. Each component is defined using `folly_add_library()` with:
- `NAME`: Library name
- `HEADERS`: Public headers
- `SRCS`: Source files
- `EXPORTED_DEPS`: Internal folly dependencies
- `EXTERNAL_DEPS`: Third-party dependencies (Boost, glog, etc.)

**Key build concepts:**
- Sources compiled ONCE via OBJECT libraries, then reused for both granular `.a` files and monolithic `libfolly.a`
- Each subdirectory has its own `CMakeLists.txt` defining its targets
- `EXCLUDE_FROM_MONOLITH` excludes targets from the main libfolly.a (used for benchmarks, test utilities)

### Major Component Areas

- **`folly/io/async/`** - Async I/O framework built on libevent
  - `EventBase` - Main event loop (one per thread typically)
  - `AsyncSocket`/`AsyncSSLSocket` - Non-blocking socket implementations
  - `HHWheelTimer` - O(1) timer implementation
  - `DelayedDestruction` - Safe destruction patterns for callback-heavy code
  - See `folly/io/async/README.md` for detailed design

- **`folly/futures/`** - Future/Promise framework for async code
  - `Future`/`SemiFuture` - Composable async operations
  - `Executor` abstractions for execution contexts

- **`folly/coro/`** - C++20 coroutines framework
  - `Task<T>` - Coroutine tasks that integrate with Future/SemiFuture
  - `co_await` compatible with folly::Future and other awaitables
  - `collectAll()` for concurrent coroutine execution
  - See `folly/coro/README.md` for usage patterns

- **`folly/container/`** - High-performance containers
  - `F14Map`/`F14Set` - Optimized hash maps/sets
  - `small_vector` - Vector with small-buffer optimization

- **`folly/synchronization/`** - Concurrent data structures and primitives
  - `AtomicHashMap` - Lock-free concurrent hash map
  - `Baton` - Single handoff synchronization primitive
  - `hazptr` - Hazard pointers for safe lock-free reclamation

- **`folly/executors/`** - Thread pool and executor implementations

- **`folly/memory/`** - Memory allocation utilities (Arena, etc.)

- **`folly/logging/`** - Structured logging framework
  - See `folly/logging/README.md` and documentation in `folly/logging/docs/`

### Test Structure

Tests are organized by component:
- Test files: `folly/**/test/*Test.cpp`
- Test utilities: `folly/test/` (shared testing infrastructure)
- Mock/test helpers: `folly/**/test/Mock*.h`, `folly/**/test/*Test.h`

Test definitions in main `CMakeLists.txt` use `folly_define_tests()` with patterns like:
```
TEST <name> [WINDOWS_DISABLED] [APPLE_DISABLED] [BROKEN] [SLOW] [HANGING]
  SOURCES <files>
  HEADERS <headers>
  CONTENT_DIR <content_dirs>
```

## Coding Guidelines

### Namespace and Symbol Conventions
- Define symbols in namespace `folly` (except macros)
- Prefix macros with `FOLLY_`
- Prefix C symbols with `folly_`
- Library-private symbols go in `folly::detail` or `folly::<component>::detail`

### Portability Requirements
- Use `throw_exception` from `folly/lang/Exception.h` instead of `throw`
- Be portable across Linux (x86-64, ARM), macOS, iOS, Windows
- Follow existing patterns when working with platform-specific code

### Drop-in Replacements
When improving upon standard/Boost libraries:
- Maintain the same APIs
- Provide the same guarantees
- Use the same naming conventions (e.g., `snake_case` for std-like APIs)

### Documentation Style
- Follow [Google Developer Documentation Style Guide](https://developers.google.com/style)
- Use American English, second person ("you"), active voice
- Document non-obvious APIs and complex tradeoffs

## Development Workflow

### Making Changes
1. Folly is header-only for many components - check both `.h` and `.cpp` files
2. Changes to internal APIs (detail namespace) still require updating tests
3. Test changes affect downstream Facebook projects - consider compatibility

### Performance Focus
- Performance is the primary reason for Folly's existence
- Benchmark before and after optimizations using `folly/Benchmark.h`
- Consider both latency (P99) and throughput

### Common Patterns
- **Event-driven architecture**: `EventBase` loop with `runInEventBaseThread()` for cross-thread work
- **DelayedDestruction**: Used throughout async code for safe object lifecycle management
- **Scope guards**: `SCOPE_EXIT` for cleanup (from `folly/ScopeGuard.h`)
- **Try wrappers**: `folly::Try<T>` for error handling in async code
- **Optional/Expected**: Prefer `folly::Optional<T>` and `folly::Expected<T, E>` for error handling

## Key Files to Reference

- `folly/docs/Overview.md` - Component descriptions
- `folly/docs/*.md` - Detailed documentation for specific components
- `CONTRIBUTING.md` - Contribution guidelines
- `folly/CODING_GUIDELINES.md` - Detailed coding standards
- Component READMEs in `folly/*/README.md` for major subsystems
