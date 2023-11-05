export SPACE_TEST_VERSION=0.14

#! Don't forget to export everything (non-local), as the per-case runs will be
#! separate processes! (WHY, BTW??)

#export _TEST_ENGINE_DIR=${_TEST_ENGINE_DIR:-`dirname $0`}
	#!BEWARE: this $0 would ONLY work if we were the root script! :-o
	#!Which wouldn't make much sense, so... Better just to require it!
if [ -z "$_TEST_ENGINE_DIR" ]; then
	echo "- ERROR: _TEST_ENGINE_DIR must be set before calling init_once.sh!"
	exit 101
fi
# ...but it's not required to have already been normalized, so:
_TEST_ENGINE_DIR=`realpath ${_TEST_ENGINE_DIR}`
. $_TEST_ENGINE_DIR/functions.sh

# This should also come preset, but we can fallback to CWD:
export TEST_DIR=${TEST_DIR:-`pwd`}
#DEBUG "Test dir is: \"$TEST_DIR\""
if [ ! -e "$TEST_DIR" ]; then FATAL "TEST_DIR \"$TEST_DIR\" doesn't seem to exist!" 102; fi

export TMP_DIR="$TEST_DIR/.tmp"
#!! Fall back to $TMP, $TEMP, /tmp etc...
if [ ! -d "$TMP_DIR" ]; then
	mkdir -p  "$TMP_DIR"
	if [ ! -d "$TMP_DIR" ]; then
		FATAL "Couldn't create tmp dir '$TMP_DIR'!:" 103
	fi
	WARNING "$TMP_DIR did not exist, created."
fi


# Add (prepend! -> #36) the engine dir to the path
#-----------------------------------------------------------------------------
p=`abspath_fixup $_TEST_ENGINE_DIR`
PATH="$p`get_path_sep`$PATH"
# ^^^ Yeah, nice, except this doesn't help with running scripts directly with
#     `sh script.sh`, as PATH lookup is not required (even discouraged) for that!
#     Fortunately, sourcing works, i.e. `sh -c ". build.sh"` *does* force PATH lookup! ;-o

# CFG + DEFAULTS
#-----------------------------------------------------------------------------

# Load the (optional) config:
test -e "$TEST_DIR/ .cfg" && . "$TEST_DIR/ .cfg"

# Set some "hard" defaults:
export TEST_NAME=${TEST_NAME:-test}
export EXPECT_FILE_NAME=${EXPECT_FILE_NAME:-EXPECT}
export TEST_CASE_SCRIPT_NAME=${TEST_CASE_SCRIPT_NAME:-SCRIPT}
export TEST_CASE_FILE_EXT=${TEST_CASE_FILE_EXT:-.case}

# "Soft" defaults:
export TOOLSET=`get_toolset`

# ROOT-LEVEL BUILD
#-----------------------------------------------------------------------------
export CASE="$TEST_NAME"
export TEST_CASE_DIR="$TEST_DIR"
build_dir "$TEST_CASE_DIR" || FATAL "Failed to build the test case!" $?
