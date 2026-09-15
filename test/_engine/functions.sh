FATAL(){
# E.g. FATAL "Boops! Someone else did it!" 9
# The exit code is optional (default: 1).
# Obviously, only call this from where it's OK to catapult without cleanup!
	echo
	echo "FATAL ERROR: $1" >&2
	echo
	exit ${2:-1}
}
ERROR(){
	echo "- ERROR: $*" >&2
}
WARNING(){
	echo "- WARNING: $*" >&2
}
NOTE(){
	echo "- NOTE: $*" >&2
}
DEBUG(){
	test -n "$SPACE_DEBUG" && echo -e "....DBG: $*" >&2
}

CREATE_EMPTY(){
	if [ ! -z "$1" ]; then echo -n "" > "$1"; fi
}

#-----------------------------------------------------------------------------
get_case_path(){
	local case_path=$TEST_DIR/$@ #!!??Why did it work just fine also with $*?!

	# Not enough just to check for empty $1...:
	if [ "`realpath \"$case_path\"`" == "`realpath \"$TEST_DIR\"`" ]; then
		ERROR "Invalid test case path \"$case_path\"!"
		return 1
	fi
	if [ ! -e "$case_path" ]; then
		if [ -e "${case_path}${TEST_CASE_FILE_EXT}" ]; then
#DEBUG "Existing single-file TC script identified via auto-suffixing: ${case_path}"
			echo "${case_path}${TEST_CASE_FILE_EXT}"
			return 0
		else
			# ERROR "Test case \"$*\" not found!"
			return 1
		fi
	fi
	# Exists; check if test case: if file -> ends with .case, if dir -> dir/case exists
	if [ -e "$case_path/$TEST_CASE_SCRIPT_NAME" ]; then
		# Fine, path is already a case dir.
#DEBUG "Existing test script in TC dir identified: `realpath \"${case_path}\"`"
		# realpath is to strip off trailing slashes that would confuse
		# script path extension checks later, and also the makes!
		echo "`realpath \"${case_path}\"`"
		return 0
	else
		if [ "${case_path%$TEST_CASE_FILE_EXT}" != "$case_path" ]; then
#DEBUG "Existing single-file TC script identified as-is: $case_path"
			echo "$case_path"
			return 0
		fi
	fi

	# ERROR "Test case \"$*\" not found!"
	return 1
}

#-----------------------------------------------------------------------------
get_case_name(){
	#! Quotes are not needed for the suffix (unlike the \"...\" for realpath above);
	#! I think they would interfere with the globbing (I forgot)...
	name=`basename "${*%$TEST_CASE_FILE_EXT}"`
	echo $name
}

sh_wants_posix_paths(){
	[ -n "$PWD" ] && [ "${PWD#/}" != "$PWD" ] && return 0
	return 1
}

get_path_sep(){
#!! Umm, OK, yeah, but... Well... On Windows, but with an env. where the shell does
#!! path conversion from C:/... to /c/..., then just switching path-sep. won't help!

	# Can't just rely on "Is it Windows?", as MinGW etc. will use UNIX-like seps.
	# Can't rely on -n $SHELL either, as it would still differ wildly...
	# But a possibly working heuristic could be checking the first char of
	# $PWD, and if it's '/' then use ':'...
#	if [ -n "$SYSTEMROOT" ] && [ -n "$SYSTEMDRIVE" ]; then
	if sh_wants_posix_paths; then
		echo -n ":"
	else
		echo -n ";"
	fi
}

# Git's MinGW tools, and who knows what else, fails to convert $0 to /c/...
# despite faking everything else, so it's impossible to add to the PATH as-is. :-(
# Git's `realpath` won't fix it either.
# So, in case there's a mismatch with the expected "native" format...

