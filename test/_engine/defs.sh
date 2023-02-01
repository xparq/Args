export SPACE_TEST_VERSION=0.08

#
# Stuff here (still) depends on some settings prepared by `run_case`!
#

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
	test -n "$SPACE_DEBUG" && echo "----DBG: $*" >&2
}

# DEFAULTS
#-----------------------------------------------------------------------------

# This one should come preset:
if [ "${TEST_DIR}" == "" ]; then
	ERROR "TEST_DIR not defined! Do it before init'ing the rest!"
	return 6
fi

# Load the (optional) config:
test -e "${TEST_DIR}/ .cfg" && . "${TEST_DIR}/ .cfg"

# Temp. dir:
export TMP_DIR="${TEST_DIR}/tmp"
#!! Fall back on $TMP, $TEMP, /tmp etc...
if [ ! -d "${TMP_DIR}" ]; then
	mkdir -p  "${TMP_DIR}"
	if [ ! -d "${TMP_DIR}" ]; then
		ERROR "Couldn't create tmp dir '${TMP_DIR}'!:"
		return 1
	fi
	WARNING "${TMP_DIR} did not exist, created."
fi

# Set some "hard" defaults:
EXPECT_FILE_NAME=${EXPECT_FILE_NAME:-EXPECT}
TEST_CASE_SCRIPT_NAME=${TEST_CASE_SCRIPT_NAME:-CASE}
TEST_CASE_FILE_EXT=${TEST_CASE_FILE_EXT:-.case}


#-----------------------------------------------------------------------------
get_case_path(){
	local case_path=${TEST_DIR}/$@ #!!??Why did it work just fine also with $*?!

	# Not enough just to check for empty $1...:
	if [[ "`realpath \"${case_path}\"`" == "`realpath \"${TEST_DIR}\"`" ]]; then
		ERROR "Invalid test case path '${case_path}'!"
		return 1
	fi
	if [[ ! -e "${case_path}" ]]; then
		if [[ -e "${case_path}${TEST_CASE_FILE_EXT}" ]]; then
#DEBUG "Existing single-file TC script identified via auto-suffixing: ${case_path}"
			echo "${case_path}${TEST_CASE_FILE_EXT}"
			return 0
		else
			# ERROR "Test case \"$*\" not found!"
			return 1
		fi
	fi
	# Exists; check if test case: if file -> ends with .case, if dir -> dir/case exists
	if [[ -e "${case_path}/${TEST_CASE_SCRIPT_NAME}" ]]; then
		# Fine, path is already a case dir.
#DEBUG "Existing test script in TC dir identified: `realpath \"${case_path}\"`"
		# realpath is to strip off trailing slashes that would confuse
		# script path extension checks later, and also the makes!
		echo "`realpath \"${case_path}\"`"
		return 0
	else
		if [[ "${case_path%${TEST_CASE_FILE_EXT}}" != "${case_path}" ]]; then
#DEBUG "Existing single-file TC script identified as-is: ${case_path}"
			echo "${case_path}"
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
	echo ${name}
}

