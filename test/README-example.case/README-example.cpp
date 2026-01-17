	#include "Args.hpp"
	#include <iostream>
	using std::cout;
	using namespace std::string_literals;

	int main(int argc, char** argv)
	{
		Args args(argc, argv);

		if (args)
			cout << "Some args are present.\n";

		if (!args || args["h"])
			cout << "Usage: " << args.exename() << " "
		             << "[-h] [-x] [--long]\n";

		if (args["x"])
			cout << "  'x' was set\n";

		if (auto x = args["long"])
			cout << "  'long' was set to "
			     << (x.empty() ? "nothing"s : x)
			     << '\n';

		for (auto a: args.positional())
			cout << "  positional arg.: " << a << '\n';
	}
