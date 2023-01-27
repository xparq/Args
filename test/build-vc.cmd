@echo off

set test=%1
set DIR_OFFSET=%2

rem This is to circumvent some of the CMD idiocy if %1 was alredy quoted:
SETLOCAL EnableDelayedExpansion
if "!test!" == "" set test=args-test.cpp

set INCLUDE=%DIR_OFFSET%../;%INCLUDE%
if "%TMP_DIR%" == "" (set out=tmp) else (set "out=%TMP_DIR%")
if not exist "%out%" md %out%

cl -nologo -std:c++20 -W4 -wd4100 -EHsc -Fo%out%/ %test%
