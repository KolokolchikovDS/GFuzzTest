@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set REL=D:\GFuzzTest\package\msvc\fuzztest\lib\Release\fuzztest.lib
set DBG=D:\GFuzzTest\package\msvc\fuzztest\lib\Debug\fuzztest.lib

copy /Y "%REL%" "D:\GFuzzTest\_pkg_fix\fuzztest_release.backup.lib" >nul
copy /Y "%DBG%" "D:\GFuzzTest\_pkg_fix\fuzztest_debug.backup.lib" >nul

lib /nologo /OUT:"%REL%.new" "%REL%" "D:\GFuzzTest\_pkg_fix\str_cat_w_rel.obj"
if errorlevel 1 exit /b 1
move /Y "%REL%.new" "%REL%" >nul

lib /nologo /OUT:"%DBG%.new" "%DBG%" "D:\GFuzzTest\_pkg_fix\str_cat_w_dbg.obj"
if errorlevel 1 exit /b 1
move /Y "%DBG%.new" "%DBG%" >nul

dir "%REL%" "%DBG%"
echo DONE