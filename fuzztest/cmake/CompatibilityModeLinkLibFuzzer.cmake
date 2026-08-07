# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file is for the DYNAMIC-CRT (/MD) Windows build of FuzzTest in libFuzzer
# compatibility mode:
#   * libFuzzer: rebuilt from source with /MD (see third_party/libfuzzer); the
#     toolchain points LIBFUZZER_NO_MAIN_LIBRARY at that library.
#   * ASan: the dynamic runtime (clang_rt.asan_dynamic-*.lib/.dll), because /MD
#     builds use the dynamic ASan runtime.
#
# There is no llvm-config / bash on Windows, so the ASan runtime files are
# located relative to the C++ compiler used for this build.

# Locates the dynamic ASan runtime files shipped with the Clang toolchain and
# sets, in the calling scope:
#   _ASAN_DYNAMIC_LIB  - clang_rt.asan_dynamic-x86_64.lib (import lib)
#   _ASAN_THUNK_LIB    - clang_rt.asan_dynamic_runtime_thunk-x86_64.lib
#   _ASAN_DLL          - clang_rt.asan_dynamic-x86_64.dll
function(_locate_asan_dynamic_files)
  get_filename_component(_clang_bin_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
  get_filename_component(_clang_root "${_clang_bin_dir}" DIRECTORY)
  foreach (_pat IN ITEMS
      "clang_rt.asan_dynamic-x86_64.lib"
      "clang_rt.asan_dynamic_runtime_thunk-x86_64.lib"
      "clang_rt.asan_dynamic-x86_64.dll")
    file(GLOB _found_lib
         "${_clang_bin_dir}/../lib/clang/*/lib/windows/${_pat}"
         "${_clang_root}/lib/clang/*/lib/windows/${_pat}"
         "${_clang_root}/../lib/clang/*/lib/windows/${_pat}")
    if (NOT _found_lib)
      message(FATAL_ERROR
        "Could not locate the Clang ASan dynamic runtime file '${_pat}' under "
        "'${_clang_root}'. Install a Clang toolchain that ships with the ASan "
        "runtime (e.g. the LLVM toolchain bundled with Visual Studio).")
    endif()
    list(GET _found_lib 0 _lib)
    if (_pat STREQUAL "clang_rt.asan_dynamic-x86_64.lib")
      set(_ASAN_DYNAMIC_LIB "${_lib}")
    elseif (_pat STREQUAL "clang_rt.asan_dynamic_runtime_thunk-x86_64.lib")
      set(_ASAN_THUNK_LIB "${_lib}")
    else ()
      set(_ASAN_DLL "${_lib}")
    endif()
  endforeach()
  set(_ASAN_DYNAMIC_LIB "${_ASAN_DYNAMIC_LIB}" PARENT_SCOPE)
  set(_ASAN_THUNK_LIB "${_ASAN_THUNK_LIB}" PARENT_SCOPE)
  set(_ASAN_DLL "${_ASAN_DLL}" PARENT_SCOPE)
endfunction()

function(_link_libfuzzer_in_compatibility_mode name)
  if (FUZZTEST_COMPATIBILITY_MODE STREQUAL "libfuzzer")
    if (WIN32 OR MSVC)
      if (NOT LIBFUZZER_NO_MAIN_LIBRARY)
        message(FATAL_ERROR
          "LIBFUZZER_NO_MAIN_LIBRARY is not set. Build the /MD libFuzzer "
          "runtime from third_party/libfuzzer and pass "
          "-DLIBFUZZER_NO_MAIN_LIBRARY=<path to clang_rt.fuzzer_no_main-md-"
          "x86_64.lib>.")
      endif()
      target_link_libraries(${name} PRIVATE "${LIBFUZZER_NO_MAIN_LIBRARY}")
    else ()
      EXECUTE_PROCESS (
          COMMAND bash -c "find \${PATH//:/ } -maxdepth 1 -executable -name 'llvm-config*'"
          OUTPUT_VARIABLE LLVM_CONFIG OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      EXECUTE_PROCESS(
        COMMAND bash -c "find $(${LLVM_CONFIG} --libdir) \
        -name libclang_rt.fuzzer_no_main-x86_64.a"
        OUTPUT_VARIABLE FUZZER_NO_MAIN OUTPUT_STRIP_TRAILING_WHITESPACE
      )
      if(NOT FUZZER_NO_MAIN)
        # LLVM_ENABLE_PER_TARGET_RUNTIME_DIR was set to ON when building LLVM.
        EXECUTE_PROCESS(
          COMMAND bash -c "find / -regex \
          \"$(${LLVM_CONFIG} --libdir).*$(${LLVM_CONFIG} --host-target).*libclang_rt.fuzzer_no_main.a\""
          OUTPUT_VARIABLE FUZZER_NO_MAIN OUTPUT_STRIP_TRAILING_WHITESPACE
        )
      endif()
      target_link_libraries(${name} PRIVATE ${FUZZER_NO_MAIN})
    endif ()
  endif ()
endfunction()

# Links the /MD libFuzzer runtime and the dynamic ASan runtime into an
# executable and stages the ASan DLL next to it. This must be called on the
# final executable target (not a static library) because the ASan thunk needs
# whole-archive semantics and an explicit symbol, and the DLL has to be copied
# next to the binary.
function(fuzztest_link_windows_sanitizer_runtime name)
  if (FUZZTEST_COMPATIBILITY_MODE STREQUAL "libfuzzer" AND (WIN32 OR MSVC))
    if (NOT LIBFUZZER_NO_MAIN_LIBRARY)
      message(FATAL_ERROR
        "LIBFUZZER_NO_MAIN_LIBRARY is not set. Build the /MD libFuzzer "
        "runtime from third_party/libfuzzer and pass "
        "-DLIBFUZZER_NO_MAIN_LIBRARY=<path to clang_rt.fuzzer_no_main-md-"
        "x86_64.lib>.")
    endif()
    _locate_asan_dynamic_files()
    target_link_libraries(${name} PRIVATE
        "${LIBFUZZER_NO_MAIN_LIBRARY}"
        "${_ASAN_DYNAMIC_LIB}")
    target_link_options(${name} PRIVATE
        "/WHOLEARCHIVE:${_ASAN_THUNK_LIB}"
        "/include:__asan_seh_interceptor")
    add_custom_command(TARGET ${name} POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${_ASAN_DLL}" "$<TARGET_FILE_DIR:${name}>"
        VERBATIM)
  endif ()
endfunction()