abspath_fixup(){
#!!Only for the (CYGWIN? MSYS?) /c/abc... format, not for generic /usr/...,
#!!     as the Windows mount point for / is unknown here!
#!!?? Would it be best to just turn off any path mangling (MSYS2_ARG_CONV_EXCL=*)?
#!!   -> https://www.msys2.org/wiki/Porting/#user-content-filesystem-namespaces
#!!MIGHT NOT WORK FOR REL PATHS!
#! The conversions are [!!SUPPOSEDLY!!] idempotent, i.e. do nothing if the path is already
#! in the requested format! !!TEST!!
# (Returns the (possibly converted) path unquoted, of course.)
#https://stackoverflow.com/a/13701495/1479945

	local p="$*"
	if sh_wants_posix_paths; then
		if which cygpath >/dev/null 2>/dev/null; then
			cygpath -u "$p" 2>/dev/null
		else
			# Last-ditch manual c:\... -> /c/... on Windows
			if [ "$OS" = "Windows_NT" ];  then
				#!!Mostly untested! (Spaces, idempotency etc.)
				#!!Actually, it's NOT idempotent: prepends / to ALREADY POSIX paths INCORRECTLY
				echo -n "/$p" | sed -e 's/\\/\//g' -e 's/:/\//'
			else
				echo "$p"
			fi
		fi
	else
		# Alas, mixed mode (-m) replaces quotes with a some plceholder char []!
		# Oh, but not only that: it also replaces the colon afrer "X:! :-o WTF?!
		# Well then, the path is completely unusable that way... Congratulations.
#		if which cygpath >/dev/null 2>/dev/null; then
#			cygpath -w "$p" 2>/dev/null
#		else
# "mixed" mode:		echo -n "$p" | sed -E -e 's|^/(.)/|\1:/|'
			echo -n "$p" | sed -E -e 's|^/(.)/|\1:\\|' -e 's|/|\\|g'
##			#!!Untested!! Windows path, but with forward slashes:
##			echo -n "$p" | sed -e 's/^\///' -e 's/\//\//g'
## WTF is this (from that SO page):                                   # -e 's/^./\0:/'
#		fi
	fi
}

#-----------------------------------------------------------------------------
RUN(){
#	if [ ! -z "$ABORTED" ] && [ "$ABORTED" != "$_TENTATIVE_ABORT_" ]; then return $ABORTED; fi
	if [ ! -z "$ABORTED" ]; then return $ABORTED; fi

	if [ -z "$CASE" ]; then # assert
		ERROR 'test case name not set (via CASE=...)!'
		return 3
	fi

	if [ "${case_variant_counter}" != "" ]; then
		case_variant_counter=$(($case_variant_counter + 1))
		echo "  RUN [$case_variant_counter]: $*" >&2
	else
		echo "  RUN: $@" >&2
	fi

	# $* is the whole command to run, as is, but, alas, that won't work
	# if $1 contains spaces, so we need to take care of that here.
	# (Note: if $1 was pre-quoted, that would fail in even more hurtful ways! ;) )
#!!... I think there's no good way to solve this in sh.
	cmd=$1
	shift
	args=$@
#!! Not even desperate attempts like this can help: it would just push the
#!! explicit quotes right down the throat of the recipient ($cmd)... :-/
#	requoted=
#	while [ -n "$1" ]
#	do
#		requoted="$requoted\"$1\" "
#			# This will also leave a trailing space, but that's the least of our problems...
#		shift
#	done
#	args=$requoted
#echo "args = $args"
		if [ -z "$RUN_WITH_PATH_LOOKUP" ]; then
			# Prepend ./ if no dir in cmd (see also #53):
			explicit_dirpath=`dirname "$cmd"`
			cmd=$explicit_dirpath/`basename "$cmd"`
		fi
DEBUG Cmdline to run: "$cmd" $args
		echo "\"$cmd\" $args"    > "$cmdfile"
# This has been the only way to get at least \"arg with space\" work on Windows + Git Bash:
		sh "$cmdfile" >> "$outfile" 2>> "$errfile"
			# Alas, sh -e would be too hamfisted, and would probably prevent testing !0 exit codes...
#		"$cmd" $args >> "$outfile" 2>> "$errfile"
		ret=$?
#		echo $ret >> "$retfile"

	# Can't do this in run_test, as that only sees the overall results,
	# not the individual test steps internal to the test case!
	case "$EXPECT_ERROR" in
	ignore)	;;
	warn)	test $ret -ne 0 && NOTE "Command returned nonzero exit code!" ;;
	0)	if [ $ret != 0 ]; then FAIL; fi ;;
	[0-9]*)	if [ $ret != $EXPECT_ERROR ]; then NOTE "INCORRECT EXIT CODE: $ret"; FAIL $ret; fi ;;
	*)	if [ -z "$EXPECT_ERROR" ] && [ $ret == 0 ]; then FAIL; fi ;;
	esac

