// Tiny cmdline processor 3.0.1 (https://github.com/xparq/Args)
#ifndef ASDCVHF374Y192S84DTYBF87HY39486CVATY
#define ASDCVHF374Y192S84DTYBF87HY39486CVATY

#include <string>
#include <vector>
#include <map>
#include <cassert>
//#include <iostream> // cerr, for debugging

class Args
{
public:
	enum {	Defaults = 0, // Invalid combinations are not checked!
		RepeatIsError = 1,                     // repeated options set an error flag (default: override)
		RepeatAppends = 2,                     // repeated opt. takes further values (if it can) (default: override) (GH #16)
		//!! Not yet: UnknownIsError = 4,      // unknown options set an error flag (default: accept)
		//!! Not yet: UnknownIsPositional = 8, // unknown options are treated as positional args (default: accept) (GH #13)
		DashDashIsPositional         = 16,     // -- is just a positional arg (default: it makes any further args positional)
		//!! Not yet: DeleteUnknown  = 32,     // unknown options are ignored (default: accept)
		//!! Not yet: DeleteInvalid  = 64,     // remove known options that got incorrect # of params (GH #44)
		//!! Not yet: IgnoreCase     = 128,    // option names are case-insensitive (default: case-sensitive)
		//!! Not yet: Greedy         = 256,    // unknown options take as many params as they can (default: only --unknown= takes 1) (GH #43)
		NoSlashOptions = 512,                  // only dashes
	};
	unsigned flags = Defaults;   // (not the enum, to avoid some annoying C++ restrictions)

	enum Error { None, ParameterMissing = 1, Duplicate = 2, Unimplemented = 0xffff };
	unsigned error = None;       // (not the enum to avoid some annoying restrictions)

	mutable int argc = 0; // 'mutable' to emphasize that these can be replaced for (and by) reparsing
	mutable char const* const* argv = nullptr; // "C++ MADE ME DO IT!" Being less uptight caused problems in corner cases

	typedef std::map<std::string, int> Rules;
	Rules opt_rules;  // { {"name", n_of_params_to_take}, ... }
	                  // Negative n means variadic: *at least* n, until the next opt (or EOS)
	                  // NOTE: nonexistent entries will return 0, in accordance with NonGreedy (std::map zero-inits primitive types)

	Args() = default;

	Args(int _argc, char const* const* _argv, const Rules& rules = {}) // ...use this also when you need to set rules, but not flags
		: argc(_argc), argv(_argv), opt_rules(rules) { proc_next("", 0); }

	Args(int _argc, char const* const* _argv, unsigned cfg, const Rules& rules = {}) // ...when you need to set flags, but not rules
		: flags(cfg), argc(_argc), argv(_argv), opt_rules(rules) { proc_next("", 0); }

	Args(const Args&) = default;
	Args& operator=(const Args&) = default;

	bool parse(int _argc, const char* const* _argv, unsigned cfg = Defaults, const Rules& rules = {})
		{ clear(); argc = _argc; argv = _argv; flags = cfg, opt_rules = rules;
		  proc_next("", 0); return error == None; }

	bool reparse(unsigned cfg = Defaults, const Rules& rules = {}) // Uses the original inputs
		{ return parse(argc, argv, cfg, rules); }

	void clear() { named_args.clear(); positional_args.clear(); }

	// Poor man's optional<string> (used by op[] below)
	struct OptStr : public std::string {
		bool set_ = false;  // Was the arg specified at all?
		bool set() const { return set_; } // Note: complements the inherited empty() nicely.
		         OptStr() noexcept = default;
		explicit OptStr(std::string str) : std::string(str), set_(true) {}
		template <typename T> T get_or(T deflt) const { return set_ ? as<T>() : deflt; }
		template <typename T> T as() const { static_assert(!sizeof(T), "Unsupported getter!"); }
		explicit inline operator bool() const; //!! { return as<bool>(); } <- DOESN'T COMPILE HERE! :-/
	};

