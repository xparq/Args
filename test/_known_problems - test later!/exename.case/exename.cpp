#include "../../Args.hpp"

#include <cassert>
#include <iostream>
using namespace std;

int main(int argc, char** argv)
{
try {
	Args args(argc, argv);

	if (args["internal-string-ops"])  {
		const char* v[] = {
		"",
		"/",
		"//",
		"x/",
		"/x",
		"/x/",
		};

		for (size_t i = 0; i < sizeof(v)/sizeof(char*); ++i) {
			auto p = (char**)&v[i];
			assert(p);
			assert(*p);
			try {
				Args a(1, p); //! not (argc, ...) ;)
				cout << v[i] <<" -> " << a.exename(true) << endl;
			} catch (const std::exception& e) {
				cerr << "Exception 1: " << e.what() << endl;
			}
		}
	} else {
		if (args["keep-ext"]) cout << "kept: " << args.exename(true) << endl;
		else                  cout << "cut: "  << args.exename()     << endl;
	}
} catch (const std::exception& e) {
	cerr << "Exception 2: " << e.what() << endl;
} catch (...) {
	cerr << "Unknown exception!" << endl;
}
}
