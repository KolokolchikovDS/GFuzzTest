cmake_minimum_required(VERSION 3.19)
project(verify_pkg_clang CXX)

# Verify the clang-cl / libFuzzer packaged fuzztest dependency. Configure with:
#   -DCMAKE_TOOLCHAIN_FILE=clang-cl-libfuzzer-toolchain.cmake
#   -DLIBFUZZER_NO_MAIN_LIBRARY=D:/GFuzzTest/build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib
# (C++23, /MD, sanitizer instrumentation matches how the package lib was built.)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The packaged lib was built with these flags (clang-cl 22, /MD).
add_compile_options(
    /std:c++latest
    -D_HAS_CXX23=0
    -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -UNDEBUG
    -fsanitize=address
    -fsanitize=fuzzer-no-link
    -DFUZZTEST_COMPATIBILITY_MODE
    -fsanitize-coverage=inline-8bit-counters -fsanitize-coverage=trace-cmp
    -DADDRESS_SANITIZER
)

# Absolute path to the packaged clang fuzztest dependency.
set(FUZZTEST_PKG "D:/GFuzzTest/package/clang/fuzztest")

add_executable(verify_tests tests.cpp)

target_include_directories(verify_tests PRIVATE "${FUZZTEST_PKG}/include")

# Link the single consolidated static library. Pick by configuration.
# The clang "Release" package lib is a RelWithDebInfo build (as originally
# built); map both Release and RelWithDebInfo to it.
target_link_libraries(verify_tests PRIVATE
    "$<$<CONFIG:Debug>:${FUZZTEST_PKG}/lib/Debug/fuzztest.lib>"
    "$<$<CONFIG:Release>:${FUZZTEST_PKG}/lib/Release/fuzztest.lib>"
    "$<$<CONFIG:RelWithDebInfo>:${FUZZTEST_PKG}/lib/Release/fuzztest.lib>"
)

# Link the /MD libFuzzer runtime and the dynamic ASan runtime (same as
# fuzztest_link_windows_sanitizer_runtime).
set(LIBFUZZER_NO_MAIN_LIBRARY "" CACHE FILEPATH
    "Path to clang_rt.fuzzer_no_main-md-x86_64.lib built with /MD")

get_filename_component(_clang_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
get_filename_component(_clang_root "${_clang_bin_dir}" DIRECTORY)
foreach (_pat IN ITEMS
    "clang_rt.asan_dynamic-x86_64.lib"
    "clang_rt.asan_dynamic_runtime_thunk-x86_64.lib"
    "clang_rt.asan_dynamic-x86_64.dll")
  file(GLOB _f
       "${_clang_bin_dir}/../lib/clang/*/lib/windows/${_pat}"
       "${_clang_root}/lib/clang/*/lib/windows/${_pat}"
       "${_clang_root}/../lib/clang/*/lib/windows/${_pat}")
  if (NOT _f)
    message(FATAL_ERROR "Could not locate ASan runtime '${_pat}' under '${_clang_root}'")
  endif()
  list(GET _f 0 _loc)
  if (_pat STREQUAL "clang_rt.asan_dynamic-x86_64.lib")
    set(_ASAN_DYNAMIC_LIB "${_loc}")
  elseif (_pat STREQUAL "clang_rt.asan_dynamic_runtime_thunk-x86_64.lib")
    set(_ASAN_THUNK_LIB "${_loc}")
  else ()
    set(_ASAN_DLL "${_loc}")
  endif()
endforeach()

target_link_libraries(verify_tests PRIVATE
    "${LIBFUZZER_NO_MAIN_LIBRARY}"
    "${_ASAN_DYNAMIC_LIB}")
target_link_options(verify_tests PRIVATE
    "/WHOLEARCHIVE:${_ASAN_THUNK_LIB}"
    "/include:__asan_seh_interceptor")
add_custom_command(TARGET verify_tests POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${_ASAN_DLL}" "$<TARGET_FILE_DIR:verify_tests>"
    VERBATIM)