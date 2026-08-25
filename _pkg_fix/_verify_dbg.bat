@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set INC=/I"D:\GFuzzTest\package\msvc\fuzztest\include"
cl /nologo %INC% /MDd /Od /EHsc /std:c++17 "D:\GFuzzTest\_pkg_fix\consume_strcatw.cc" ^
   "D:\GFuzzTest\package\msvc\fuzztest\lib\Debug\fuzztest.lib" ^
   /Fe:"D:\GFuzzTest\_pkg_fix\consume_debug.exe"
if errorlevel 1 ( echo LINK_FAILED_DEBUG & exit /b 1 ) else ( echo LINK_OK_DEBUG )
"D:\GFuzzTest\_pkg_fix\consume_debug.exe"
echo EXITCODE=%errorlevel%