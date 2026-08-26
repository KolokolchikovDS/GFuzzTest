@echo off
rem ==========================================================================
rem  Sets up the Visual Studio MSVC / Windows SDK environment (rc.exe, link.exe,
rem  MSVC STL headers, SDK libs) by calling vcvars64.bat. Must be invoked with
rem  `call` from another .bat so the environment changes persist.
rem  Uses goto-based error handling to avoid cmd parentheses pitfalls with
rem  the "Program Files (x86)" install path.
rem ==========================================================================

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto :no_vswhere

"%VSWHERE%" -latest -products * -property installationPath > "%TEMP%\vs_install.txt" 2>nul
set "VSINSTALL="
set /p VSINSTALL=<"%TEMP%\vs_install.txt"
del "%TEMP%\vs_install.txt" >nul 2>&1

if not defined VSINSTALL goto :no_vs

set "VCVARS=%VSINSTALL%\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" goto :no_vcvars

call "%VCVARS%" >nul 2>&1
exit /b %errorlevel%

:no_vswhere
echo [msvc-env] ERROR: vswhere not found at "%VSWHERE%"
echo              Install Visual Studio Build Tools ^(with the C++ workload^).
exit /b 1

:no_vs
echo [msvc-env] ERROR: no Visual Studio installation detected by vswhere.
exit /b 1

:no_vcvars
echo [msvc-env] ERROR: "%VCVARS%" not found. Is the Desktop C++ workload installed?
exit /b 1