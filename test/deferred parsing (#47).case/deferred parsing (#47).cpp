#include "Args.hpp"
#include <iostream>
using namespace std;

int main(int argc, char** argv)
{
	Args args;

	// 1
	try {
		args.parse(argc, argv);
	} catch(...) {
		cout << "boo!";
		return -1;
	}
	cout << "initial parse OK, flags: " << args.flags << '\n';

	// 2
	const char* new_argv[] = {"dummy.exe", "--newarg=cool"};
	args.parse(2, new_argv);
	cout << "survived reparsing. newarg: " << args("newarg") <<'\n';

	// 3
	args.parse(1, new_argv);
	cout << "round 3 survived; !args: " << !args <<'\n';
}
