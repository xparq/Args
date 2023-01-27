@echo off

if exist "%PROGRAMFILES%\Git\bin\sh.exe" (
	set _sh_="%PROGRAMFILES%\Git\bin\sh.exe"
) else (
	set _sh_=busybox sh
	rem (No check: it's a last-ditch fallback.)
)

%_sh_% run_cases %*