#-----------------------------------------------------------------------------
RUN(){
	if [ -z "$CASE" ]; then
		ERROR 'test case name not set (via CASE=...)!'
		return 3
	fi

	if [ "${case_variant_counter}" != "" ]; then
		case_variant_counter=$(($case_variant_counter + 1))
		echo "  Test [${case_variant_counter}]: $*" >&2
	else
		echo "  Test: $*" >&2
	fi

	# $* is the whole command to run, as is, but, alas, that won't work
	# if $1 contains spaces, so we need to take care of that here.
	# (Note: if $1 was pre-quoted, that would fail in even more hurtful ways! ;) )
	cmd=$1
	shift
	args=$*

	# Kludge to prepend ./ if no dir in cmd:
	normalized_dirpath=`dirname "${cmd}"`
	cmd=${normalized_dirpath}/${cmd}
DEBUG Cmdline ready to run: "$cmd" $args

	savecd=`pwd`
	cd "${TEST_CASE_DIR}"
	"$cmd" $args >> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
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
	echo "  Testing: $*"

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


get_make_flavor(){
	#!!This is allo really stupid yet, sorry...
	if [[ -n "${MAKE}" ]]; then
		if which "${MAKE}" >/dev/null; then
			echo "$MAKE"
		else
			ERROR "Make tool was set to '${MAKE}', but it can't be found!"
			return 1
		fi
	elif [[ "`get_toolset`" == "msvc" ]]; then
		echo nmake    # `-nologo` will be applied implicitly
	else
		echo gnumake
	fi

	return 0
}

get_toolset(){
	if [[ -n "$TOOLSET" ]]; then
		echo "$TOOLSET"
	elif [[ -n "$VCToolsVersion" || -n "$VCTOOLSVERSION" ]]; then #!!?? Must also check upper-cased, BusyBox(?) sometimes(?) converts env var names?!... :-o
		if which cl >/dev/null; then
			echo msvc
		else
			ERROR "The MSVC CLI env. is not setup propery! Forgot to run 'vcvars*.bat'?"
			return 1
		fi
	elif [[ -n "$W64DEVKIT" ]]; then
		echo "gcc/w64devkit"
	elif which gcc >/dev/null; then
		echo gcc
	else
		ERROR "Couldn't find any known build toolset!"
		return 2
	fi

	return 0
}


build_dir(){
# $1: build dir (will be chdired to for the duration of the build)
# Using "globals": $MAKE, $TOOLSET, $TEST_DIR, $_TEST_ENGINE_DIR
	local build_dir="$1"
	local add_makefile mkcmd dirsave result
	#! The makefiles themselves can't easily examine wildcard sources, so:
	cpp=`find "$build_dir" -maxdepth 1 -name '*.cpp' -print -quit`
		#!!That `-maxdepth 1` is pretty arbitrary, but this entire crude autobuild support is!...
	if [[ -z "${MAKE}" || -z "${cpp}" ]]; then
		# Nothing to do.
		return 0
	fi

	if [ "${MAKE}" == "nmake" ]; then
		#!BEWARE: /nologo, instead of -nologo, made Git-sh expand it to /full/path/nologo! :-o
		mkcmd="nmake -nologo"
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.nmake"
	else
		mkcmd="${MAKE}"
		add_makefile="-f ${_TEST_ENGINE_DIR}/asset/TC-Makefile.gnumake"
	fi

	# If the TC has a local makefile (note: single-line TCs share one!),
	# use that. Otherwise use a non-specific local Makefile, if that exists.
	# Else, use an internal default ($MAKE-specific) makefile.
	if [[ -e "${build_dir}/Makefile.${MAKE}" ]]; then
		mkcmd="${mkcmd} -f Makefile.${MAKE}"
	elif [[ ! -e "${build_dir}/Makefile" ]]; then   # use the internal if no local Makefile
		mkcmd="${mkcmd} ${add_makefile}"
	fi

	export CASE
	export TEST_CASE_DIR
	export TEST_DIR
	export TOOLSET=`get_toolset`
	export TEST_ENGINE_DIR="$_TEST_ENGINE_DIR"
	dirsave=`pwd`
		cd "${TEST_CASE_DIR}"
		${mkcmd}
		result=$?
	cd "${dirsave}"
	return $result
}


#-----------------------------------------------------------------------------
# LESSONS...:

# NOTE: this "thoughtful precaution" actually made it impossible to ever execute it...:
#	case_exe="\"./issue 10.exe\""
# E.g. an earlier comment from run_cmd:
#	$* didn't work, despite a) apparently proper-looking quoting in the echoed output,
#	and also b) running the exact same command successfully from the sh command line...
#	and even c) running it directly from here:
#	"./issue 10.exe" --long
# (Neither did any quoting, shift+quoting, backticking, $()ing, whatever... Which is now
# understandable, in hinsight, but was a nightmare with a dual CMD / sh mindset! :) )
