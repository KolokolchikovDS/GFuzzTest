cmake_minimum_required(VERSION 3.19)

set(CMAKE_CXX_STANDARD 20)
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

add_subdirectory(fuzztest)

enable_testing()
include(GoogleTest)

fuzztest_setup_fuzzing_flags()

add_executable(my_fuzz_test main.cpp)

target_include_directories(my_fuzz_test SYSTEM PRIVATE
    "${CMAKE_BINARY_DIR}/_deps/googletest-src/googletest/include"
)

link_fuzztest(my_fuzz_test)

target_link_libraries(my_fuzz_test PRIVATE 
    fuzztest::fuzztest
    GTest::gtest
    absl::status
    absl::statusor
    absl::base
    absl::raw_logging_internal
)



gtest_discover_tests(my_fuzz_test)