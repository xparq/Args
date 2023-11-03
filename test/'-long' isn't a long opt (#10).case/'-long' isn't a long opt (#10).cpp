	#include "Args.hpp"
	#include <iostream>
	using namespace std;
	int main(int argc, char** argv)
	{
		Args args(argc, argv);

		if (args["long"])
			{ cout << "- 'long' was set\n"; }
	}
