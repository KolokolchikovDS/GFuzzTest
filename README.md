# GFuzzTest

Примеры фаззинг-тестов на базе Google [FuzzTest](https://google.github.io/fuzztest/) для пользовательских доменов (векторы, собственные структуры через `StructOf`) с логированием входных данных на каждой итерации.

## Сборка

Собирается на **Windows** компилятором **MSVC** в **unit test mode** (обычные `FUZZ_TEST`-свойства, без centipede/libFuzzer).

```sh
cmake -S . -B build
cmake --build build --target my_fuzz_test --config Release
```

Исполняемый файл: `build/Release/my_fuzz_test.exe`.

## Запуск

Фаззинг управляется переменными окружения:

- `FUZZTEST_FUZZ_FOR` — длительность фаззинга (например, `0.2s`).
- `FUZZTEST_PRNG_SEED` — сид генератора (например, `AAAA`).

```sh
$env:FUZZTEST_FUZZ_FOR="0.2s"; $env:FUZZTEST_PRNG_SEED="AAAA"
build\Release\my_fuzz_test.exe --gtest_filter=DotProductSuite.DotProductLogsVaryingInputs
```

Управление работой фаззинг-раннера — в `fuzztest/fuzztest/internal/runtime.cc`.