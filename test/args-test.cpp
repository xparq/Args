#include "Args.hpp"
#include <iostream>
using namespace std;


auto listvals(auto const& vect)
{
	for (auto v = vect.begin(); v != vect.end(); ++v)
		cout << (v == vect.begin() ? "":", ")
		     << *v
		     << (v+1 == vect.end() ? "\n":"");
};

int main(int argc, char* argv[])
{
	Args args(argc, argv, {
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