#	if [ "$ABORTED" == "$_TENTATIVE_ABORT_" ]; then ABORTED=; fi
	return $ret
}

#-----------------------------------------------------------------------------
SH(){
#	if [ ! -z "$ABORTED" ] && [ "$ABORTED" != "$_TENTATIVE_ABORT_" ]; then return $ABORTED; fi
	if [ ! -z "$ABORTED" ]; then return $ABORTED; fi

#!!	run sh -c \"$*\"
#!!	run sh -c "$*"
#!!	- didn't work, maybe due to quoting problems?!

	if [ -z "$CASE" ]; then
		ERROR 'test case name not set (via CASE=...)!'
		return 3
	fi
	echo "  SHELL: $@"

	cmd=$1
	shift
	args=$@ #! This is where spaces in quoted args die... :-/
	        #! Maybe because BB_GLOBBING is off? Had they survived:
	#! ...we'd need to re-quote them so they could also survive
	#! the shell invocation command line later below:
	#for a in $args; do qargs="$qargs \"$a\"" ; done
	#echo QUOTED ARGS: $qargs
	#!!Alas, that probably wouldn't help either, after all... See at RUN()!

DEBUG "SH args: [$args]"

		echo "sh -c \"$cmd $args\"" > "$cmdfile"
		sh -c "$cmd $args" >> "$outfile" 2>> "$errfile"
		ret=$?
#		echo $ret >> "$retfile"

	# Can't do this in run_test, as that only sees the overall results,
	# not the individual test steps internal to the test case!
	case "$EXPECT_ERROR" in
	ignore)	;;
	warn)	test $ret -ne 0 && NOTE "Command returned nonzero exit code!" ;;
	0)	if [ $ret != 0 ]; then FAIL; fi ;;
	[0-9]*)	if [ $ret != $EXPECT_ERROR ]; then NOTE "INCORRECT EXIT CODE: $ret"; FAIL $ret; fi ;;
	*)	if [ -z "$EXPECT_ERROR" ] && [ $ret == 0 ]; then FAIL; fi ;;
	esac

#	if [ "$ABORTED" == "$_TENTATIVE_ABORT_" ]; then ABORTED=; fi
	return $ret
}

#-----------------------------------------------------------------------------
EXPECT(){
	# Reset by the test case runner (run_case)!
	EXPECT=${EXPECT}$*
}
EXCEPT(){
	FATAL "Well, well... Been there, done that!... (Check the spelling of 'EXPECT'! ;) )"
}


#-----------------------------------------------------------------------------
# `EXPECT_ERROR`   - the command is expected to fail
# `EXPECT_ERROR x` - the command is expected to fail with error code x
# `EXPECT_ERROR 0` - no error is expected, the command must succeed
# `EXPECT_ERROR warn` - note if a cmd. fails, but do not fail the case
# `EXPECT_ERROR ignore` - disable checking (default)
#
# It must come before the RUN/SH (exec) statement(s) it belongs to!
# Each further exec statement in the test case will be affected, so adjust
# or reset accordingly, as needed (e.g. `EXPECT_ERROR ignore`).
#
EXPECT_ERROR(){
	# Reset by the test case runner (run_case)!
	EXPECT_ERROR=$1
#	echo $1 > $retexpfile
}

FAIL(){
	FORCED_RESULT=${1:-1}
}

PASS(){
	FORCED_RESULT=0
}


# Can't really abort this way directly (without also terminating the whole
# runner script); the second best is trying to propagate a magic ABORT code...
#export _TENTATIVE_ABORT_=108
export _ABORT_=109
ABORT(){
	ABORTED=$_ABORT_
	# Legacy fallback trigger, for some extra chances of doom...:
	FORCED_RESULT=$_ABORT_
}

normalize_crlf(){
	dos2unix -u "$1" 2> /dev/null
}


