	#include "Args.hpp"
	#include <iostream>
	using namespace std;
	int main(int argc, char** argv)
	{
		Args args(argc, argv);

		if (args)
			{ cout << "Some args are present.\n"; }

		if (!args || args["h"])
//			{ cout << "Usage: " << argv[0] << " "
			{ cout << "Usage: " << "README.exe" << " "
		               << "[-h] [-x] [--long]\n";
		          return 0; }

		if (args["x"])
			{ cout << "- 'x' was set\n"; }

		if (args["long"])
			{ cout << "- 'long' was set\n"; }

		if (args["unknown"])
			{ cout << "- 'unknown' was set to '" << args("unknown") << "'\n"; }
	}
