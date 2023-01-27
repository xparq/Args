# v0.01

#
# Stuff here depends on the settings prepared by run_case!
#


ERROR(){
	echo "- ERROR: $*" >&2
}

WARNING(){
	echo "- WARNING: $*" >&2
}


if [ "${TEST_DIR}" == "" ]; then
	ERROR "TEST_DIR not defined! Do it before init'ing the defs.!"
	return 6
fi

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


get_case_path(){
	case_path=${TEST_DIR}/$*
	# Not enough just to check for empty $1...:
	if [ "`realpath \"${case_path}\"`" == "`realpath \"${TEST_DIR}\"`" ]; then
		ERROR "Invalid test case path '${case_path}'!"
		return 1
	fi
	if [ ! -e "${case_path}" ]; then
		if [ -e "${case_path}.case" ]; then
			case_path="${case_path}.case"
		else
			ERROR "Test case '${case_path}' not found!"
			return 1
		fi
	fi
	echo ${case_path}
}

get_case_name(){
	name=`basename "${*%.case}"`
	echo ${name}
}


RUN(){
	if [ "${CASE}" == "" ]; then
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

	savecd=`pwd`
	cd "${TEST_CASE_DIR}"
	"$cmd" $args >> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
}

SH(){
#!!	run sh -c \"$*\"
#!!	run sh -c "$*"
#!!	- didn't work, maybe due to quoting problems?!

	if [ "${CASE}" == "" ]; then
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
#	echo "sh -c \"$cmd $args\"" >> "${TMP_DIR}/${CASE}.cmd"
	sh -c "$cmd $args" >> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
}


check_make_flavor(){
	if [[ -n "${MAKE}" ]]; then echo "${MAKE}"; return 0; fi

	#! Must also check upper-cased, BusyBox(?) sometimes(?) converts env var names!...
	if [[ -n "${VisualStudioVersion}" || -n "${VISUALSTUDIOVERSION}" ]]; then
		echo nmake
			# `/nologo` will be applied implicitly
	else
		echo gnumake
			# Can't share Makefiles tho, so this dispatching is XOR, not OR... :-/
	fi
}


normalize_crlf(){
	dos2unix -u "$1" 2> /dev/null
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
