#include "Args.hpp"
#include <iostream>
using namespace std;
int main(int argc, char** argv)
{
	Args args(argc, argv);
	if (args("arg") == "") cout << "arg is empty";
	else cout << "arg is: " << args("arg") << "\n";
}
