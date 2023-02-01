#!/bin/sh

# "$1" - source to compile; default: $TEST_NAME

#echo TOOLSET: $TOOLSET
#echo ARGS: $@

#!!...
     exe="${1:-$TEST_NAME}"
     exe="${exe%.exe}.exe"
#echo "exe: $exe"
#!!...
main_src="${1:-$TEST_NAME}"
main_src="${main_src%.exe}.cpp"
#echo "src: $main_src"


outdir="${TMP_DIR:-tmp}"
mkdir -p "$outdir"

case $TOOLSET in
msvc)
	export INCLUDE="$TEST_DIR;$INCLUDE"
	cl -nologo -std:c++20 -W4 -wd4100 -EHsc "-Fo$outdir/" "$main_src"
	;;
gcc*)
	g++ -std=c++20 "-I${TEST_DIR}" -o "$exe" "$main_src"
	;;

esac
