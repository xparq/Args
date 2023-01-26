﻿#include "Args.hpp"
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
		{"moons", 1}, // number of moons to start with
		{"i", -1}, // any number of args up to the next arg or EOS
	});
	//auto exename = args.exename();

	//test: args = Args(argc, argv); // <- no args take params.

	cout << "-------- NAMED: \n";
	for (auto const& p : args.named()) {
		cout << p.first << (p.second.empty() ? "\n" : " = ");
		listvals(p.second);
	}

	cout << "-------- POSITIONAL: \n";
	listvals(args.unnamed());

	if (args["?"] || args["h"] || args["help"]) {
		cout << "Usage: [-V] [--moons n]" << endl;
		return 0;
	}
	if (args["V"]) {
		cout << "Version: ..." << endl;
		return 0;
	}
}
