@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
set INC=/I"D:\GFuzzTest\package\msvc\fuzztest\include"
cl /nologo /c %INC% /MD  /O2 /EHsc /std:c++17 /Fo"D:\GFuzzTest\_pkg_fix\str_cat_w_rel.obj" "D:\GFuzzTest\_pkg_fix\str_cat_w.cc"
cl /nologo /c %INC% /MDd /Od /EHsc /std:c++17 /Fo"D:\GFuzzTest\_pkg_fix\str_cat_w_dbg.obj" "D:\GFuzzTest\_pkg_fix\str_cat_w.cc"
dir "D:\GFuzzTest\_pkg_fix\*.obj"