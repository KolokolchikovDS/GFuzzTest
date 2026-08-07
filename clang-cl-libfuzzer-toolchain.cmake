# Toolchain for building FuzzTest in libFuzzer "compatibility mode" on
# Windows with Clang (clang-cl) targeting the MSVC ABI, using the DYNAMIC CRT
# (/MD) and a libFuzzer runtime rebuilt from source with /MD.
#
# Requirements:
#   * A recent Clang toolchain. LLVM 22.1.8 is used here because its dynamic
#     ASan runtime works on Windows, while the one bundled with VS2022's
#     Clang 19 crashes at startup ("interception_win: unhandled instruction").
#     Put the LLVM 22 bin directory on PATH before configuring (it is detected
#     as the "clang-cl" below) and run from a VS x64 developer environment
#     (vcvars64.bat) so the MSVC STL / Windows SDK / rc.exe are found.
#   * Build the libFuzzer runtime from source (third_party/libfuzzer, /MD) and
#     pass -DLIBFUZZER_NO_MAIN_LIBRARY=<path to clang_rt.fuzzer_no_main-md-x86_64.lib>.
#
# Why this file exists:
#   * clang-cl is MSVC-flavored, so CMake links executables with lld-link
#     directly. lld-link does not understand sanitizer flags (-fsanitize=address)
#     and does not pull in the ASan/libFuzzer runtimes; those are linked
#     explicitly (see fuzztest/cmake/CompatibilityModeLinkLibFuzzer.cmake).
#   * The libFuzzer runtime shipped inside Clang is prebuilt with the static
#     CRT (/MT). To build a fuzzer with the dynamic CRT (/MD) we rebuild
#     libFuzzer from source with /MD.
#   * Configure-time try_compiles link a full executable; with global
#     fuzzing/instrumentation flags those links fail (undefined sanitizer
#     coverage symbols). Compiling try_compiles to static libraries avoids the
#     link step entirely.
#
# Usage (from a VS2022 x64 developer prompt, with LLVM22\bin on PATH):
#   cmake -S . -B build-clang-md -G Ninja \
#     -DCMAKE_TOOLCHAIN_FILE=clang-cl-libfuzzer-toolchain.cmake \
#     -DFUZZTEST_COMPATIBILITY_MODE=libfuzzer \
#     -DLIBFUZZER_NO_MAIN_LIBRARY=D:/GFuzzTest/build-libfuzzer-md/clang_rt.fuzzer_no_main-md-x86_64.lib

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

# Clang's MSVC-flavored driver; resolved from PATH (use LLVM 22.x).
set(CMAKE_C_COMPILER "clang-cl" CACHE FILEPATH "Clang-cl C compiler" FORCE)
set(CMAKE_CXX_COMPILER "clang-cl" CACHE FILEPATH "Clang-cl C++ compiler" FORCE)

# rc.exe / mt.exe come from the Windows SDK. Some developer environments do not
# put rc.exe on PATH, so pass -DCMAKE_RC_COMPILER=<full path to rc.exe> (e.g.
# .../Windows Kits/10/bin/<ver>/x64/rc.exe) when needed.
set(CMAKE_RC_COMPILER "rc" CACHE FILEPATH "Windows resource compiler")

# Only compile configure-time try_compiles (no link). Global sanitizer/fuzzer
# instrumentation flags would otherwise break the link step of try_compiles.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Use the DYNAMIC MSVC runtime (/MD). This matches a typical application build.
# The libFuzzer runtime is built from source with /MD (see third_party/libfuzzer)
# and the dynamic ASan runtime is linked explicitly, so /failifmismatch checks
# are consistent across all objects.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL" CACHE STRING "Use dynamic release CRT (/MD)" FORCE)

# Path to the libFuzzer "no_main" runtime library rebuilt with /MD.
set(LIBFUZZER_NO_MAIN_LIBRARY "" CACHE FILEPATH
    "Path to clang_rt.fuzzer_no_main-md-x86_64.lib built with /MD")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)