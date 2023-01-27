#!/bin/sh

test=${1:-args-test.cpp}
DIR_OFFSET=$2

exe=${test%.cpp}.exe
#if [ "${TMP_DIR}" == "" ]; then set out=tmp; else set out=${TMP_DIR}; fi
#test ! -d "${out}" && mkdir "${out}"

g++ -std=c++20 -I${DIR_OFFSET}.. -o "$exe" "$test"
