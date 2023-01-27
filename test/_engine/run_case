#!/bin/sh

TEST_DIR=${TEST_DIR:-`pwd`}
#echo Test dir is: \"$TEST_DIR\"

. _engine/defs.sh
retval=$?; if [ "$retval" != "0" ]; then exit $retval; fi

case_path=`get_case_path $1`
retval=$?; if [ "$retval" != "0" ]; then exit $retval; fi

#!
#! Now we have a path to the test case, but it can be either a single file
#! or a dir. This script must handle the differences.
#!

CASE=`get_case_name ${case_path}`
retval=$?; if [ "$retval" != "0" ]; then exit $retval; fi

echo; echo CASE \"${CASE}\"
	# (at '${case_path}')

if [ ! -d  "${case_path}" ]; then
	case_script="${case_path}"
	TEST_CASE_DIR=`dirname "${case_path}"`
else
	#!!Do better than hardcodings like this:
	case_script="${case_path}/case"
	TEST_CASE_DIR=${case_path}
fi

if [ ! -f "${case_script}" ]; then
	echo "- ERROR: test case script '${case_script}' not found!"
	return 1
fi

#
# Run a test case via a .case definition...
#
#!!?? Should also support running any arbitrary exe directly, letting it
#!!?? not interfere with the test tools at all; in that case a separate script
#!!?? should tell what the expected results are (not the .case file itself).
#!!   
#!!   Could always be just run as test case variant, which are native exes anyway!
#!!   

#
#!! Depending on whether this is a native exe or an instrumented .case script,
#!! the output needs to be handled differently: full redirection for 
#

# Work file layout... (Preparing the exp. results file usually requires running the case first!)
outfile="${TMP_DIR}/${CASE}.out"
errfile="${TMP_DIR}/${CASE}.err"
retfile="${TMP_DIR}/${CASE}.retval"

# Reset the work files...
test -f "${outfile}" && rm "${outfile}"
test -f "${errfile}" && rm "${errfile}"
test -f "${retfile}" && rm "${retfile}"


# Finally, run the case...
failed=0
case_variant_counter=0
. "${case_script}"

if [ "$?" != "0" ]; then
	echo "- ERROR: test script failed with unexpected error! Aborting."
	exit 99
fi

# Find or dyn. regenerate the expfile if defined in a .case script
if [ -f         "${TEST_CASE_DIR}/expect" ]; then
	expfile="${TEST_CASE_DIR}/expect"
# NOTE:
# In a mixed "GNU tools on Windows" env (like mine) diff may not be able
# to ignore CR/LF differences, so we need to strip those manually.
# (-> e.g.: https://github.com/skeeto/w64devkit/issues/45)
# One easy way is to normalize the newlines in *both* the output
# and the user-supplied "expect" file -- which means we'd need to
# "redirect" that too, the same way we do with an EXPECT clause.
# (Because obviously we won't touch the opriginal file.)
	kludge_expf="${TMP_DIR}/${CASE}.expected"
	# Better do this together with outfile, later below:
	# tr -d '\015' < ${expfile} > "${kludge_expf}"
	cp "${expfile}" "${kludge_expf}"
	expfile=${kludge_expf}
else
	expfile="${TMP_DIR}/${CASE}.expected"
	# $EXPECT must be quoted to preserve newlines.
	# And mind the -n, too:
	echo -n "${EXPECT}" > "${expfile}"
fi

# Normalizing these would prevent precision-testing some whitespace handling, but the
# CR/LF mismatches is a bigger issue anyway than what we could handle on this level...
normalize_crlf "${expfile}"
normalize_crlf "${outfile}"

#echo diff -b "${outfile}" "${expfile}"
     diff -b "${outfile}" "${expfile}"

if [ $? == 0 ]; then
	echo "  OK."
else
	echo "  -------------------------- FAILED! --------------------------"
	set failed=1
fi

exit ${failed}
