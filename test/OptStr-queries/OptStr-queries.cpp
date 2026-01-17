#include "Args.hpp"

#include <iostream>
using namespace std;


//----------------------------------------------------------------------------
int main(int argc, char** argv)
{
	Args args(argc, argv);

	if (!args) { cout << "No args."; return 0; }

	if (args["flag_set"]) { cout << "OK, flag is set.\n"; }

	if (auto x = args["opt"]) {
		cout << "opt as bool: " << x.as<bool>() <<"\n";
		cout << "opt as int: "  << x.as<int>() <<"\n";
	}
	if (auto x = args["o"]) {
		cout << "o as bool: " << x.as<bool>() <<"\n";
		cout << "o as int: "  << x.as<int>() <<"\n";
	}

	return 0;
}
