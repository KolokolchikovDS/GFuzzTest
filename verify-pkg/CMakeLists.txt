cmake_minimum_required(VERSION 3.19)
project(verify_pkg CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# MSVC 14.38 only exposes C++23 via /std:c++latest; the packaged fuzztest.lib
# was compiled with it, so the consumer must match for ABI consistency.
if(MSVC)
  add_compile_options(/std:c++latest)
endif()

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