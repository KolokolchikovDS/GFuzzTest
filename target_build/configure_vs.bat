@echo off
setlocal DisableDelayedExpansion

rem ==========================================================================
rem  FuzzTest - configure for the Visual Studio generator using the CLANG-CL
rem  TOOLSET THAT SHIPS INSIDE VISUAL STUDIO (-T ClangCL).
rem
rem  Use this ONLY if you accept the clang that is bundled with Visual Studio.
rem  To build with YOUR OWN standalone clang (e.g. LLVM 22), use configure.bat
rem  instead (the Ninja generator honors an arbitrary compiler; the Visual
rem  Studio generator ignores -DCMAKE_CXX_COMPILER).
rem ==========================================================================

set "SRC_DIR=%~dp0.."
set "BUILD_DIR=%~dp0build_vs"

call "%~dp0_msvc_env.bat"
if errorlevel 1 exit /b 1

rem ---- Detect the highest installed VS version (paren-safe via temp file) ----
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :no_vswhere

"%VSWHERE%" -latest -products * -property installationVersion > "%TEMP%\vs_ver.txt" 2>nul
set "_VSVER="
set /p _VSVER=<"%TEMP%\vs_ver.txt"
del "%TEMP%\vs_ver.txt" >nul 2>&1

if not defined GENERATOR (
    set "GENERATOR=Visual Studio 17 2022"
    if defined _VSVER (
        for /f "tokens=1 delims=." %%M in ("%_VSVER%") do set "_MAJOR=%%M"
        if "%_MAJOR%"=="18" set "GENERATOR=Visual Studio 18 2026"
        if "%_MAJOR%"=="17" set "GENERATOR=Visual Studio 17 2022"
        if "%_MAJOR%"=="16" set "GENERATOR=Visual Studio 16 2019"
    )
)
if not defined PLATFORM set "PLATFORM=x64"

setlocal EnableDelayedExpansion

set "DEPS=%~dp0third_party\deps"
if not defined LIBFUZZER_NO_MAIN_LIBRARY set "LIBFUZZER_NO_MAIN_LIBRARY=%~dp0third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib"

echo.
echo  Source dir : %SRC_DIR%
echo  Build dir  : %BUILD_DIR%
echo  Generator  : !GENERATOR!  (%PLATFORM%)  [-T ClangCL]
echo  Compiler   : clang-cl bundled with Visual Studio
echo  Deps       : offline (vendored in target_build\third_party\deps)
echo.

cmake -S "%SRC_DIR%" -B "%BUILD_DIR%" ^
  -G "!GENERATOR!" -A "%PLATFORM%" -T ClangCL ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DFUZZTEST_COMPATIBILITY_MODE=libfuzzer ^
  -DFUZZTEST_FUZZING_MODE=OFF ^
  -DFUZZTEST_BUILD_TESTING=OFF ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL ^
  "-DLIBFUZZER_NO_MAIN_LIBRARY=%LIBFUZZER_NO_MAIN_LIBRARY%" ^
  "-DFETCHCONTENT_SOURCE_DIR_ABSEIL-CPP=%DEPS%\abseil-cpp" ^
  "-DFETCHCONTENT_SOURCE_DIR_RE2=%DEPS%\re2" ^
  "-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=%DEPS%\googletest" ^
  "-DFETCHCONTENT_SOURCE_DIR_ANTLR_CPP=%DEPS%\antlr_cpp"

if errorlevel 1 goto :fail

echo.
echo Configuration OK. Next step: build.bat  ^(use CONFIG=Release^)
exit /b 0

:no_vswhere
echo ERROR: vswhere not found at "%VSWHERE%"
exit /b 1
:fail
echo.
echo *** Configuration FAILED ***
exit /b 1