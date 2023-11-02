Examples:

	#include "Args.hpp"
	#include <iostream>
	using namespace std;
	int main(int argc, char** argv)
	{
		Args args(argc, argv, {
			// Custom rules, like:
			// {"take-two", 2}, // --take-two=1,2 (or --take-two 1 2) would make it an array of [1, 2]
		});

		if (args)
			cout << "Some args are present.\n";

		if (!args || args["h"])
			cout << "Usage: " << args.exename() << " "
		             << "[-h] [-x] [--long]\n";

		if (args["x"])
			cout << "  'x' was set\n";

		if (args["long"])
			cout << "  'long' was set";
			if (!args("long").empty()) cout << " to " + args("long");
			cout << '\n';

		for (auto a: args.positional())
			cout << "  positional arg.: " << a << '\n';
	}
