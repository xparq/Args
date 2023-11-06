/*
  This file can be #included from test cases, to keep its behavior,
  but alter the config!

  E.g.:
	#define FLAGS Args::RepeatAppends,
	#include "args-test.cpp"
*/

//---------------------------------------------------------------------------
// Parameter macros currently supported (name: format):

#ifdef FLAGS // unsigned
# define FLAGS_COMMA_IF_DEFINED FLAGS,
#else
# define FLAGS_COMMA_IF_DEFINED
#endif
//---------------------------------------------------------------------------

#include "Args.hpp"
#include <iostream>
using namespace std;


auto listvals(auto const& container, const char* tail = "\n", const char* sep = ", ")
{
	for (auto v = container.begin(); v != container.end(); ++v)
		cout << (v == container.begin() ? "":sep)
		     << *v
		     << (v+1 == container.end() ? tail:"");
}

int main(int argc, char* argv[])
{
	Args args(argc, argv, FLAGS_COMMA_IF_DEFINED {
		{"one", 1},     // take 1 param.
		{"i", -1},      // short; any nr. of params up to the next arg or EOS
		{"many", -1},   // long;  any nr. of params up to the next arg or EOS
		{"take-two", 2},
	});
	//auto exename = args.exename();

	//test: args = Args(argc, argv); // <- no args take params.

	cout << "-------- NAMED: \n";
	for (auto const& p : args.named()) {
		cout << p.first << (p.second.empty() ? "\n" : " = ");
		listvals(p.second);
	}

	cout << "-------- POSITIONAL: \n";
	listvals(args.positional());

	if (args["?"] || args["h"] || args["help"]) {
		cout << "Usage: [-V] [--moons n]" << endl;
		return 0;
	}
	if (args["V"]) {
		cout << "Version: ..." << endl;
		return 0;
	}
}
