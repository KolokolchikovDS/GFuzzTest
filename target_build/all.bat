@echo off
setlocal EnableDelayedExpansion

rem ==========================================================================
rem  One-shot: configure + build + verify. Uses the same env vars as
rem  configure.bat (CLANG_DIR, GENERATOR, PLATFORM, CONFIG).
rem ==========================================================================

call "%~dp0configure.bat"
if errorlevel 1 exit /b 1

call "%~dp0build.bat"
if errorlevel 1 exit /b 1

exit /b 0