@echo off
setlocal EnableDelayedExpansion

rem ==========================================================================
rem  Merges all FuzzTest + Abseil + gtest + re2 static libs under %LIBDIR%
rem  into a single %LIBDIR%\fuzztest.lib using llvm-lib (%LLVM_LIB%).
rem  Uses a response file to avoid the ~8K cmd.exe command-line limit.
rem  Expects %LIBDIR% and %LLVM_LIB% to be set by the caller.
rem ==========================================================================

set "MERGE_RSP=%TEMP%\fuzztest_merge.rsp"
del "%MERGE_RSP%" >nul 2>&1

for /r "%LIBDIR%\fuzztest" %%F in (*.lib) do echo %%F >> "%MERGE_RSP%"
for /r "%LIBDIR%\absl"      %%F in (*.lib) do echo %%F >> "%MERGE_RSP%"
echo %LIBDIR%\gtest.lib >> "%MERGE_RSP%"
echo %LIBDIR%\re2.lib   >> "%MERGE_RSP%"

del "%LIBDIR%\fuzztest.lib" >nul 2>&1
"%LLVM_LIB%" @"%MERGE_RSP%" /out:"%LIBDIR%\fuzztest.lib" >nul
set "RESULT=!errorlevel!"
del "%MERGE_RSP%" >nul 2>&1

if "!RESULT!"=="0" if exist "%LIBDIR%\fuzztest.lib" (
    echo Created %LIBDIR%\fuzztest.lib
) else (
    echo WARNING: failed to merge fuzztest.lib; link via the link.rsp response file instead.
)
exit /b !RESULT!