	// Get the value of a named arg. as OptStr (coerced via as<bool>() in bool contexts)
	// Note: `if (["x"])` for `--x`, or `-x` is true, BUT SO IS `--x=` (unless explicitly
	// set to false (like `--x=off`). So, `x.as<bool>()` is true when x.empty()!
	// It's always cleaner to check with .set() explicitly if there's any ambiguity:
	// `if (auto x = args["x"]; x.set()) cfg.x = x.as<float>();`
	// or better yet: `cfg.x = args["x"].get_or(3.14f)`.
	// (Note: if ["x"] just meant "was x set?", it'd need to return true also for `--x=false`!)
	OptStr operator[](const std::string& opt) const { return named().find(opt) == named().end() ?
	                                                         OptStr()   :       !named().at(opt).size() ?
	                                                         OptStr("") : OptStr(named().at(opt)[0]); }
	// Get the nth positional arg, or "" if none:
	std::string operator[](unsigned n) const { return positional().size() > n ? positional()[n] : ""; }
	// Get the nth param. of "opt" (first (0th) by default), or "":
	std::string operator()(const std::string& opt, unsigned n = 0) const { return named().find(opt) == named().end() ?
	                                                                      "" : (named().at(opt).size() <= n ?
	                                                                      "" :  named().at(opt)[n]); }

	const std::vector<std::string>& positional() const { return positional_args; }
	      std::vector<std::string>& positional()       { return positional_args; }
	const std::map<std::string, std::vector<std::string>>& named() const { return named_args; }
	      std::map<std::string, std::vector<std::string>>& named()       { return named_args; }
		// Hint: to prevent casual named()[...] calls from silently adding
		// missing keys (std::map does that!), use the Args obj. via a const ref!

	// Remember: this is coming from the command that eventually launched the exe, so it
	// could be "anything"... E.g. no guarantee that it ends with ".exe" on Windows etc.
#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wpedantic"
#endif
	std::string exename(bool keep_as_is = false, std::string ext = ".exe") const {
		// Anyway, if it has a path, remove it:
		std::string basename(std::string(argv[0]).substr(std::string(argv[0]).find_last_of("/\\") + 1));
		if (keep_as_is) { return basename; }
		else { return basename.substr(0, basename.rfind(ext)); }
	}
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif

	explicit operator bool() const { return argc > 1; }

protected:
	std::map<std::string, std::vector<std::string>> named_args;
	std::vector<std::string> positional_args;

