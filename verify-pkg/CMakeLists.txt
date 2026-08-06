cmake_minimum_required(VERSION 3.19)
project(verify_pkg CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Absolute path to the packaged fuzztest dependency.
set(FUZZTEST_PKG "D:/GFuzzTest/package/fuzztest")

add_executable(verify_tests tests.cpp)

target_include_directories(verify_tests PRIVATE "${FUZZTEST_PKG}/include")

# Link the single consolidated static library. Pick by configuration.
target_link_libraries(verify_tests PRIVATE
    "$<$<CONFIG:Debug>:${FUZZTEST_PKG}/lib/Debug/fuzztest.lib>"
    "$<$<CONFIG:Release>:${FUZZTEST_PKG}/lib/Release/fuzztest.lib>"
)

target_compile_options(verify_tests PRIVATE /bigobj)