#-----------------------------------------------------------------------------
get_make_flavor(){
	#!! This is pretty simplistic yet, sorry...

	# `MAKE` is set?
	if [ -n "$MAKE" ]; then
		# Try directly first, as-is, because it may have a path, and
		# the "get the first word" attempt, in case it also has options,
		# would butcher the path if it has spaces! :-/
		# This would still fail if it has BOTH options and a path with spaces,
		# but I know no cure for that here, sorry. :-/
		if command -v "$MAKE" >/dev/null 2>/dev/null; then
			echo "$MAKE"
			return 0
		else
			# Now try the first-word thing, as `make -s -p` is still a
			# pretty likely use case, and it would also work even with
			# a path WITHOUT spaces...
			make_cmd=${MAKE%% *}
			if command -v "$make_cmd" >/dev/null 2>/dev/null; then
				echo "$MAKE"
				return 0
			else
				ERROR "MAKE was set to '$MAKE', but it can't be found!"
				return 1
			fi
		fi
	fi

	# Not set, try something...
	if [ "$TOOLSET" = "msvc" ]; then
		#!! This is pretty much hardcoded, as we're gonna call it directly
		#!! anyway, with the MSVC+NMake-specific makefile...
		#!! If it doesn't exist, the MSVC setup is broken anyway(?), and also,
		#!! a parent script would hard-fail with an error telling the reason.
		echo nmake    # `-nologo` will be added to it later
	elif command -v make >/dev/null 2>/dev/null; then
		echo make
	elif command -v gnumake >/dev/null 2>/dev/null; then
		echo gnumake
#!!	elif #!! Try busybox-w32's builtin PDPMake...
#!!		...
	else
		ERROR "MAKE was not set, and neither 'make' nor 'gnumake' was found!"
		return 1
	fi

	return 0
}

#-----------------------------------------------------------------------------
get_toolset(){
#!! BB `which` differs from the original GNU version (e.g. at Git), which just can't shut up...

	if [ -n "$TOOLSET" ]; then
#DEBUG "$TOOLSET"
		echo "$TOOLSET"
	elif [ -n "$VCToolsVersion" ] || [ -n "$VCTOOLSVERSION" ]; then #!!?? Must also check upper-cased, BusyBox(?) sometimes(?) converts env var names?!... :-o
		if which cl >/dev/null 2>/dev/null; then
#DEBUG msvc
			echo msvc
		else
			ERROR "The MSVC CLI env. is not setup propery! Forgot to run 'vcvars*.bat'?"
			return 1
		fi
	elif [ -n "$W64DEVKIT" ]; then
#DEBUG "gcc/w64devkit"
		echo "gcc/w64devkit"
	elif which gcc >/dev/null 2>/dev/null; then
#DEBUG gcc
		echo gcc
	else
		ERROR "Couldn't find any known build toolset!"
		return 2
	fi

#DEBUG "(returning 0)"
	return 0
}

