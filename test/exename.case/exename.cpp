#include "../../Args.hpp"

#include <iostream>
using namespace std;

int main(int argc, char** argv)
{
	cout << Args(argc, argv).exename() << endl;

	const char* v[] = {
	"",
	"/",
	"//",
	"x/",
	"/x",
	"/x/",
	};

	for (size_t i = 0; i < sizeof(v)/sizeof(char*); ++i) {
		Args a(argc, (char**)&v[i]);
		try {
			cout << v[i] <<" -> " << a.exename() << endl;
		} catch (const std::exception& e) {
			std::cerr << e.what() << endl;
		}
	}
}
