@echo off

set test=%1
if "%test%" == "" set test=args-test.cpp

set INCLUDE=../;%INCLUDE%
set out=tmp

if not exist "%out%" md %out%

cl /std:c++20 /W4 /wd4100 /EHsc /Fo%out%/ %test%
