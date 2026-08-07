# GFuzzTest

Примеры фаззинг-тестов на базе Google [FuzzTest](https://google.github.io/fuzztest/) для пользовательских доменов (векторы, собственные структуры через `StructOf`) с логированием входных данных на каждой итерации.

## Сборка

Собирается на **Windows** двумя способами: **MSVC** в *unit test mode* (обычные `FUZZ_TEST`-свойства, без centipede/libFuzzer) и **Clang (clang-cl)** в *compatibility mode* (FuzzTest + **libFuzzer** + AddressSanitizer). Обе сборки используют **C++23** и динамический CRT **`/MD`**.

### 1. MSVC / unit test mode

```sh
cmake -S . -B build
cmake --build build --target my_fuzz_test --config Release
```

Исполняемый файл: `build/Release/my_fuzz_test.exe`.

### 2. Clang (clang-cl) / libFuzzer compatibility mode, **dynamic CRT `/MD`**

FuzzTest работает как драйвер поверх libFuzzer. Используется **LLVM 22.1.8** (последний стабильный), потому что его динамический ASan-рантайм работает на Windows, а у Clang 19 из VS2022 dynamic ASan падает на старте (`interception_win: unhandled instruction`). STL — от VS 2022.

Эталонные артефакты уже собраны:
- `dist/lib/` — все собранные статические библиотеки (`/MD`): FuzzTest, abseil, googletest, re2 и рантайм libFuzzer `clang_rt.fuzzer_no_main-md-x86_64.lib`.
- `dist/bin/my_fuzz_test.exe` + `clang_rt.asan_dynamic-x86_64.dll`.
- Исходники libFuzzer — в `third_party/libfuzzer/` (LLVM 22.1.8, пропатчены небезопасные `strstr`/`strcmp`-хуки).

#### Шаг 1. Сборка рантайма libFuzzer с `/MD`

```sh
# LLVM 22 bin и каталог rc.exe Windows Kits должны быть в PATH
set PATH=D:\GFuzzTest\llvm-22\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin;%PATH%
cmake -S third_party/libfuzzer -B build-libfuzzer-md -G Ninja -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_BUILD_TYPE=Release
cmake --build build-libfuzzer-md -j 8
# -> build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib
```

#### Шаг 2. Сборка FuzzTest (`/MD`)

```sh
# из VS2022 x64 Developer PowerShell, LLVM 22 bin и rc.exe в PATH
cmake -S . -B build-clang-md -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE=clang-cl-libfuzzer-toolchain.cmake `
  -DFUZZTEST_COMPATIBILITY_MODE=libfuzzer `
  -DLIBFUZZER_NO_MAIN_LIBRARY=D:/GFuzzTest/build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib `
  -DCMAKE_BUILD_TYPE=RelWithDebInfo

cmake --build build-clang-md --target my_fuzz_test -j 8
```

Исполняемый файл: `build-clang-md/my_fuzz_test.exe` (рядом копируется `clang_rt.asan_dynamic-x86_64.dll`).

> `clang-cl-libfuzzer-toolchain.cmake` использует `/MD` (динамический CRT), связывает динамический ASan-рантайм из LLVM 22 и рантайм libFuzzer, пересобранный с `/MD`. `third_party/libfuzzer/CMakeLists.txt` собирает libFuzzer с `/MD` и содержит пропатченные небезопасные weak-хуки (`strstr`/`strcmp`), которые на Windows делали `strlen` по не-NUL-terminated буферам и давали ложные ASan `global-buffer-overflow`.

> **C++23:** обе сборки используют `CMAKE_CXX_STANDARD 23` (`/std:c++latest`). MSVC 14.38 в этом режиме даёт C++20 (`_HAS_CXX23=0`); для clang-cl 22 аналогично принудительно задаётся `-D_HAS_CXX23=0`, чтобы MSVC STL не включал недоступные clang-cl 22 пути C++23.

## Упаковка (package: include + lib)

Для обоих режимов собраны самодостаточные пакеты «заголовки + консолидированная статическая библиотека» (один `fuzztest.lib`, склеенный из всех отдельных либов через `lib.exe`):

- `package/msvc/fuzztest/` — сборка **MSVC / unit test mode** (C++23, `/MD`): `include/`, `lib/Debug/fuzztest.lib`, `lib/Release/fuzztest.lib`.
- `package/clang/fuzztest/` — сборка **clang-cl / libFuzzer compatibility mode** (C++23, `/MD`): `include/`, `lib/Debug/fuzztest.lib`, `lib/Release/fuzztest.lib` (с ASan/libFuzzer-инструментацией; `lib/Release` — сборка RelWithDebInfo, как исходно).

Проверка работоспособности пакетов в тестовых проектах (`tests.cpp` линкуется только против пакета — без `fuzztest/` и `_deps/`):

```sh
# MSVC-пакет
cmake -S verify-pkg -B verify-pkg/build3 -G "Visual Studio 17 2022" -A x64 -DCMAKE_CXX_STANDARD=23
cmake --build verify-pkg/build3 --config Release
verify-pkg\build3\Release\verify_tests.exe

# clang-пакет (LLVM 22 bin + vcvars64 в PATH)
cmake -S verify-pkg-clang -B verify-pkg-clang/build -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE=clang-cl-libfuzzer-toolchain.cmake `
  -DLIBFUZZER_NO_MAIN_LIBRARY=D:/GFuzzTest/build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib
cmake --build verify-pkg-clang/build -j 8
verify-pkg-clang\build\verify_tests.exe --gtest_filter=UnstableApi.ParseReproducerValueInstantiates
```

## Запуск

### Unit test mode (MSVC)

Фаззинг управляется переменными окружения:

- `FUZZTEST_FUZZ_FOR` — длительность фаззинга (например, `0.2s`).
- `FUZZTEST_PRNG_SEED` — сид генератора (например, `AAAA`).

```sh
$env:FUZZTEST_FUZZ_FOR="0.2s"; $env:FUZZTEST_PRNG_SEED="AAAA"
build\Release\my_fuzz_test.exe --gtest_filter=DotProductSuite.DotProductLogsVaryingInputs
```

Управление работой фаззинг-раннера — в `fuzztest/fuzztest/internal/runtime.cc`.

### Compatibility mode (clang-cl + libFuzzer)

Фаззинг запускается через `--fuzz=<Suite>.<Test>`; параметры libFuzzer передаются после `--`. Без ограничений фаззинг идёт бесконечно, поэтому задайте `-runs` или `-max_total_time`.

```sh
# найти контрпример в намеренно падающем свойстве
build-clang-md\my_fuzz_test.exe --fuzz=DotProductSuite.DotProductNeverNegative -- -runs=1000

# прогон без падений, ограниченный по времени
build-clang-md\my_fuzz_test.exe --fuzz=ArbitrarySuite.IntDoesNotCrash -- -max_total_time=30
```

Обычные unit-тесты (`TEST`) работают как обычно, например:

```sh
build-clang-md\my_fuzz_test.exe --gtest_filter=UnstableApi.ParseReproducerValueInstantiates
```

> `gtest_discover_tests` регистрирует `FUZZ_TEST`-ы как обычные тесты, поэтому `ctest` будет запускать их и фаззить без лимита — для bounded-прогонов используйте флаги libFuzzer, как выше.
