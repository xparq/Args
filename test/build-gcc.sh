#!/bin/sh

test=${1:-args-test.cpp}

exe=${test%.cpp}.exe
g++ -std=c++20 -I.. -o $exe $test
