# Standalone build of the libFuzzer runtime (no main) for Windows/MSVC,
# linked with the dynamic CRT (/MD).
#
# Why: the libFuzzer runtime shipped inside the Clang/LLVM distribution
# (clang_rt.fuzzer_no_main*.lib) is prebuilt with the STATIC CRT (/MT). To link
# FuzzTest into an application that uses the dynamic CRT (/MD), the runtime
# must be rebuilt from source with /MD so the RuntimeLibrary (/failifmismatch)
# matches.
#
# This project compiles compiler-rt/lib/fuzzer (LLVM release llvmorg-22.1.8)
# into a static library. It is intentionally built WITHOUT the -fsanitize=*
# fuzzing/instrumentation flags: libFuzzer is itself the coverage engine and
# must not be instrumented.
#
# Build (from a VS x64 developer prompt so MSVC STL/rc.exe are available):
#   cmake -S third_party/libfuzzer -B build-libfuzzer-md -G Ninja \
#       -DCMAKE_CXX_COMPILER=clang-cl
#   cmake --build build-libfuzzer-md
#
# Output: build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib

cmake_minimum_required(VERSION 3.19)
project(libfuzzer_md CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Force the dynamic CRT (/MD) so the resulting library matches an /MD app.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "Use dynamic CRT (/MD)" FORCE)

set(LIBFUZZER_SOURCES
  FuzzerCrossOver.cpp
  FuzzerDataFlowTrace.cpp
  FuzzerDriver.cpp
  FuzzerExtFunctionsDlsym.cpp
  FuzzerExtFunctionsWeak.cpp
  FuzzerExtFunctionsWindows.cpp
  FuzzerExtraCounters.cpp
  FuzzerExtraCountersDarwin.cpp
  FuzzerExtraCountersWindows.cpp
  FuzzerFork.cpp
  FuzzerIO.cpp
  FuzzerIOPosix.cpp
  FuzzerIOWindows.cpp
  FuzzerLoop.cpp
  FuzzerMerge.cpp
  FuzzerMutate.cpp
  FuzzerSHA1.cpp
  FuzzerTracePC.cpp
  FuzzerUtil.cpp
  FuzzerUtilDarwin.cpp
  FuzzerUtilFuchsia.cpp
  FuzzerUtilLinux.cpp
  FuzzerUtilPosix.cpp
  FuzzerUtilWindows.cpp)

# The `no_main` variant: everything except FuzzerMain.cpp (the fuzzer's own
# main()). FuzzTest provides LLVMFuzzerRunDriver and its own main, so it links
# this variant.
add_library(clang_rt_fuzzer_no_main STATIC ${LIBFUZZER_SOURCES})

target_include_directories(clang_rt_fuzzer_no_main
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/include)

# Mirror the flags compiler-rt uses for the MSVC build of libFuzzer.
# Exceptions off (avoids warnings/errors in MSVC headers); keep frame pointers
# for stack traces. Crucially, no -fsanitize-coverage / -fsanitize=fuzzer
# instrumentation (libFuzzer is itself the coverage engine and must not be
# coverage-instrumented).
#
# -fsanitize=address is added only so this library emits the same
# /failifmismatch:"annotate_string=1"/"annotate_vector=1" directives as the
# ASan-instrumented FuzzTest objects (without it, ASan reports a mismatch:
# "annotate_string=1" vs "annotate_string=0"). The runtime's own critical paths
# are marked NO_SANITIZE, so ASan instrumentation here is harmless.
target_compile_options(clang_rt_fuzzer_no_main PRIVATE
  /D_HAS_EXCEPTIONS=0
  -fno-omit-frame-pointer
  -fsanitize=address
  -fsanitize-coverage=0)

# Deterministic, stable output name.
set_target_properties(clang_rt_fuzzer_no_main PROPERTIES
  OUTPUT_NAME "clang_rt.fuzzer_no_main-md-x86_64")