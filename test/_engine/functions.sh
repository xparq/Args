FATAL(){
# E.g. FATAL "Boops! Someone else did it!" 9
# The exit code is optional (default: 1).
# Obviously, only call this from where it's OK to catapult without cleanup!
	echo
	echo "ERROR: $1" >&2
	echo
	exit ${2:-1}
}
ERROR(){
	echo "- ERROR: $*" >&2
}
WARNING(){
	echo "- WARNING: $*" >&2
}
DEBUG(){
	test -n "$SPACE_DEBUG" && echo "....DBG: $*" >&2
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
	#!!Shouldn't it have escaped \"...\" as those realpaths above?!
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
			#!!Mostly untested! (Spaces, idempotency etc.)
			#!!Actually, it's NOT idempotent: prepends / to POSIX paths INCORRECTLY
			echo -n "/$p" | sed -e 's/\\/\//g' -e 's/:/\//'
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
	if [ -z "$CASE" ]; then
		ERROR 'test case name not set (via CASE=...)!'
		return 3
	fi

	if [ "${case_variant_counter}" != "" ]; then
		case_variant_counter=$(($case_variant_counter + 1))
		echo "  RUN [$case_variant_counter]: $*" >&2
	else
		echo "  RUN: $*" >&2
	fi

	# $* is the whole command to run, as is, but, alas, that won't work
	# if $1 contains spaces, so we need to take care of that here.
	# (Note: if $1 was pre-quoted, that would fail in even more hurtful ways! ;) )
	cmd=$1
	shift
	args=$*

	# Kludge to prepend ./ if no dir in cmd:
	normalized_dirpath=`dirname "$cmd"`
	cmd=$normalized_dirpath/$cmd
#DEBUG Cmdline to run: "$cmd" $args

	savedir=`pwd`
	cd "$TEST_CASE_DIR"
	"$cmd" $args >> "$TMP_DIR/${CASE}.out" 2>> "$TMP_DIR/${CASE}.err"
	echo $? >> "$TMP_DIR/${CASE}.retval"
	cd "$savedir"
}

#-----------------------------------------------------------------------------
SH(){
#!!	run sh -c \"$*\"
#!!	run sh -c "$*"
#!!	- didn't work, maybe due to quoting problems?!

	if [ -z "$CASE" ]; then
		ERROR 'test case name not set (via CASE=...)!'
		return 3
	fi
	echo "  SHELL: $*"

	# $* is the whole command to run, as is, but, alas, that won't work
	# if $1 contains spaces, so we need to take care of that here.
	# (Note: if $1 was pre-quoted, that would fail in even more hurtful ways! ;) )
	cmd=$1
	shift
	args=$*

	savecd=`pwd`
	cd "${TEST_CASE_DIR}"
	echo "sh -c \"$cmd $args\"" >> "${TMP_DIR}/${CASE}.cmd"
	sh -c "$cmd $args" >> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
}

#-----------------------------------------------------------------------------
EXPECT(){
	# Reset by the test case runner (run_case)!
	EXPECT=${EXPECT}$*
}

EXCEPT(){
	ERROR "Well, well... Been there, done that! ;)"
}

normalize_crlf(){
	dos2unix -u "$1" 2> /dev/null
}


#-----------------------------------------------------------------------------
get_make_flavor(){
	#!!This is really stupid yet, sorry...
	if [ -n "$MAKE" ]; then
		if which "$MAKE" >/dev/null 2>/dev/null; then
			echo "$MAKE"
		else
			ERROR "Make tool was set to '$MAKE', but it can't be found!"
			return 1
		fi
	elif [ "$TOOLSET" == "msvc" ]; then
		echo nmake    # `-nologo` will be applied implicitly
	else
		#!!Umm... GNU make then, anyone?
		echo gnumake
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

	MAKE=`get_make_flavor` || return $?

	#! The makefiles themselves can't easily examine wildcard sources, so:
	#!!FAILED using -name 'a b' (instead of "a b") with BB's find! :-o
	cpp=`find "$build_dir" -maxdepth 1 -name "$CASE.cpp" -print -quit`
	if [ -z "$cpp" ]; then
DEBUG "Build: No sources found -> nothing to do."
			return 0
	fi

	if [ "$MAKE" == "nmake" ]; then
		#!BEWARE: /nologo, instead of -nologo, made Git-sh expand it to /full/path/nologo! :)
		#!(Well, path mangling is "mostly" disabled now, but only via some tentative heuristics yet!)
		mkcmd="nmake -nologo"
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.nmake"
	else
		if [ "$MAKE" != "gmake" ] && [ "$MAKE" != "gnumake" ]; then
			WARNING "Using GNU-specific fallback makefile for '$MAKE'. Things may break!"
		fi
		mkcmd="${MAKE}"
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.gnumake"
	fi

	# If the TC has a local makefile (note: single-line TCs share one!),
	# use that. Otherwise use a non-specific local Makefile, if that exists.
	# Else, use an internal default ($MAKE-specific) makefile.
	if [ -e "$build_dir/Makefile.$MAKE" ]; then
		mkcmd="$mkcmd -f Makefile.$MAKE"
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
	export _SH_=`abspath_fixup ${_sh_:-$_SH_}`
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
		$mkcmd
		result=$?
	cd "$dirsave"
	return $result
}
