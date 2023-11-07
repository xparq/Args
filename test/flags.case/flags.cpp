// Set flag and reparse the args...

#include "Args.hpp"
#include <string>
#include <string_view>
#include <cstring>
#include <cassert>
#include <iostream>
using namespace std;

#define TRY_SET_OR_DEFAULT(var, expr, dflt) {try {var = expr;} catch(...) {var = dflt;}}

#define FOUND(expr) ((expr) != std::string::npos)
#define CONTAINS(str, chars) FOUND((str).find_first_of(chars))
string listvals(auto const& container, const char prewrap[] = "", const char postwrap[] = "", const char sep[] = ", ",
	const char* quote = "\"", // not const char[], to hint that it accepts nullptr!
	const char* scary_chars = " \t\n")
{
	string result;
	if (!container.empty()) {
		size_t QLEN = quote ? strlen(quote) : 0;
		// Precalc. size... (Note: we're processing cmd args. We got time.)
		size_t size = strlen(prewrap) + (container.size() - 1) * strlen(sep) + strlen(postwrap);
		for (auto& v : container)
			size += v.length()
				+ (quote && *quote && CONTAINS(v, scary_chars) ? // add quotes...
					(QLEN>1 ? QLEN:2) : 0); // special case for 1 (-> pair)!
		result.reserve(size);
		// Write...
		result += prewrap;
		for (auto v = container.begin(); v != container.end(); ++v) {
			if (quote && *quote && CONTAINS(*v, scary_chars))
				{ result += string_view(quote, quote + (QLEN/2 ? QLEN/2 : 1)); // special case for 1 quote!
				  result += *v;
				  result += string_view(quote + QLEN/2); }
			else    { result += *v; }
			result += (v+1 == container.end() ? postwrap : sep);
		}
		assert(result.length() == size);
	}
	return result;
}
#undef FOUND
#undef CONTAINS


void dumpargs(Args& args, char prefixchar = '-', const char* longprefix = "--")
{
	// Named...
	for (auto& [name, val] : args.named()) {
		if (name.length() == 1)
			cout << prefixchar << name << listvals(val, " ", "", " ");
		else
			cout << longprefix << name << listvals(val, "=", "", " ");
		cout << " ";
	}
	// Positional...
	cout << listvals(args.positional(), "", "", " ");
}

int main(int argc, char** argv)
{
	Args args(argc, argv);

	if (!args) {
		cerr << "Usage: " << args.exename() << " [REAL ARGS...] --flags=<UNSIGNED | xHEX>" << '\n';
		cerr << "- default flags: " << args.flags << " (hex: x" << hex << args.flags << ")\n";
		return 1;
	}

	string flags_s = args("flags");
	unsigned flags;
	if (flags_s[0] != 'x') {// dec
		TRY_SET_OR_DEFAULT(flags, stoul(flags_s), args.flags);
	} else { // hex
		TRY_SET_OR_DEFAULT(flags, stoul(flags_s.c_str() + 1, nullptr, 16), args.flags);
	}
//	cout << args.exename() << " "; dumpargs(args); cout << '\n';
	cout << "using flags: " << flags << " (hex: x" << hex << flags << ")\n";

	args.reparse(flags);

	cout << "-------- NAMED ("<< args.named().size() <<"): \n";
	for (auto& [name, val] : args.named()) {
		cout << name << listvals(val, " = ") << '\n'; // val may itself be a list!
	}
	cout << "-------- POSITIONAL ("<< args.positional().size() <<"): \n"
	     << listvals(args.positional(), "", "\n"); // only \n it if non-empty

	if (args["?"] || args["h"] || args["help"]) {
		cout << "Usage: [-V] [--moons n]" << '\n';
		return 0;
	}
	return 0;
}
