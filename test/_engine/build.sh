#!/bin/sh
#!!
#!! NOTE: Git sh insists on "helpfully" screwing around with paths here... :-/
#!! E.g. "adjusting" "C:/sz/prj/Space_Test/test/tmp"
#!!               to "C:\sz\prj\Space_Test\test\C:\Program Files\Git\sz\prj\Space_Test\test\tmp\". :-o
#!! Fascinating... :-/
#!! Fortunately, prefixing commands with MSYS_NO_PATHCONV=1 helps.
#!!?? Or perhaps even https://www.msys2.org/wiki/Porting/#user-content-filesystem-namespaces:
#!!?? "Setting MSYS2_ARG_CONV_EXCL=* prevents any path transformation."?
MSYS2_ARG_CONV_EXCL=*

# "$1" - source to compile; default: $TEST_NAME
#! NOTE: Any individual $n args are expected to have been _quoted_ in the makefiles before passed to this script!

#echo ARGS: $@
#echo TOOLSET: $TOOLSET

#!!...
     exe="${1:-$TEST_NAME}"
     exe="${exe%.cpp}.exe"
#echo "exe: $exe"
#!!...
main_src="${1:-$TEST_NAME}"
main_src="${main_src%.exe}.cpp"
#echo "src: $main_src"

outdir="${TMP_DIR:-tmp}"
mkdir -p "$outdir"

case $TOOLSET in
msvc)
	export INCLUDE="$_TEST_DIR;$INCLUDE"
	#https://stackoverflow.com/a/73220812/1479945
	MSYS_NO_PATHCONV=1 cl -nologo -std:c++20 -W4 -wd4100 -EHsc "-Fo$outdir/" "$main_src"
	# ^^^ Redundant now, I guess, with `MSYS2_ARG_CONV_EXCL=*`, but keeping as a memento... ;)
	;;
gcc*)
	#!!?? Not quite sure why GCC on e.g. w64devkit survives the botched path autoconv.:
	g++ -std=c++20 -Wall "-I${TEST_DIR}" -o "$exe" "$main_src"
	;;
esac
