@echo off
setlocal EnableDelayedExpansion

rem ==========================================================================
rem  Stage the built FuzzTest artifacts (libs + dll + headers) into
rem  target_build\external\ so they can be linked into ANOTHER project.
rem
rem  Run AFTER build.bat. Layout produced:
rem     external\lib\fuzztest\*.lib            - FuzzTest static libraries
rem     external\lib\absl\**\*.lib             - Abseil static libraries
rem     external\lib\gtest.lib, re2.lib
rem     external\lib\clang_rt.fuzzer_no_main-md-x86_64.lib
rem     external\lib\clang_rt.asan_dynamic-x86_64.lib           (ASan import lib)
rem     external\lib\clang_rt.asan_dynamic_runtime_thunk-x86_64.lib
rem     external\bin\clang_rt.asan_dynamic-x86_64.dll           (runtime DLL)
rem     external\include\...                                    (headers)
rem     external\link.rsp                                       (all libs)
rem
rem  CLANG_DIR (optional): bin folder of the LLVM toolchain used to build,
rem  to locate the ASan dynamic runtime.
rem ==========================================================================

set "SRC_DIR=%~dp0.."
set "BUILD_DIR=%~dp0build"
set "OUT=%~dp0external"
set "LIBDIR=%OUT%\lib"
set "BINDIR=%OUT%\bin"
set "INCDIR=%OUT%\include"
set "RSP=%OUT%\link.rsp"

if not exist "%BUILD_DIR%\my_fuzz_test.exe" (
    echo ERROR: %BUILD_DIR%\my_fuzz_test.exe not found. Run build.bat first.
    exit /b 1
)

for %%D in ("%OUT%" "%LIBDIR%" "%BINDIR%" "%INCDIR%") do if not exist "%%~D" mkdir "%%~D"
del "%RSP%" >nul 2>&1

rem ---- 1. FuzzTest static libraries ----------------------------------------
echo Staging FuzzTest libs...
robocopy "%BUILD_DIR%\fuzztest" "%LIBDIR%\fuzztest" *.lib /S /NJH /NJS >nul
for /r "%BUILD_DIR%\fuzztest" %%F in (*.lib) do echo "%%F" >> "%RSP%"

rem ---- 2. Abseil static libraries (transitive deps) --------------------------
echo Staging Abseil libs...
robocopy "%BUILD_DIR%\_deps\abseil-cpp-build\absl" "%LIBDIR%\absl" *.lib /S /NJH /NJS >nul
for /r "%BUILD_DIR%\_deps\abseil-cpp-build\absl" %%F in (*.lib) do echo "%%F" >> "%RSP%"

rem ---- 3. re2 + gtest --------------------------------------------------------
echo Staging re2 and gtest...
copy /Y "%BUILD_DIR%\_deps\re2-build\re2.lib" "%LIBDIR%\re2.lib" >nul
copy /Y "%BUILD_DIR%\lib\gtest.lib" "%LIBDIR%\gtest.lib" >nul
echo "%BUILD_DIR%\_deps\re2-build\re2.lib" >> "%RSP%"
echo "%BUILD_DIR%\lib\gtest.lib" >> "%RSP%"

rem ---- 4. libFuzzer runtime + ASan import lib / thunk -------------------------
set "FUZZLIB=%~dp0third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib"
if not exist "%FUZZLIB%" set "FUZZLIB=%BUILD_DIR%\third_party\libfuzzer\clang_rt.fuzzer_no_main-md-x86_64.lib"
if exist "%FUZZLIB%" (
    copy /Y "%FUZZLIB%" "%LIBDIR%\" >nul
    echo "%FUZZLIB%" >> "%RSP%"
) else (
    echo WARNING: libFuzzer runtime not found; linking may require it.
)

rem Locate the ASan dynamic runtime from the clang toolchain
set "ASAN_LIBDIR="
if defined CLANG_DIR (
    for /d %%V in ("%CLANG_DIR%\..\lib\clang\*") do (
        if exist "%%~V\lib\windows\clang_rt.asan_dynamic-x86_64.lib" set "ASAN_LIBDIR=%%~V\lib\windows"
    )
)
if not defined ASAN_LIBDIR (
    for /d %%V in ("%SRC_DIR%\llvm-22\clang+llvm-*\lib\clang\*") do (
        if exist "%%~V\lib\windows\clang_rt.asan_dynamic-x86_64.lib" set "ASAN_LIBDIR=%%~V\lib\windows"
    )
)
if not defined ASAN_LIBDIR (
    echo WARNING: could not locate ASan dynamic runtime. Set CLANG_DIR to your LLVM bin folder.
) else (
    copy /Y "%ASAN_LIBDIR%\clang_rt.asan_dynamic-x86_64.dll" "%BINDIR%\" >nul
    copy /Y "%ASAN_LIBDIR%\clang_rt.asan_dynamic-x86_64.lib" "%LIBDIR%\" >nul
    copy /Y "%ASAN_LIBDIR%\clang_rt.asan_dynamic_runtime_thunk-x86_64.lib" "%LIBDIR%\" >nul
    echo "%ASAN_LIBDIR%\clang_rt.asan_dynamic-x86_64.lib" >> "%RSP%"
)

rem ---- 5. Headers -------------------------------------------------------------
rem fuzztest's public include root is the <repo>/fuzztest package dir, so its
rem contents go straight into include/ -> resolves "#include \"fuzztest/fuzztest.h\"".
rem Dependency headers are taken from the vendored sources in third_party/deps.
echo Staging headers...
if exist "%SRC_DIR%\fuzztest" xcopy /E /I /Y /Q "%SRC_DIR%\fuzztest\*" "%INCDIR%\" >nul
if exist "%~dp0third_party\deps\abseil-cpp\absl" xcopy /E /I /Y /Q "%~dp0third_party\deps\abseil-cpp\absl" "%INCDIR%\absl" >nul
if exist "%~dp0third_party\deps\googletest\googletest\include" xcopy /E /I /Y /Q "%~dp0third_party\deps\googletest\googletest\include\*" "%INCDIR%\" >nul
if exist "%~dp0third_party\deps\googletest\googlemock\include" xcopy /E /I /Y /Q "%~dp0third_party\deps\googletest\googlemock\include\*" "%INCDIR%\" >nul
if exist "%~dp0third_party\deps\re2\re2" xcopy /E /I /Y /Q "%~dp0third_party\deps\re2\re2" "%INCDIR%\re2" >nul

echo.
echo ============================================================
echo  Done. Staged FuzzTest artifacts under:
echo    %OUT%
echo.
echo  Headers : -I%INCDIR%
echo  Libs    : @%RSP%   ^(response file with ALL libs^)
echo  Runtime : copy %BINDIR%\clang_rt.asan_dynamic-x86_64.dll
echo             next to your final .exe
echo.
echo  Link (see README for full command):
echo    clang-cl my.obj @%RSP% ^
echo      /WHOLEARCHIVE:%LIBDIR%\clang_rt.asan_dynamic_runtime_thunk-x86_64.lib ^
echo      /include:__asan_seh_interceptor /out:my.exe
echo ============================================================
endlocal