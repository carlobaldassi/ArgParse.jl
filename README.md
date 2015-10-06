ArgParse.jl Overview
====================

ArgParse.jl is a package for parsing command-line arguments to
[Julia](http://julialang.org) programs.

The documentation can be found at
[this link](http://argparsejl.readthedocs.org/en/latest/argparse.html), or in
the [doc directory](doc).

See also the [examples directory](examples).

[![Build Status](https://api.travis-ci.org/carlobaldassi/ArgParse.jl.png?branch=master)](https://travis-ci.org/carlobaldassi/ArgParse.jl)
[![Coverage Status](https://coveralls.io/repos/carlobaldassi/ArgParse.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/carlobaldassi/ArgParse.jl?branch=master)
[![Build status](https://ci.appveyor.com/api/projects/status/5c81omg867fu2gfy/branch/master?svg=true)](https://ci.appveyor.com/project/carlobaldassi/argparse-jl/branch/master)

Changes in release 0.3.0
========================

Breaking changes
----------------

Upgrading from versions 0.2.X to 0.3.X, the following API change was made,
which may break existing code: option arguments are no longer evaluated by
default. This is for security reasons. Evaluation can be forced on a per-option
basis with the `eval_arg=true` setting (although this is discuraged).

Other changes
-------------

* Documented that overloading the function `ArgParse.parse_item` can be used to
  instruct ArgParse on how to parse custom types. Parse error reporting was
  also improved
* Removed dependecy on the Options.jl module
* Enabled precompilation on Julia 0.4