	void proc_next(const std::string& last_opt, int values_to_take, int next_arg_index = 1, bool options_done = false) {
		auto get_next_word = [&](){ return std::string(next_arg_index < argc ? argv[next_arg_index++] : ""); };
		auto handle_duplicate = [this](const std::string& opt){
			if (!named().contains(opt)) return; // Not a dup.
			if (  flags & RepeatIsError ) error |= Error::Duplicate;
			if (!(flags & RepeatAppends)) named_args[opt].clear(); // Reset its param. list...
		};
		auto arg = get_next_word();
		if (arg == "") return;
		if (options_done) goto process_as_positional; // Not another nested if level!...
		if (values_to_take > 0) { // last_opt still eating parameters?
	//std::cerr << "- eating '"<< arg <<"' as param. val. for " << last_opt << "\n";
			assert(!last_opt.empty());
			named_args[last_opt].emplace_back(arg); // Add current arg as new param. value to last_opt, and...
			return proc_next(last_opt, --values_to_take, next_arg_index, options_done); // ...continue with last_opt!
		}
		// Option (-x, /x, -aggregate, /aggregate, --long, --, //...)?...
		if ((arg[0] == '-' || (!(flags & NoSlashOptions) && arg[0] == '/'))
				&& arg.size() > 1) { // (Note: -/ and /- are options, // is not!)
			std::string new_opt;
			if (arg[1] == '-' && arg.size() > 2) { // --long opt.
				new_opt = arg.substr(2); // OK, we don't check now... ;)
				// Extract any =value right now, because the next loop cycle can't (even see it)!
				//! This also allows --unknown=value, so no need for a rule for each arg
				auto eqpos = new_opt.find_first_of(":=");
				bool arg_has_eq = eqpos != std::string::npos;
				if (arg_has_eq) new_opt = new_opt.substr(0, eqpos); // Chop off the =... from the opt. name
				handle_duplicate(new_opt);
				if (arg_has_eq) {
					if (arg.size() > 2/*for --*/ + eqpos + 1) { // Any value after the =?
		//std::cerr << "val: " << arg.substr(2, eqpos) << "\n";
						named_args[new_opt].emplace_back(arg.substr(2 + eqpos+1)); //! Don't crash on `--opt=`
						auto pc = opt_rules[new_opt]; // pc: configured param. count, or 0
						// We have taken (the) one param. now, regardless of any arity rules.
						// If there is a rule, and it says 0, the value is just gonna get
						// ignored by the app (well, an error would be nice!...), beyond
						// making the option evaluate true as a predicate, of course. And if
						// the rule is !0, we just continue taking more, or none, as prescribed:
		//std::cerr << tmp << " params expected for [" << new_opt << "]\n";
						return proc_next(new_opt, pc<-1? pc+1 : (pc? pc-1 : 0), //!! The pc<-1 case is bogus/incomplete!
							next_arg_index, options_done);
					} else {
		//std::cerr << "--"<<new_opt<<"= (distinct from --"<<new_opt<<") detected!\n"; //!!?? Push an "" param?
					}
				} else values_to_take = opt_rules[new_opt]; // Take the next arg(s) instead, if needed
			} else if (arg[1] != arg[0]) { // a real short opt, or short opt. aggregate
//!!				return proc_next("-" + arg.substr(1), next_arg_index, ...state/mode);
				for (auto c : arg.substr(1)) {
					new_opt = std::string(1, c);
					handle_duplicate(new_opt); // Err, drop prev. params, or do nothing
					named_args[new_opt]; // Register (with no new params (yet))
				}
			} else { // `--` is a positional arg. if opted in (FWIW, `//...` always is)
				assert(arg[1] == arg[0]); // (In case I reshuffle the cond. above...)
				if (arg == "--" && !(flags & DashDashIsPositional)) {
					options_done = true;
					return proc_next(new_opt, 0, next_arg_index, options_done);
				}
				goto process_as_positional;
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
			return proc_next(new_opt, opt_rules[new_opt], next_arg_index, options_done);
		}

	process_as_positional:
	//std::cerr << "- adding unnamed arg (or eating it as param): "<< arg <<"\n";
		if (values_to_take < 0) { // Well, there's still this greedy option-param case first, so...:
			named_args[last_opt].emplace_back(arg);
			return proc_next(last_opt, values_to_take, next_arg_index, options_done);
		} else {
			positional_args.push_back(arg); // Finally! :)
			return proc_next("", 0, next_arg_index, options_done);
		}
	};
};

// C++ doesn't let us keep these in-class, where they belong. :-/ (MSVC does though, so it is possible!)
template <> inline bool     Args::OptStr::as() const { return set() /* But not: && !empty(), to support `--opt` (and `--opt=`) still being true! */
	&& *this != "0" && *this != "false" && *this != "off" && *this != "no"  && *this != "disabled"; };
template <> inline int      Args::OptStr::as() const { try { return std::stoi (*this); } catch(...) { return 0; } }
template <> inline long     Args::OptStr::as() const { try { return std::stol (*this); } catch(...) { return 0; } }
template <> inline unsigned Args::OptStr::as() const { try { return std::stoul(*this); } catch(...) { return 0; } }
template <> inline float    Args::OptStr::as() const { try { return std::stof (*this); } catch(...) { return 0; } }
template <> inline double   Args::OptStr::as() const { try { return std::stod (*this); } catch(...) { return 0; } }
Args::OptStr::operator bool() const { return as<bool>(); }

// An op<< to print without casting (to std::string):
template <typename Out>
Out& operator << (Out& out, const Args::OptStr& s) { out.put(static_cast<const std::string&>(s)); return out; }

#endif //ASDCVHF374Y192S84DTYBF87HY39486CVATY
