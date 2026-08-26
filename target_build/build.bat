@echo off
setlocal DisableDelayedExpansion

rem ==========================================================================
rem  Build the my_fuzz_test target (works with both Ninja and Visual Studio
rem  generators). CONFIG defaults to Release.
rem ==========================================================================

set "BUILD_DIR=%~dp0build"
if not defined CONFIG set "CONFIG=Release"

rem ---- Set up MSVC / Windows SDK environment (rc.exe, STL, SDK libs) ---------
call "%~dp0_msvc_env.bat"
if errorlevel 1 exit /b 1

rem ASan runtime workarounds (LLVM clang ASan on Windows + this dependency set):
rem   detect_odr_violation=0 : benign "odr-violation" false positive between
rem                             fuzztest's L"*" and googletest's "*".
rem   intercept_strlen=0     : avoid an ASan empty-string strlen false positive.
rem Applies to the gtest_discover_tests POST_BUILD step too (env propagates).
if not defined ASAN_OPTIONS set "ASAN_OPTIONS=detect_odr_violation=0:intercept_strlen=0"

if not exist "%BUILD_DIR%\CMakeCache.txt" (
    echo ERROR: not configured yet. Run configure.bat first.
    exit /b 1
)

cmake --build "%BUILD_DIR%" --config %CONFIG% --target my_fuzz_test
if errorlevel 1 (
    echo.
    echo *** BUILD FAILED ***
    exit /b 1
)

rem ---- locate the exe for either layout ------------------------------
set "EXE="
if exist "%BUILD_DIR%\my_fuzz_test.exe" set "EXE=%BUILD_DIR%\my_fuzz_test.exe"
if not defined EXE if exist "%BUILD_DIR%\%CONFIG%\my_fuzz_test.exe" set "EXE=%BUILD_DIR%\%CONFIG%\my_fuzz_test.exe"

set "DLL="
if defined EXE (
    if exist "%EXE%\..\clang_rt.asan_dynamic-x86_64.dll" set "DLL=%EXE%\..\clang_rt.asan_dynamic-x86_64.dll"
)

echo.
if not defined EXE (
    echo WARNING: my_fuzz_test.exe not found under %BUILD_DIR%
    exit /b 0
)
echo Build OK.
echo   exe : %EXE%
if defined DLL (
    echo   asan: %DLL%  ^(copied next to exe by CMake POST_BUILD^)
) else (
    echo   WARNING: clang_rt.asan_dynamic-x86_64.dll not found next to the exe!
    echo   The exe needs it. Check the compiler toolchain ships a dynamic ASan runtime.
)
exit /b 0