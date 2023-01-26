#include "Args.hpp"
#include <iostream>
using namespace std;

int main(int argc, char* argv[])
{
	Args args(argc, argv, {
		{"moons", 1}, // number of moons to start with
		{"i", -1}, // any number of args up to the next arg or EOS
	});
	//auto exename = args.exename();

	//test: args = Args(argc, argv); // <- no args take params.

//	auto listvals = [](auto vect) {
//	};

	cout << "-------- NAMED: \n";
	for (auto const& p : args.named()) {
		cout << p.first << (p.second.empty() ? "\n" : " = ");
		for (auto v = p.second.begin(); v != p.second.end(); ++v)
			cout << (v == p.second.begin() ? "":", ")
			     << *v
			     << (v+1 == p.second.end() ? "\n":"");
	}

	cout << "-------- POSITIONAL: \n";
        for (auto v = args.unnamed().begin(); v != args.unnamed().end(); ++v) {
		cout << (v == args.unnamed().begin() ? "":", ")
		     << *v
		     << (v+1 == args.unnamed().end() ? "\n":"");
	}

	if (args["?"] || args["h"] || args["help"]) {
		cout << "Usage: [-V] [--moons n]" << endl;
		return 0;
	}
	if (args["V"]) {
		cout << "Version: ..." << endl;
		return 0;
	}
}
