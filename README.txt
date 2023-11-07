A simple example:

	#include "Args.hpp"
	#include <iostream>
	using std::cout;
	int main(int argc, char** argv)
	{
		Args args(argc, argv);

		if (args)
			cout << "Some args are present.\n";

		if (!args || args["h"])
			cout << "Usage: " << args.exename() << " "
		             << "[-h] [-x] [--long] [whatever...]\n";

		if (args["x"])
			cout << "  'x' was set\n";

		if (args["long"])
			cout << "  'long' was set"
			     << (args("long").empty() ? "" : " to " + args("long"))
			     << '\n';

		for (auto a: args.positional())
			cout << "  positional arg.: " << a << '\n';
	}
