#!/bin/sh

exe=${1%.cpp}.exe
g++ -std=c++20 -I.. -o $exe $1
