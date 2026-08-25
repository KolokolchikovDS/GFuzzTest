@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set INC=/I"D:\GFuzzTest\package\msvc\fuzztest\include"
cl /nologo %INC% /MD /O2 /EHsc /std:c++17 "D:\GFuzzTest\_pkg_fix\consume_strcatw.cc" ^
   "D:\GFuzzTest\package\msvc\fuzztest\lib\Release\fuzztest.lib" ^
   /Fe:"D:\GFuzzTest\_pkg_fix\consume_release.exe"
if errorlevel 1 ( echo LINK_FAILED_RELEASE & exit /b 1 ) else ( echo LINK_OK_RELEASE )
"D:\GFuzzTest\_pkg_fix\consume_release.exe"
echo EXITCODE=%errorlevel%