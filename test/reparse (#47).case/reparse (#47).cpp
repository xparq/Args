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

	// 1
	const char* new_argv[] = {"dummy.exe", "--newarg=dummy", "dummy-separator", "--newarg=cool"};
	args.parse(4, new_argv);
	cout << "survived repeated parsing; newarg: " << args("newarg") <<'\n';

	// 2
	args.reparse();
	cout << "after reparse(): !args == " << !args << ", newarg is still " << args("newarg") <<'\n';

	// 3 - different flags
	args.reparse(Args::RepeatAppends);
	cout << "after reparse(), newarg: " << args("newarg", 0) << ", " << args("newarg", 1) <<'\n';
}
