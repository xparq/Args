/*
  Test app to allow resetting the flags + reparsing the args...

  This file can be also be #included from test cases, to keep its behavior,
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
#include <string>
#include <string_view>
#include <cassert>
#include <iostream>
using namespace std;

#define TRY_SET_OR_DEFAULT(var, expr, dflt) {try {var = expr;} catch(...) {var = dflt;}}

#define CONTAINS(str, chars) ((str).find_first_of(chars) != std::string::npos)
string listvals(auto const& container, string prewrap = "", string postwrap = "",
	string sep = ", ", string quote = "\"", string scary_chars = " \t\n")
{
	string result;
	if (!container.empty()) {
		// Precalc. size... (Note: we're processing cmd args. We got time.)
		size_t size = prewrap.size() + (container.size() - 1) * sep.size() + postwrap.size();
		for (auto& v : container) size += v.length()
			+ (!quote.empty() && CONTAINS(v, scary_chars) ? // add quotes...
				(quote.size() > 1 ? quote.size() : 2) : 0); // special case for 1 (-> pair)!
		result.reserve(size);
		// Write...
		result += prewrap;
		for (auto v = container.begin(); v != container.end(); ++v) { // We'll need v+1, so no range...
			if (!quote.empty() && CONTAINS(*v, scary_chars))
				{ result += string_view(quote.c_str(), quote.c_str() + (quote.size()/2 ? quote.size()/2 : 1)); // special case for 1 quote!
				  result += *v;
				  result += string_view(quote.c_str() + quote.size()/2); }
			else    { result += *v; }
			result += (v+1 == container.end() ? postwrap : sep);
		}
		assert(result.size() == size);
	}
	return result;
}
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

//----------------------------------------------------------------------------
int main(int argc, char** argv)
{
	Args args(argc, argv, FLAGS_COMMA_IF_DEFINED {
		{"one", 1},     // take 1 param., long
		{"1", 1},       // take 1 param., short
		{"take-two", 2},
		{"2", 2},       // take 2 param, short
		{"G", -1},      // short greedy; any nr. of params up to the next arg or EOS
		{"greedy", -1}, // long greedy;  any nr. of params up to the next arg or EOS
	});

	if (!args) {
		cerr << "Usage: " << args.exename() << "[--flags=<UNSIGNED | xHEX>] [REAL ARGS...] [--debug]" << '\n';
		cerr << "\n	If run with --flags, it will reparse the args with the new setting.\n";
		cerr << "	Default flags: " << args.flags << " (hex: x" << hex << args.flags << ")\n";
		cerr << "\n	--debug: output more, like error codes etc.\n";
		cerr << "\n	--cmdgen: regenerate (approx.) command line from the parsed args.\n";
		return 1;
	}
	// Some legacy test cases also use this:
	if (args["?"] || args["h"] || args["help"]) {
		cout << "Usage: help..." << '\n';
	}

	string flags_s = args("flags");
	unsigned flags;
	if (flags_s[0] != 'x') {// dec
		TRY_SET_OR_DEFAULT(flags, stoul(flags_s), args.flags);
	} else { // hex
		TRY_SET_OR_DEFAULT(flags, stoul(flags_s.c_str() + 1, nullptr, 16), args.flags);
	}

	args.reparse(flags, args.known_options);

	cout << "-------- NAMED ("<< args.named().size() <<"): \n";
	for (auto& [name, val] : args.named()) {
		cout << name << listvals(val, " = ") << '\n'; // val may itself be a list!
	}
	cout << "-------- POSITIONAL ("<< args.positional().size() <<"): \n"
	     << listvals(args.positional(), "", "\n"); // only \n it if non-empty

if (args["debug"]) {
	cout << "-------- ERROR: " << dec << args.error << '\n';
	cout << "flags: " << flags << " (hex: x" << hex << flags << ")\n";
}
	if (args["cmdgen"]) { cout << args.exename() << " "; dumpargs(args); cout << '\n'; }


	return 0;
}
