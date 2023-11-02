// Tiny "functional" cmdline processor (-> github.com/xparq/Args)
// v1.8

#include <string>
#include <vector>
#include <map>
#include <cstddef> // size_t
#include <cassert>
//#include <iostream> // cerr (for debugging)

class Args
{
public:
	enum {	Defaults,
		RepeatAppends = 1, // for opts. expecting >1 params; default: override (replace) (GH #16)
		//!! These two are implicitly forced by the current implementation (can't be disabled):
		KeepInvalid = 2,   // default: invalid opts. (i.e. those with incorrect # of params) are deleted (GH #44)
		NonGreedy = 4 };   // undefined options don't try to take params; default: they do (GH #43)
	unsigned flags = Defaults;

	enum Error { None, ParameterMissing, Unimplemented = -1 }
	     error = None;

protected:
	typedef std::map<std::string, int> Rules;

	int argc;
	char** argv;
	Rules param_count; // entries: { "option", nr_of_params_for_option }
	                   // negative n means greedy: "at least n", until the next opt or EOS
	                   // NOTE: nonexistent entries will return 0 (std::map zero-inits primitive types)
//!!	const char* split_sep = ",;"; // split("option") will use this by default
public:
	Args(int argc_, char** argv_, const Rules& rules = {})
		: argc(argc_), argv(argv_), param_count(rules) { proc_next("", 0); }
	Args(int argc_, char** argv_, unsigned flags, const Rules& rules = {})
		: argc(argc_), argv(argv_), flags(flags), param_count(rules) { proc_next("", 0); }
	Args(const Args&) = default;
	Args& operator=(const Args&) = default;

	// Check if opt was set:
	bool operator[](const std::string& opt) const { return named().find(opt) != named().end(); }

	// Return nth (1st by default) value of arg, or "":
	std::string operator()(const std::string& argname, size_t n = 0) const { return named().find(argname) == named().end()
	                                                            ? "" : (named().at(argname).size() <= n
	                                                                   ? "" : named().at(argname)[n]); }

	const std::vector<std::string>& positional() const { return unnamed_params; }
	//! Note: std::map[key] would want to create a key if not yet there,
	//! so named()[...] would fail, if const! But constness it is... (for consistency).
	//! Use the op() and op[] accessors for direct element access!
	const std::map<std::string, std::vector<std::string>>& named() const { return named_params; }

	// Remember: this is coming from the command that eventually launched the exe, so it
	// could be "anything"... E.g. no guarantee that it ends with ".exe" on Windows etc.
	std::string exename(bool keep_as_is = false, std::string ext = ".exe") {
		// Anyway, if it has a path, remove it:
		std::string basename(std::string(argv[0]).substr(std::string(argv[0]).find_last_of("/\\") + 1));
		if (keep_as_is) { return basename; }
		else { return basename.substr(0, basename.rfind(ext)); }
	}

	bool operator !() const { return argc < 2; }
//	operator bool() const { return !!*this; }
	//! Enabling op bool would break args["opt"] due to a weird ambiguity, where the
	//! compiler would suddenly think it may also match the builtin "opt"[int]! :-o
	//! It's due to it trying a match with autoconverted bool->int before the "real thing".
	//! The hacky workaround below may be good enough tho (but certainly not "good":
	//! -> https://www.artima.com/articles/the-safe-bool-idiom)
	//! Just comment it out, if you feel offended! ;)
	operator const void*() const { return !(*this) ? nullptr : (void*)this; }

protected:
	std::string get_next_word() { return std::string(argi < argc ? argv[argi++] : ""); }

	std::map<std::string, std::vector<std::string>> named_params;
	std::vector<std::string> unnamed_params;

	void proc_next(const std::string& last_opt, int values_to_take) {
		std::string a = get_next_word();
		if (a == "") return;

		if (values_to_take > 0) {
	//std::cerr << "- eating '"<< a <<"' as param. val. for " << last_opt << "\n";
			assert(!last_opt.empty());
			named_params[last_opt].emplace_back(a);
			return proc_next(last_opt, --values_to_take);
		}

		if ((a[0] == '-' || a[0] == '/') && a.size() > 1) { // option, or -- or // (note: -/ and /- are options)
			std::string new_opt;
			if (a[1] == '-' && a.size() > 2) { // likely --long-option, or junk like --$G@%F or ---...
				new_opt = a.substr(2); // OK, we don't check now... ;)
				// Go ahead, extract the =value (only one for now...) now,
				// because the loop/next won't!
				auto eqpos = new_opt.find_first_of(":=");
				if (param_count[new_opt] && eqpos == std::string::npos) {
					//error = ParameterMissing;
					//! Not necessarily... Should `--opt val` be kept supported?
					//! Simply ignoring this case would just work as before.
				} else if (eqpos != std::string::npos) { //! This also allows `--unknown-opt=value` (no matter the rules)!
					new_opt = new_opt.substr(0, eqpos); // chop off the `=...`
					if (!(flags & RepeatAppends)) named_params[new_opt].clear(); // Reset in case it's not actually new?...
					if (a.size() > 2 + eqpos + 1) { // value after the `=`?
	//std::cerr << "val: " << a.substr(2, eqpos) << "\n";
						named_params[new_opt].emplace_back(a.substr(2 + eqpos+1)); //! don't crash on `--opt=`
						// We have taken the offered value regardless of the rules,
						// but if there's indeed a rule, we're good, 'coz if = 0, then
						// the value can just be ignored, and if != 0, then we've just
						// started taking params anyway, the only thing left is to
						// make sure to continue that if expecting more:
						auto pc = param_count[new_opt];
	//std::cerr << tmp << " params expected for [" << new_opt << "]\n";
						return proc_next(new_opt, pc < -1 ? pc+1 : pc-1);
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

private:
	int argi = 1; // next arg word to eat (start with argv[1])
};
