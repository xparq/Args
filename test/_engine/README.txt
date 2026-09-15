Space Test
  Superfrugal autotest framework, in case you got stranded on a dead planet

  (See _engine/VERSION to identify the instance.)

Features:

- ...umm, supports spaces in test case names?

  (But seriously: make tools (and many other utilities) are traditionally
  hostile to files with spaces in their names, so in order to keep the chilling
  frugality of this tool (to only depend on whatever sh-like shell it can find
  to run itself), and its stubbornness to just run, dammit, no matter what,
  constantly overcoming space-issues all the way through has been perhaps
  the single biggest challenge. (See e.g. GH issue #25, #42...)
  Oh, BTW, see, even GitHub still can't support spaces in repo names! ;) )

Anyway:

- Very small, frugal, self-containing (just a bunch of shell scripts
  + some change)

- Depends on basically nothing (but some sh shell -- a BusyBox.exe for Windows
  has been packed, to be sure, but Git's bash, or WSL should be fine), or and
  of course the toolset you may want to use for (auto)building stuff for the
  test cases, if needed)

- Everything-agnostic, can help testing anything (and basically anywhere)

- Filenames are the test titles
  (Which is the main motivation for "aggressive" space (and other misc. char)
  support in paths.)

- Despite the minimalism and early stage, still fairly comfy & flexible:
  - single-file or subdir test cases
  - cases can have a custom variation (build) of the (common) test subject
  - or basically any arbitrary test env/setup whatsoever
  - trivially lean & simple script format:

    RUN something
    EXPECT some result

  - or as shell commands (as opposed to directly exec'ing; built-ins like
    `echo` must be SH'ed):

    SH echo -n this
    EXPECT this

    SH echo newline
    EXPECT "newline
    "

    SH "echo Dir list:; ls -r"
    SH echo command 3
    EXPECT "Dir list:
    Hi from the test case dir!
    CASE
    command 3
    "

  - or mix in any normal .sh (BB ash) syntax:

    if [ -n "$SOME_FLAG" ]; then
        prepare_something         # no output capture
        RUN stuff                 # output captured as usual
        EXPECT "one thing"        # quoting these is a good habit!
    else
        prepare_something_else
        RUN stuff
        EXPECT "other thing"
    fi

- Multiple test (variant) runs in a single case:

    RUN some command
    RUN other command
    RUN command --with-params

    EXPECT "some result
    some other results
    accumulated
    " # (Assuming those commands print with trailing newlines.)

    or, equivalently, with interleaved EXPECTs:

    RUN some command
    EXPECT "some result
    "
    RUN other command
    EXPECT "some other results
    "
    RUN command --with-params
    EXPECT "accumulated
    "

  - or standalone "EXPECT" files (overriding any EXPECT clauses)

- Check for command exit status:

    EXPECT_ERROR
    RUN thing_returning_nonzero

    EXPECT_ERROR 4
    RUN thing_that_should_return_4

    EXPECT_ERROR ignore
    # For all subsequent steps (until another EXPECT_ERROR)
    RUN retval_doesnt_matter --retval 0
    RUN retval_doesnt_matter --retval 1

    EXPECT_ERROR warn
    RUN make -s something # retval will be noted, but not used

- Arbitrary multi-level test tree hierarchy



- Manual (forced) FAIL, PASS, ABORT

- Arbitrary multi-level test tree hierarchy

- Flexible runner:

  `run` to test all, or `run some*`, or `run this "and that"`

  And no need to be in the test dir, so e.g. `test/run` from the prj. dir
  (if it's the parent of `test`) would also be fine.

  BTW, since there's no reliable way to identify a test dir (you see,
  it's so flexible, it can be anything!...), it's just assumed to be the
  parent of the `_engine` dir currently, or whatever the `TEST_DIR` env.
  var. points to, if set.

  If the test dir is not `_engine/..`, it's recommended to have a simple
  proxy `run` script there (e.g. just a one-liner, executing the real one
  at `.../_engine/run[.cmd]`), which could then conveniently set the
  TEST_DIR variable, and/or pass test case filter params. etc.
  (Just symlinking to `_engine/run` doesn't work yet, but will: #51.)

  NOTE: outside of Windows + BusyBox (the default for me), wildcard patterns
  may need to be in single quotes ('pattern*') to work as expected!

- "GitHub-Actions-ready" MSVC and GCC autobuild (for both test-subject
  and custom test-case code)
  BTW, I've hacked this together just for this exact purpose, in fact.
  (It's ridiculously primitive and limited yet, and C++ only, etc.,
  but good enough for sales...)

- Doesn't require CMake (e.g. to replace trivial single-line compiler
  commands with multi-100 megs of opaque, fragile, ugly complexity)
