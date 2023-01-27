@echo off

if exist "%PROGRAMFILES%\Git\bin\sh.exe" (
	 "%PROGRAMFILES%\Git\bin\sh.exe" run_cases %*
) else (
	busybox sh run_cases %*
)
