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
		             << "[-h] [-x] [--long] [...]\n";

		if (args["x"]) // Predicate check
			cout << "  'x' was set (to not false)\n";

		if (auto x = args["long"]; x.set()) // x is like optional<string>, but with the std::string API!
			cout << "  'long' was set to "
			     << (x.empty() ? "nothing"s : x) // "..."s works (and needed) because x is (derived from) std::string
			     << '\n';

		for (auto a: args.positional())
			cout << "  positional arg.: " << a << '\n';
	}
