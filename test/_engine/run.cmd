@echo off
rem Windows frontend for the real `run` (the main command script)

rem Here's some questionable heuristics for desperately trying to escape to
rem a proper shell, based on assumptions like folks using this are likely also
rem use Git, or bash from WSL, or they may just have a stray BusyBox instance
rem hanging around on the PATH somewhere...
rem
rem But it's a minefield... E.g. if things are not set up favorably, commands
rem like FIND.EXE wouldy come first on the PATH, and the sh instance that
rem ended up being picked up may use the wrong command executables...
rem Not to mention random subtle incompatibilities that could break things
rem silently... Not exactly a textbook premise for test frameworks, is it?! :)
rem
rem Alternatively, we might as well just ship a BB instance eventually...
rem It's just so big!... ;) Well then, maybe we can download one on-the-fly!)


rem Allow presetting _sh_...
rem NOTE: not using %SHELL%, as the "fake shells" will overwrite it e.g. to
rem /bin/sh or something equally useless on Windows.
rem !!
rem !! BTW, it should be clear that this is just a Win-specific kludge!
rem !!
rem if not "%_sh_%" == "" goto ready
rem !! FFS!... Wow... Can't quote here, if the value is already quoted!... :)
rem !! But then x%_sh_%x==xx could also fail, due to spaces!... :-o Incredible! :D
rem So, this is how I have to check if it's been set:
(set _sh_ 2>nul >nul) && goto ready

rem !! Should start with a "local" (shipped or prev. downloaded) BB, and fall
rem    back to less and less compatible options...

rem NOTE: The `set ...` quoting has to be the way done below to support spaces in
rem       the paths *AND* commands that are not just a path but also have args.!
rem !!?? Is there a nicer way for this else-if chain (given that `if` can't run commands)?
"%~dp0busybox" --help           2>nul >nul && (set _sh_="%~dp0busybox" sh)        && goto endif

rem Maybe the host project has BusyBox? NOTE: We're still better off with that on Windows
rem than the various other bash clones, as that's what I've been testing all the time!
busybox --help           2>nul >nul && (set "_sh_=busybox sh")        && goto endif

rem NOTE: We can't use Git's sh version that's typically on the PATH (...Git/usr/bin/sh.exe)
rem       as it won't find its fellow POSIX commands! :-o
"%PROGRAMFILES%\Git\bin\sh" --help      2>nul >nul && (set _sh_="%PROGRAMFILES%\Git\bin\sh")      && goto endif
"%PROGRAMFILES(X86)%\Git\bin\sh" --help 2>nul >nul && (set _sh_="%PROGRAMFILES(X86)%\Git\bin\sh") && goto endif
rem !! This is way too random, should only try as a last resort, even after downloading BB failed!
rem sh --help                               2>nul >nul && (set _sh_=sh)                               && goto endif
rem !! NOT YET! The scripts aren't ready yet...: bash --help 2>nul >nul && set "_sh_=bash" && goto endif
rem ! This is attempted after a failed BB download: busybox --help 2>nul >nul && set "_sh_=busybox" && goto endif
set "_sh_="

:endif

(set _sh_ 2>nul >nul) && goto ready

rem If still nothing, we could try downloading a busybox.exe!... ;-o
rem Oh yeah..., except:
rem - PS scripting seems to be disabled by deafult in Windows!
rem   But... Fortunately (but even more surprisingly), it means nothing: it can be overridden indiscriminately! :D
rem ! Also: DO NOT run it in our current console window, because it would fuck up the layout!... :-ooo
rem ! And don't forget /wait to make it synchronous, for checking its result!
set _BB_IN_SPACE_=%~dp0busybox.exe
start /wait /min PowerShell -ExecutionPolicy Bypass -File %~dp0download_file.ps1 "https://frippery.org/files/busybox/busybox.exe" "%_BB_IN_SPACE_%"
rem if not errorlevel 1 goto endif
rem - Perhaps more robust and on the point:
if not exist "%_BB_IN_SPACE_%" (

	echo - ERROR: Failed to download BusyBox^!

	busybox sh --help 2>nul 1>nul && (
		set _sh_=busybox sh
			rem See at the end, why not quoting as set "name=val"!
		echo ...but found one on the PATH, using it:
		where busybox
		goto ready
	)

	echo Giving up.
	exit 1
)

set _sh_="%_BB_IN_SPACE_%" sh
	rem See at the end, why not quoting as set "name=val"!
echo Using a downloaded BusyBox ^("%_BB_IN_SPACE_%"^) for shell...

:ready
set BB_GLOBBING=0
echo Riding %_sh_%...

rem NOTE: _sh_ can be more than just a single file path (i.e. a command phrase, like "busybox sh")!
rem       So it can't be quoted here, because it would then be treated as a filename...
rem       So, the cmd filename itself ought to have already been quoted (see above, eveywhere...)! :-o
%_sh_% %~pd0run %*
