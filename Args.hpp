// Tiny cmdline processor (-> github.com/xparq/Args)
// v1.3

#include <string>
#include <vector>
#include <map>
// For debugging/testing only:
//#include <cassert>
//#include <iostream> // cerr

class Args
{
protected:
	typedef std::map<std::string, int> Rules;
	Rules param_count; // entries: { "option_name", number_of_args }
							// negative count means "at least n", until the next opt or EOS
							// NOTE: nonexistent items will return 0 (map zero-inits primitive types)
public:
	enum Error { None, ParameterMissing, Unimplemented = -1 }
	     error = None;

public:
	Args(int argc_, char** argv_, const Rules& rules = {})
		: argc(argc_), argv(argv_), param_count(rules) { proc_next("", 0); }
	Args(const Args&) = default;
	Args& operator=(const Args&) = default;

	// Check if opt was set:
	bool operator[](const std::string& opt) const { return named().find(opt) != named().end(); }

	// Return nth (1st by default) value of arg, or "":
	std::string operator()(const std::string& argname, int n = 0) const { return named().find(argname) == named().end()
	                                                            ? "" : (named().at(argname).size() <= n
	                                                                   ? "" : named().at(argname)[n]); }

	const std::vector<std::string>&                        positional() const { return unnamed_params; }
	//! Note: std::map[key] would want to create a key if not yet there,
	//! so named()[...] would fail, if const! But constness it is... (for consistency).
	//! Use the op() and op[] accessors for direct element access!
	const std::map<std::string, std::vector<std::string>>& named()   const { return named_params; }

	bool operator !() const { return argc < 2; }
//!	operator bool() const { return !!*this; }
	//! Enabling op bool would break args["opt"] due to a weird ambiguity, where the
	//! compiler would suddenly think it may also match the builtin "opt"[int]! :-o
	//! It's due to it trying a match with autoconverted bool->int before the "real thing".
	//! The hacky workaround below may be good enough tho (but certainly not "good":
	//! -> https://www.artima.com/articles/the-safe-bool-idiom)
	//! Just comment it out, if you feel offended! ;)
	operator const void*() const { return !(*this) ? nullptr : (void*)this; }

protected:
	int argc;
	char** argv;
	int argi = 1; // next arg word to eat (skip argv[0]!)
	std::string get_next_word() { return std::string(argi < argc ? argv[argi++] : ""); }

	std::map<std::string, std::vector<std::string>> named_params;
	std::vector<std::string> unnamed_params;

	void proc_next(const std::string& last_opt, int values_to_take) {
		std::string a = get_next_word();
		if (a == "") return;

		if (values_to_take > 0) {
	//std::cerr << "- eating '"<< a <<"' as param. val. for " << last_opt << "\n";
	//		assert(!last_opt.empty());
			named_params[last_opt].emplace_back(a);
			return proc_next(last_opt, --values_to_take);
		}

		if (a[0] == '-' || a[0] == '/' && a.size() > 1) { // option, or -- or // (note: -/ and /- are options)
			std::string new_opt;
			if (a[1] == '-' && a.size() > 2) { // likely --long-option, or junk like --$G@%F or ---...
				new_opt = a.substr(2); // OK, we don't check now... ;)
				// Go ahead, extract the =value (only one for now...) now,
				// because the loop/next won't!
				if (auto eqpos = new_opt.find_first_of(":=");
					param_count[new_opt] && eqpos == std::string::npos) {
					//error = ParameterMissing;
					//! Not necessarily... Should `--opt val` be kept supported?
					//! Simply ignoring this case would just work as before.
				} else if (eqpos != std::string::npos) { //! This also allows `--unknown-opt=value` (no matter the rules)!
					new_opt = new_opt.substr(0, eqpos); // chop off the `=...`
					if (a.size() > 2 + eqpos + 1) { // value after the `=`?
	//std::cerr << "val: " << a.substr(2, eqpos) << "\n";
						named_params[new_opt].emplace_back(a.substr(2 + eqpos+1)); //! don't crash on `--opt=`
						// We have taken the offered value regardless of the rules,
						// but if there's indeed a rule, we're good, 'coz if = 0, then
						// the value can just be ignored, and if != 0, then we've just
						// started taking params anyway, the only thing left is to
						// make sure to continue that if expecting more:
						auto tmp = param_count[new_opt];
	//std::cerr << tmp << " params expected for [" << new_opt << "]\n";
						return proc_next(new_opt, tmp < -1 ? tmp+1 : tmp-1);
					}
				}
			} else if (a[1] != a[0]) { // a real short opt, or short opt. aggregate
				new_opt = a.substr(1, 1);
			} else { // '--' or '//...' will be considered unnamed params
				goto process_unnamed_param;
			}

			// We have a new option, process it...
			if (values_to_take < -1) {
				error = Unimplemented;
	//!!std::cerr << "- Not yet supporting variable number of option args.\n";
				// But it would involve using last_opt, hence the last/new distinction...
			}
			// Add the option with an empty param list to start with:
	//std::cerr << "ready to take next arg as param, if expects any.\n";
			named_params[new_opt];
			return proc_next(new_opt, param_count[new_opt]);
		}

	process_unnamed_param:
	//std::cerr << "- adding unnamed param\n";
		if (values_to_take < 0) {
			named_params[last_opt].emplace_back(a);
			return proc_next(last_opt, values_to_take);
		} else {
			unnamed_params.push_back(a);
			return proc_next("", 0);
		}
	};
};
