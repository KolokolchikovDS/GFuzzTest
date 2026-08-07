cmake_minimum_required(VERSION 3.19)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

project(GTEST_FUZZING CXX)

set(ABSL_PROPAGATE_CXX_STD ON CACHE BOOL "" FORCE)

set(CMAKE_TLS_VERIFY 0)
set(WITH_STATIC_CRT OFF CACHE BOOL "Disable static CRT for ANTLR4" FORCE)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(/clang:-Wno-error /clang:-Wno-deprecated-declarations)
endif()

add_compile_options(/wd4267 /wd4244 /wd4100 /wd4996 /wd4324 /wd4127)
add_compile_options(/WX-)

# MSVC 14.38 (and clang-cl) only expose C++23 via /std:c++latest. Force it
# globally (also as a cache CMAKE_CXX_FLAGS so Abseil's configure-time standard
# detection sees C++20 and does not pin cxx_std_17).
if(MSVC OR (WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
  add_compile_options(/std:c++latest)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest" CACHE STRING "CXX flags" FORCE)
endif()

add_subdirectory(fuzztest)

enable_testing()
include(GoogleTest)

fuzztest_setup_fuzzing_flags()

add_executable(my_fuzz_test main.cpp)

target_compile_options(my_fuzz_test PRIVATE /bigobj)

target_include_directories(my_fuzz_test SYSTEM PRIVATE
    "${CMAKE_BINARY_DIR}/_deps/googletest-src/googletest/include"
)

link_fuzztest(my_fuzz_test)

# In libFuzzer compatibility mode on Windows (clang-cl), lld-link does not
# understand sanitizer flags, so link the /MD libFuzzer runtime and the dynamic
# ASan runtime explicitly. (Function is provided by the fuzztest subdirectory.)
if (FUZZTEST_COMPATIBILITY_MODE STREQUAL "libfuzzer" AND WIN32)
  fuzztest_link_windows_sanitizer_runtime(my_fuzz_test)
endif()

target_link_libraries(my_fuzz_test PRIVATE 
    fuzztest::fuzztest
    GTest::gtest
    absl::status
    absl::statusor
    absl::base
    absl::raw_logging_internal
)



gtest_discover_tests(my_fuzz_test)