#-----------------------------------------------------------------------------
build_dir(){
# $1: build dir (will be chdired to for the duration of the build)
# Using "globals": _TEST_ENGINE_DIR, TOOLSET, TEST_NAME, TEST_DIR, CASE, TEST_CASE_DIR
#
# This is recommended to be called by `init_once.sh` for the root TC (i.e.
# for preparing the whole set), and then per-case by `run_case`.
#
# Since the build target is the TC name ($CASE), it would build different
# things for the root case vs. any individual top-level/single-file TCs
# sharing the same (root) dir. (Albeit it's messy to have dangling sources
# (and then even executables) for the top-level "single-file" cases -- kinda
# defeating their single-filedness... ;) )
#
	local build_dir="$1"
	local add_makefile mkcmd dirsave result

	#!! -> #91...:
	MAKE=`get_make_flavor` || return $?
	#!! This would still fail with spaces in the path! :-/
	#!! Implementing #91 is really unavoidable!!
	MAKE_TOOL=$(basename "${MAKE%% *}")
	#!!MAKE_CMD="$MAKE"

	#! The makefiles themselves can't easily examine wildcard sources, so:
	#!!FAILED using -name 'a b' (instead of "a b") with BB's find! :-o
	cpp=`find "$build_dir" -maxdepth 1 -name "$CASE.cpp" -print -quit`
		# NOTE: This is (as all other such commands) case-sensitive,
		# while the actual file names aren't on Windows (NTFS), so
		# sloppiness would lead to errors like #74!...
	if [ -z "$cpp" ]; then
DEBUG "Build: No sources found -> nothing to do."
			return 0
	fi


	if [ "$MAKE_TOOL" = "nmake" ]; then
		#!BEWARE: /nologo, instead of -nologo, made Git-sh expand it to /full/path/nologo! :)
		#!(Well, path mangling is "mostly" disabled now, but only via some tentative heuristics yet!)
		if [ "$MAKE" = "nmake" ]; then
			mkcmd="nmake -nologo"
		else
			# $MAKE is already not just `nmake`, so dont' mess with it!
			mkcmd="$MAKE"
		fi
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.nmake"
	else
		if [ -z "$("${MAKE%% *}" --version 2>/dev/null | grep GNU)" ]; then
			WARNING "Using GNU-specific makefile with possibly non-GNU '$MAKE'! The build would likely fail!"
		fi

		# Detect BusyBox-w32's built-in make, and avoid it!
		if [ "$(which "${MAKE%% *}" 2>/dev/null)" = "make" ]; then
			WARNING "'make' seems to be a BusyBox applet, not GNU Make! Overriding it..."

			#!! MAKE="full/path/make.exe" WORKED, confirming the issue...
			#!! NOPE: MAKE="command -p $MAKE"
			#!! NOPE: MAKE="env $MAKE"
			#!! Whoa! This also worked, thankfuilly:
			export BB_OVERRIDE_APPLETS=make
			#!! But we could do even better; or at least this one would be more fun:
			#!!MAKE="$MAKE.exe"
			#!! NOTE: But... $MAKE may be a cmdline with opts... :-/ After #91 though
			#!! that issue should vanish, and the .exe hack would be back in the game! ;)
		fi

		mkcmd="${MAKE}"
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.gnumake"
	fi

	# If the TC has a local makefile (note: single-line TCs share one!),
	# use that. Otherwise use a non-specific local Makefile, if that exists.
	# Else, use an internal default ($MAKE-specific) makefile
	#!!
	#!! But... $MAKE may have path and/or options!... -> #91 (Add MAKE_FLAGS...)
	#!! Here `basename` should at least deal with the path issue though:
	#!!
	if [ -e "$build_dir/Makefile.$(basename $MAKE)" ]; then
		mkcmd="$mkcmd -f Makefile.$(basename $MAKE)"
	elif [ ! -e "$build_dir/Makefile" ]; then   # use the internal if no local Makefile
		mkcmd="$mkcmd $add_makefile"
	fi

	export TEST_NAME
	export TEST_DIR
	export CASE
	export TEST_CASE_DIR
	export TOOLSET
	export TEST_ENGINE_DIR="$_TEST_ENGINE_DIR"

	# This "resanitizing" can help bridge some incompatibilities across toolsets/sh
	# versions (e.g. sh called from gnumake under MinGW & friends):
	#! Also mind the frustrating var name uppercasing by BB... :-/
#echo "_sh_ before fixup: [$_sh_]"
#echo "_SH_ before fixup: [$_SH_]"
	export _SH_=`abspath_fixup ${_sh_:-$_SH_}`
#echo "_SH_ AFTER fixup: [$_SH_]"
		#!!But this would fuck up _SH_ for the rest of the process back here! :-o
		#!!So we should either save/restore it, or pass it to the build
		#!!process with a different name!

	#!! Should revert all the unixified dirs for the native Windows build tools, too! :-o
	#!! (Fortunately there's no "windows toolset on Linux converting posix paths to win for emulation" case! :) )
	export _TMP_DIR=`abspath_fixup ${TMP_DIR}`
	export _TEST_DIR=`abspath_fixup ${TEST_DIR}`
	export _TEST_CASE_DIR=`abspath_fixup ${TEST_CASE_DIR}`

	dirsave=`pwd`
		cd "$TEST_CASE_DIR"
DEBUG "Launching $MAKE (as '$mkcmd') for dir '$TEST_CASE_DIR'..."
#!! Alas, the built-in busybox-w32 make would choke on this:
#!!DEBUG "'MAKE --version says: $($MAKE --version)"
		$mkcmd
		result=$?
	cd "$dirsave"
	return $result
}
