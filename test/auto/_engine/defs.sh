# v0.01

#
# Stuff here depends on the settings prepared by run_case!
#

if [ "${TEST_DIR}" == "" ]; then
	echo "- ERROR: TEST_DIR not defined! Do it before init'ing the defs.!"
	return 7
fi

#!! Fall back on $TMP, $TEMP, /tmp etc...
TMP_DIR="${TEST_DIR}/tmp"
if [ ! -d "${TMP_DIR}" ]; then
	mkdir -p  "${TMP_DIR}"
	if [ ! -d "${TMP_DIR}" ]; then
		echo "- ERROR: Couldn't create tmp dir '${TMP_DIR}'!:"
		return 1
	fi
	echo "- WARNING: "${TMP_DIR}" did not exist, created."
	return 7
fi


get_case_path(){
	case_path=${TEST_DIR}/$*
	# Not enough just to check for empty $1...:
	if [ "`realpath \"${case_path}\"`" == "`realpath \"${TEST_DIR}\"`" ]; then
		echo "- ERROR: Invalid test case path '${case_path}'!"
		return 1
	fi
	if [ ! -e "${case_path}" ]; then
		if [ -e "${case_path}.case" ]; then case_path="${case_path}.case"; fi
	fi
	echo ${case_path}
}

get_case_name(){
	name=`basename "${*%.case}"`
	echo ${name}
}


RUN(){
	if [ "${CASE}" == "" ]; then
		echo "- ERROR: test case name not set (via CASE=...)!"
		return 3
	fi

	if [ "${case_variant_counter}" != "" ]; then
		case_variant_counter=$(($case_variant_counter + 1))
		echo "  Testing [${case_variant_counter}]: $*"
	else
		echo "  Testing: $*"
	fi

	# $* is the whole command to run, as is, but, alas, that won't work
	# if $1 contains spaces, so we need to take care of that here.
	# (Note: if $1 was pre-quoted, that would fail in even more hurtful ways! ;) )
	cmd=$1
	shift
	args=$*

	savecd=`pwd`
	cd "${TEST_CASE_DIR}"
	"$cmd" $args 1>> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
}

RUN_SH(){
#!!Doesn't work, maybe due to quoting problems?!
#!!	run sh -c \"$*\"
#!!	run sh -c "$*"

	if [ "${CASE}" == "" ]; then
		echo "- ERROR: test case name not set (via CASE=...)!"
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
	sh -c "$cmd $args" 1>> "${TMP_DIR}/${CASE}.out" 2>> "${TMP_DIR}/${CASE}.err"
	echo $? >> "${TMP_DIR}/${CASE}.retval"
	cd "${savecd}"
}


normalize_crlf(){
	dos2unix -u "$1"
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

