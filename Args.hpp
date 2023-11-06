// Tiny cmdline processor (-> github.com/xparq/Args)
// v1.12

#ifndef _ARGS_HPP_

#include <string>
#include <vector>
#include <map>
#include <cstddef> // size_t
#include <cassert>
//#include <iostream> // cerr, for debugging

class Args
{
public:
	enum {	Defaults = 0,
		RepeatAppends = 1,   // for opts. expecting >1 params; default: override (replace) (GH #16)
		//!! Not supported yet:
		//RejectUnknown = 2,   // undefined options are treated as positional args; default: accept (GH #13)
		//!! These are implicitly enforced by the current implementation (can't be disabled):
		KeepInvalid   = 4,   // default: delete them (i.e. those with incorrect # of params) (GH #44)
		NonGreedy     = 8 }; // undefined options don't try to take params; default: they do (GH #43)
	unsigned flags = Defaults;   // (not the enum, to avoid some annoying restrictions)

	enum Error { None, ParameterMissing, Unimplemented = -1 } error = None;

protected:
	typedef std::map<std::string, int> Rules;

	// Mutable to allow resetting for reparsing (e.g. with different flags/rules)
	mutable int argc = 0;
	mutable const char* const* argv = nullptr;

	Rules param_count; // entries: { "option", nr_of_params_for_option }
	                   // negative n means greedy: "at least n", until the next opt or EOS
	                   // NOTE: nonexistent entries will return 0 (std::map zero-inits primitive types)
//!!	const char* split_sep = ",;"; // split("option") will use this by default
public:
	Args(int argc, const char* const* argv, const Rules& rules = {}) // ...also if you need to set rules, but not flags
		: argc(argc), argv(argv), param_count(rules) { proc_next("", 0); }

	Args(int argc, const char* const* argv, unsigned flags, const Rules& rules = {}) // ...also if you need to set flags, but not rules
		: flags(flags), argc(argc), argv(argv), param_count(rules) { proc_next("", 0); }

	Args() = default;
	Args(const Args&) = default;
	Args& operator=(const Args&) = default;

	bool parse(int argc_, const char* const* argv_, unsigned flags_ = Defaults, const Rules& rules_ = {})
		{ clear(); argc = argc_; argv = argv_; flags = flags_, param_count = rules_;
		  proc_next("", 0); return error == None; }

	bool reparse(unsigned flags_ = Defaults, const Rules& rules_ = {}) // uses the original inputs (which can also be altered)
		{ return parse(argc, argv, flags_, rules_); }

	void clear() { named_args.clear(); positional_args.clear(); argi = 1; }

	// Check if opt was set:
	bool operator[](const std::string& opt) const { return named().find(opt) != named().end(); }

	// Return nth (1st by default) value of arg, or "":
	std::string operator()(const std::string& argname, size_t n = 0) const { return named().find(argname) == named().end()
	                                                            ? "" : (named().at(argname).size() <= n
	                                                                   ? "" : named().at(argname)[n]); }

	const std::vector<std::string>& positional() const { return positional_args; }
	      std::vector<std::string>& positional()       { return positional_args; }
	const std::map<std::string, std::vector<std::string>>& named() const { return named_args; }
	      std::map<std::string, std::vector<std::string>>& named()       { return named_args; }
		// Pedantry: if you want to prevent casual named()[...] calls to add missing keys
		// (std::map does that), use a const copy of the Args obj with op() and op[].

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

	std::map<std::string, std::vector<std::string>> named_args;
	std::vector<std::string> positional_args;

	void proc_next(const std::string& last_opt, int values_to_take) {
		std::string a = get_next_word();
		if (a == "") return;

		if (values_to_take > 0) {
	//std::cerr << "- eating '"<< a <<"' as param. val. for " << last_opt << "\n";
			assert(!last_opt.empty());
			named_args[last_opt].emplace_back(a);
			return proc_next(last_opt, --values_to_take);
		}

		if ((a[0] == '-' || a[0] == '/') && a.size() > 1) { // option, or -- or // (note: -/ and /- are options)
			std::string new_opt;
			if (a[1] == '-' && a.size() > 2) { // likely --long-option, or junk like --$G@%F or ---...
				new_opt = a.substr(2); // OK, we don't check now... ;)
				// Extract the =value right now, because the next loop cycle can't (even see it)!
				auto eqpos = new_opt.find_first_of(":=");
				if (eqpos == std::string::npos) {
					values_to_take = param_count[new_opt];
				} else { //! This also allows `--unknown-opt=value` (no matter the rules)!
					new_opt = new_opt.substr(0, eqpos); // chop off the `=...`
					if (!(flags & RepeatAppends)) named_args[new_opt].clear(); // Reset in case it's not actually new?...
					if (a.size() > 2 + eqpos + 1) { // value after the `=`?
	//std::cerr << "val: " << a.substr(2, eqpos) << "\n";
						named_args[new_opt].emplace_back(a.substr(2 + eqpos+1)); //! don't crash on `--opt=`
						auto pc = param_count[new_opt];
						// We have taken the offered value regardless of the rules,
						// but if there's indeed a rule, we're good, 'coz if = 0, then
						// the value can just be ignored, and if != 0, then we've just
						// started taking params anyway, the only thing left is to
						// make sure to continue that if expecting more:
	//std::cerr << tmp << " params expected for [" << new_opt << "]\n";
						return proc_next(new_opt, pc < -1 ? pc+1 : (pc ? pc-1 : 0));
					}
				}

				//!! CHECK ERRORS!
				//!! ...
				//!! Should `--opt val` be kept supported?
				//!! ... error = ParameterMissing;

			} else if (a[1] != a[0]) { // a real short opt, or short opt. aggregate
				new_opt = a.substr(1, 1);
			} else { // '--' or '//...' are considered positional args for now
				goto process_unnamed;
			}

			// We have a new option, process it...
			if (values_to_take < -1) {
				error = Unimplemented;
	//!!std::cerr << "- Not yet supporting variable number of option args.\n";
				// But it would involve using last_opt, hence the last/new distinction...
			}
			// Add the option with an empty param list to start with:
	//std::cerr << "ready to take next arg as param, if expects any.\n";
			named_args[new_opt];
			return proc_next(new_opt, param_count[new_opt]);
		}

	process_unnamed:
	//std::cerr << "- adding unnamed arg (or eating it as param): "<< a <<"\n";
		if (values_to_take < 0) {
			named_args[last_opt].emplace_back(a);
			return proc_next(last_opt, values_to_take);
		} else {
			positional_args.push_back(a);
			return proc_next("", 0);
		}
	};

private:
	int argi = 1; // next arg word to eat (start with argv[1])
};

#define _ARGS_HPP_
#endif
