@echo off
setlocal DisableDelayedExpansion

rem ==========================================================================
rem  FuzzTest - configure using a SPECIFIC standalone clang toolchain.
rem
rem  REQUIRED: set CLANG_DIR to the folder containing clang-cl.exe, e.g.:
rem      set "CLANG_DIR=D:\GFuzzTest\llvm-22\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin"
rem      configure.bat
rem
rem  WHY NINJA? The Visual Studio generator IGNORES -DCMAKE_CXX_COMPILER and
rem  always uses its own compiler (cl.exe / -T ClangCL). Only the Ninja (or
rem  Makefiles) generator honors an arbitrary external compiler such as your
rem  standalone LLVM 22 clang-cl. To avoid any need for a separate Ninja
rem  install, this script uses the bundled ninja.exe in target_build\bin.
rem  Visual Studio is still required for the MSVC STL headers / Windows SDK
rem  that clang-cl needs (auto-set-up via vcvars64.bat).
rem
rem  If you accept using the clang that ships inside Visual Studio instead,
rem  see configure_vs.bat.
rem ==========================================================================

set "SRC_DIR=%~dp0.."
set "BUILD_DIR=%~dp0build"

rem ---- Set up MSVC / Windows SDK environment (rc.exe, STL, SDK libs) ---------
call "%~dp0_msvc_env.bat"
if errorlevel 1 exit /b 1

setlocal EnableDelayedExpansion

if not exist "%SRC_DIR%\CMakeLists.txt" goto :no_src

rem ---- Mandatory: standalone clang toolchain ---------------------------------
if not defined CLANG_DIR goto :no_clang
if not exist "%CLANG_DIR%\clang-cl.exe" goto :bad_clang

rem ---- Bundled Ninja ---------------------------------------------------------
set "NINJA=%~dp0bin\ninja.exe"
if not exist "%NINJA%" goto :no_ninja

set "GENERATOR=Ninja"
set "PLATFORM=x64"

rem ---- Offline vendored dependencies (no network / git needed) ---------------
set "DEPS=%~dp0third_party\deps"

rem ---- Prebuilt libFuzzer runtime (dynamic CRT, /MD) --------------------------
if not defined LIBFUZZER_NO_MAIN_LIBRARY set "LIBFUZZER_NO_MAIN_LIBRARY=%~dp0third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib"

rem ---- Point the compilers at YOUR standalone clang-cl ------------------------
set "COMPILER_OPTS=-DCMAKE_C_COMPILER=!CLANG_DIR!\clang-cl.exe -DCMAKE_CXX_COMPILER=!CLANG_DIR!\clang-cl.exe -DCMAKE_MAKE_PROGRAM=!NINJA!"

echo.
echo  Source dir : %SRC_DIR%
echo  Build dir  : %BUILD_DIR%
echo  Generator  : !GENERATOR!
echo  Compiler   : !CLANG_DIR!\clang-cl.exe  (STANDALONE, explicit)
echo  Ninja      : !NINJA!
echo  Deps       : offline (vendored in target_build\third_party\deps)
echo.

cmake -S "%SRC_DIR%" -B "%BUILD_DIR%" ^
  -G "!GENERATOR!" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_SUPPRESS_REGENERATION=ON ^
  -DCMAKE_REQUIRED_FLAGS="/std:c++latest" ^
  -DFUZZTEST_COMPATIBILITY_MODE=libfuzzer ^
  -DFUZZTEST_FUZZING_MODE=OFF ^
  -DFUZZTEST_BUILD_TESTING=OFF ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL ^
  "-DLIBFUZZER_NO_MAIN_LIBRARY=%LIBFUZZER_NO_MAIN_LIBRARY%" ^
  "-DFETCHCONTENT_SOURCE_DIR_ABSEIL-CPP=%DEPS%\abseil-cpp" ^
  "-DFETCHCONTENT_SOURCE_DIR_RE2=%DEPS%\re2" ^
  "-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=%DEPS%\googletest" ^
  "-DFETCHCONTENT_SOURCE_DIR_ANTLR_CPP=%DEPS%\antlr_cpp" ^
  !COMPILER_OPTS!

if errorlevel 1 goto :fail

echo.
echo Configuration OK. Next step: build.bat
exit /b 0

:no_src
echo ERROR: source tree not found at %SRC_DIR%
exit /b 1
:no_clang
echo ERROR: CLANG_DIR is not set.
echo Set it to the folder that contains clang-cl.exe, for example:
echo   set "CLANG_DIR=D:\GFuzzTest\llvm-22\clang+llvm-22.1.8-x86_64-pc-windows-msvc\bin"
exit /b 1
:bad_clang
echo ERROR: clang-cl.exe not found in "%CLANG_DIR%"
exit /b 1
:no_ninja
echo ERROR: ninja.exe not found at "%NINJA%". It is bundled in target_build\bin.
exit /b 1
:fail
echo.
echo *** Configuration FAILED ***
exit /b 1