// Tiny cmdline processor (-> github.com/xparq/Args)
// v1.0

#include <string>
#include <vector>
#include <map>
// For debugging/testing only:
//#include <cassert>
//#include <iostream> // cerr

class Args
{
	int argc;
	char** argv;
	int argi = 1; // next arg word to eat (skip argv[0]!)
	std::string get_next_word() { return std::string(argi < argc ? argv[argi++] : ""); }

	typedef std::map<std::string, int> ParamRules;
	ParamRules param_count; // entries: { "option_name", number_of_args }
							// negative count means "at least n", until the next opt or EOS
							// NOTE: nonexistent items will return 0 (map zero-inits primitive types)
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
			if (a[1] == '-' && a.size() > 2) { // likely --long-option, or junk like --$G@%F
				new_opt = a.substr(2); // OK, we don't check now... ;)
			} else if (a[1] != a[0]) { // a real short opt, or short opt. aggregate
				new_opt = a.substr(1);
			} else { // '--' or '//...' will be considered unnamed params
				goto process_unnamed_param;
			}

			// We have a new option, process it...
			if (values_to_take < -1) {
	//!!std::cerr << "- Not yet supporting variable number of option args.\n";
				// But it would involve using last_opt, hence the last/new distinction...
			}
			// Add the option with an empty param list to start with:
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

public:
	Args(int argc_, char** argv_, const ParamRules& rules = {})
		: argc(argc_), argv(argv_), param_count(rules)
		{ proc_next("", 0); }
	Args(const Args&) = default;
	Args& operator=(const Args&) = default;

	// Check if opt was set:
	bool operator[](const std::string& opt) const { return named().find(opt) != named().end(); }

	// Return nth (1st by default) value of arg, or "":
	std::string operator()(const std::string& argname, int n = 1) const { return named().find(argname) == named().end()
	                                                            ? "" : (named().at(argname).size() <= n
	                                                                   ? "" : named().at(argname)[n]); }

	const std::vector<std::string>&                        unnamed() const { return unnamed_params; }
	//! Note: std::map would want to create a key if not yet there, when accessed via [key],
	//! so this can't really be const _and_ fully practical... But constness it is now:
	const std::map<std::string, std::vector<std::string>>& named()   const { return named_params; }

};
