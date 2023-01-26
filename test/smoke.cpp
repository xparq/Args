#include "Args.hpp"
#include <iostream> // cerr
using namespace std;

int main(int argc, char* argv[])
{
    Args args(argc, argv, {
        {"moons", 1}, // number of moons to start with
        {"i", -1}, // any number of args up to the next arg or EOS
    });
    //auto exename = args.exename();

    //test: args = Args(argc, argv); // <- no args take params.

    cerr << "-------- NAMED PARAMS: \n"; for (auto const& p : args.named()) {
        cerr << p.first << (p.second.empty() ? "\n" : " = ");
        for (auto const& v : p.second) cerr << "    " << v << "," <<endl;
    }
    cerr << "-------- POSITIONAL PARAMS: \n"; for (auto const& p : args.unnamed()) { cerr << p << endl; }

    if (args["?"] || args["h"] || args["help"]) {
        cout << "Usage: [-V] [-moons n]" << endl;
        return 0;
    }
    if (args["V"]) {
        cout << "Version: ..." << endl;
        return 0;
    }
}
