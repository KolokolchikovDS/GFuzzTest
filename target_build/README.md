# FuzzTest — сборка на целевой машине (standalone clang + офлайн)

Самодостаточный набор для сборки `my_fuzz_test` (FuzzTest в режиме совместимости
с libFuzzer + AddressSanitizer) на любой Windows-машине, где есть **Visual Studio
Build Tools / Visual Studio** (C++ workload) и **CMake**.

## Главное: как собирается компилятор

Ваш отдельно скачанный clang (LLVM 22) задаётся **папкой** через `CLANG_DIR`,
и именно он используется для всей сборки.

**Почему используется Ninja, а не Visual Studio генератор?**
Генератор Visual Studio **игнорирует** `-DCMAKE_CXX_COMPILER` и всегда берёт свой
компилятор (`cl.exe` или `-T ClangCL`). Только генераторы Ninja/Makefiles
позволяют подставить произвольный внешний clang-cl. Чтобы «не было ninja на
целевой машине», здесь **поставляется сам `ninja.exe`** (`target_build\bin\ninja.exe`),
а MSVC STL / Windows SDK / `rc.exe` берутся из Visual Studio через `vcvars64.bat`
(сценарий сам находит VS и вызывает её). То есть всё равно нужен Visual Studio
для заголовков и библиотек MSVC STL — но компилирует именно ваш LLVM 22.

## Быстрый старт

```bat
cd D:\GFuzzTest

set "CLANG_DIR=D:\GFuzzTest\llvm-22\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin"
call target_build\configure.bat
call target_build\build.bat
call target_build\run_fuzzer.bat -runs=10000
```

Либо одной командой: `set CLANG_DIR=...` → `call target_build\all.bat`.

## Результат

```
target_build\build\my_fuzz_test.exe
target_build\build\clang_rt.asan_dynamic-x86_64.dll   (копируется POST_BUILD)
```

`clang_rt.asan_dynamic-x86_64.dll` находится автоматически внутри тулчейна
`CLANG_DIR` (каталог `lib\clang\<ver>\lib\windows`) и кладётся рядом с exe.

## Файлы

| Файл | Назначение |
|------|-----------|
| `configure.bat` | Настройка (офлайн-зависимости, standalone clang `CLANG_DIR`, Ninja) |
| `build.bat` | Сборка `my_fuzz_test` |
| `run_fuzzer.bat` | Запуск фаззера (аргументы передаются дальше) |
| `all.bat` | configure + build |
| `configure_vs.bat` | Запасной вариант: VS-генератор + встроенный в VS clang (`-T ClangCL`) |
| `bin\ninja.exe` | Встроенный Ninja (никаких установок не нужно) |
| `third_party\deps\*` | Вендоренные исходники abseil/re2/googletest/ANTLR (офлайн) |
| `third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib` | Предсобранный libFuzzer-рантайм |

## Переменные окружения

| Переменная | По умолчанию | Зачем |
|-----------|-------------|-------|
| `CLANG_DIR` | (обязательная) | Папка с `clang-cl.exe` вашего standalone-тулчейна |
| `CONFIG` | `Release` | Конфигурация |
| `ASAN_OPTIONS` | `detect_odr_violation=0:intercept_strlen=0` | Отключает известные ложные срабатывания ASan (см. ниже) |
| `LIBFUZZER_NO_MAIN_LIBRARY` | `third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib` | Рантайм libFuzzer |

> **Смена компилятора / настройки:** `configure.bat` ставит
> `CMAKE_SUPPRESS_REGENERATION=ON`, чтобы Ninja не крутил бесконечный цикл
> «Re-running CMake» при сборке. Из-за этого после изменения `CMakeLists.txt`
> или смены `CLANG_DIR` нужно **заново выполнить `configure.bat`** (а при смене
> компилятора лучше удалить `target_build\build` и пересобрать начисто).

## Почему эти ASAN_OPTIONS по умолчанию

Связка clang-ASan (динамический рантайм) на Windows + этот набор зависимостей даёт
два ложных срабатывания:

- **`odr-violation`**: глобалы `L"*"` (fuzztest) и `"*"` (googletest) →
  `detect_odr_violation=0`.
- **`global-buffer-overflow` на пустой строке** в `_asan_wrap_strlen` при старте →
  `intercept_strlen=0`.

Эти флаги безопасны и ставятся только если `ASAN_OPTIONS` ещё не задан вручную.

## Изменения относительно оригинального проекта (важно)

- `CMakeLists.txt`: `CMAKE_CXX_STANDARD` **23 → 20**. Причина: CMake 4.x
  эмитит `/std:c++23` для `cxx_std_23`, а **clang-cl 22 не принимает** этот флаг
  и молча откатывается на C++14. Проект и так работает в режиме C++20
  (`/std:c++latest` + `-D_HAS_CXX23=0`), поэтому 20 корректно и безопасно.
- `third_party/deps/abseil-cpp/CMake/AbseilDll.cmake`: проверка стандарта C++
  через `check_cxx_source_compiles` заменена на принудительную установку фичи
  `cxx_std_20` (обход того же бага CMake 4.x + clang-cl: probe компилируется как
  C++14 и ошибочно падает). На проекте это безопасно — компилятор всегда ≥ C++20.

## Диагностика на целевой машине

- **Не найден `CLANG_DIR`** — задайте переменную до запуска `configure.bat`.
- **`__asan_* not found in dll` / краш в `ucrtbase.dll`** — рядом с exe должна
  лежать именно та `clang_rt.asan_dynamic-x86_64.dll`, что из того же `CLANG_DIR`-
  тулчейна; убедитесь, что в System32 / `%PATH%` нет старой копии этой DLL.
- **`vcvars64.bat` не найден** — поставьте C++ workload в Visual Studio.
- Обновите **VC++ Redistributable x64** и Windows Update (актуальный `ucrtbase.dll`).