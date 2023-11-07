FEATURES
--------

(Just to codify existing behavior as "expected" (and testable), rather than leaving them
"accidental"...)

- [x] Classic named (option) and unnamed (positional) arguments
  - [x] intermixed (if the order doesn't matter)
- [x] Prefix char either - or / freely mixed,
      - [ ] but that can be disabled
- [x] Both short and long options: -x --long
      - [x] Long options only as --long (so //whaaat is always positional)
- [ ] A bare -- turns off named args. for the rest of the cmdline by default, but it
      - [ ] can be configured to be a regular positional arg. (*for now it always is!*)
- [x] Options are predicates by default, with simple bool checks: args["x"], args["long"]
- [x] Long options can take values without config.: --name=val
- [x] Any option can take values if configured so: -a file --except *pattern
      - [x] long ones also without = in this case
      - [x] query (as std::string): args("a") -> "file", args("except") -> "*pattern"
- [x] Outputs also available in args.named() -> std::map, args.positional() -> std::vector
      - [x] Use the non-const accessors to modify these containers as you wish
            (they are *yours*, right? ;) especially after parsing...)
- [x] Options (short or long) can also have multiple parameters --multi a b c
      - [x] query like: args("multi", 2) -> "c",
      - [x] or get them all with args.named("multi") -> std::vector{"a", "b", "c"}
- [?] Multi-parameter args. can be "greedy" to take each value up to the next opt.,
      - [x] or only a fixed n. of values
- [x] Repeated options override earlier ones by default
- [ ] Repeated options can also be set to
      - [x] be ignored,
      - [x] append (for multi-val opts.),
      - [ ] fail
- [x] Parsing on construction: Args args(argc, argv)
- [x] Deferred parsing: Args args; args.parse(argc, argv)
- [x] Reparsing with different config: reparse(flags = Defaults, rules = {})
      - [x] The instance can be reused for completely new parses, too:
            parse(new_argc, new_argv, flags = Defaults, rules = {})
      - [x] The last used argc/argv are available as args.argc, args.argv
            (in case they're needed outside of main(), e.g. via myApp.args)
- [x] exename(): argv[0], but stripping the path and
      - [x] the extension (".exe" by default, but -> exename(false, ".mysuffix"),
      - [x] unless its "true value" :) is requested with exename(true)
- [x] Quick bool check if there have been any args: if (args), if (!args)


EXAMPLES
--------

- A simple one:

	#include "Args.hpp"
	#include <iostream>
	using std::cout;
	int main(int argc, char** argv)
	{
		Args args(argc, argv);

		if (args)
			cout << "Some args are present.\n";

		if (!args || args["h"])
			cout << "Usage: " << args.exename() << " "
		             << "[-h] [-x] [--long] [whatever...]\n";

		if (args["x"])
			cout << "  'x' was set\n";

		if (args["long"])
			cout << "  'long' was set"
			     << (args("long").empty() ? "" : " to " + args("long"))
			     << '\n';

		for (auto a: args.positional())
			cout << "  positional arg.: " << a << '\n';
	}
