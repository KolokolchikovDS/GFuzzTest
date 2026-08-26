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

# MSVC 14.38 (and clang-cl) only expose C++23 via /std:c++latest. Force it
# globally (also as a cache CMAKE_CXX_FLAGS so Abseil's configure-time standard
# detection sees C++20 and does not pin cxx_std_17).
if(MSVC OR (WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang"))
  add_compile_options(/std:c++latest)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /std:c++latest" CACHE STRING "CXX flags" FORCE)
endif()

# clang-cl 22 reports __cplusplus=202400 under /std:c++latest, which turns on
# MSVC STL C++23 paths (_HAS_CXX23) that clang-cl 22 cannot compile (e.g.
# <optional> std::invoke). MSVC 14.38's /std:c++latest is C++20 (_MSVC_LANG
# 202004, _HAS_CXX23=0), so pin the STL to the C++20 code paths to match.
if(WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-D_HAS_CXX23=0)
  # On Windows clang-cl, googletest's POSIX detection is off and gtest tries to
  # #include <pthread.h>; disable pthreads so gtest/gmock build cleanly.
  set(gtest_disable_pthreads ON CACHE BOOL "" FORCE)
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

# clang-cl 22's dynamic ASan runtime requires the release CRT (/MD) and cannot
# be combined with /MDd. Absl unconditionally sets CMAKE_MSVC_RUNTIME_LIBRARY
# to the Debug runtime in a Debug build, so force /MD on every target after all
# subdirectories are added (clang-cl uses the last /M* flag).
if(WIN32 AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  macro(_collect_all_targets _dir _acc)
    get_property(_tg DIRECTORY "${_dir}" PROPERTY BUILDSYSTEM_TARGETS)
    list(APPEND ${_acc} ${_tg})
    get_property(_sd DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
    foreach(_s IN LISTS _sd)
      _collect_all_targets("${_s}" ${_acc})
    endforeach()
  endmacro()
  _collect_all_targets("${CMAKE_SOURCE_DIR}" _all_targets)
  foreach(_t IN LISTS _all_targets)
    if(TARGET "${_t}")
      get_target_property(_tt "${_t}" TYPE)
      if(_tt STREQUAL "STATIC_LIBRARY" OR _tt STREQUAL "SHARED_LIBRARY" OR
         _tt STREQUAL "EXECUTABLE" OR _tt STREQUAL "MODULE_LIBRARY" OR
         _tt STREQUAL "OBJECT_LIBRARY")
        target_compile_options("${_t}" PRIVATE /MD)
      endif()
    endif()
  endforeach()
endif()