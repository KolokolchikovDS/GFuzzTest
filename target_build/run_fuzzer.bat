@echo off
setlocal EnableDelayedExpansion

rem ==========================================================================
rem  Run the built fuzzer (libFuzzer compatibility mode).
rem  Any arguments after the script name are passed to my_fuzz_test.exe.
rem ==========================================================================

set "BUILD_DIR=%~dp0build"
if not defined CONFIG set "CONFIG=Release"

set "EXE="
if exist "%BUILD_DIR%\my_fuzz_test.exe" set "EXE=%BUILD_DIR%\my_fuzz_test.exe"
if not defined EXE if exist "%BUILD_DIR%\%CONFIG%\my_fuzz_test.exe" set "EXE=%BUILD_DIR%\%CONFIG%\my_fuzz_test.exe"

if not defined EXE (
    echo ERROR: my_fuzz_test.exe not found. Run build.bat first.
    exit /b 1
)

rem ASan runtime workarounds (LLVM clang ASan on Windows + this dependency set):
rem   detect_odr_violation=0 : benign "odr-violation" false positive between
rem                             fuzztest's L"*" and googletest's "*".
rem   intercept_strlen=0     : avoid an ASan empty-string strlen false positive.
rem Can be overridden via the ASAN_OPTIONS env var.
if not defined ASAN_OPTIONS set "ASAN_OPTIONS=detect_odr_violation=0:intercept_strlen=0"

"%EXE%" %*
exit /b %errorlevel%