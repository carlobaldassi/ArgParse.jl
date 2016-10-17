ArgParse.jl Overview
====================

ArgParse.jl is a package for parsing command-line arguments to
[Julia][julia] programs.

The documentation can be found at
[this link][docs-latest], or in
the [doc directory](doc).

See also the [examples directory](examples).

[![Build Status][build-status-img]][build-status-url]
[![Coverage Status][cov-status-img]][cov-status-url]
[![Build status][appv-status-img]][appv-status-url]

Changes in release 0.4.0
========================

New features
------------

* Added support for vectors of METAVAR names (see [#33][PR33])

Other changes
-------------

* Support for Julia v0.3 was dropped.

Changes in release 0.3.1
========================

New available settings
----------------------

* `fromfile_prexif_chars` (see [#27][PR27])
* `preformatted_desciption`/`preformatted_epilog` (see [#28][PR28])


Changes in release 0.3.0
========================

Breaking changes
----------------

Upgrading from versions 0.2.X to 0.3.X, the following API changes were made,
which may break existing code:

* Option arguments are no longer evaluated by default. This is for security
  reasons. Evaluation can be forced on a per-option basis with the
  `eval_arg=true` setting (although this is discuraged).
* The syntax of the `add_arg_table` function has changed, it now takes a `Dict`
  object instead of an `@options` opbject, since the dependency on the
  Options.jl module was removed. (The `@add_arg_table` macro is unchanged
  though.)

Other changes
-------------

* Documented that overloading the function `ArgParse.parse_item` can be used to
  instruct ArgParse on how to parse custom types. Parse error reporting was
  also improved
* Removed dependecy on the Options.jl module
* Enabled precompilation on Julia 0.4

[julia]: http://julialang.org
[docs-latest]: http://argparsejl.readthedocs.org/en/latest/argparse.html

[build-status-img]: https://api.travis-ci.org/carlobaldassi/ArgParse.jl.png?branch=master
[build-status-url]: https://travis-ci.org/carlobaldassi/ArgParse.jl

[cov-status-img]: https://coveralls.io/repos/carlobaldassi/ArgParse.jl/badge.svg?branch=master&service=github
[cov-status-url]: https://coveralls.io/github/carlobaldassi/ArgParse.jl?branch=master

[appv-status-img]: https://ci.appveyor.com/api/projects/status/5c81omg867fu2gfy/branch/master?svg=true
[appv-status-url]: https://ci.appveyor.com/project/carlobaldassi/argparse-jl/branch/master

[PR27]: https://github.com/carlobaldassi/ArgParse.jl/pull/27
[PR28]: https://github.com/carlobaldassi/ArgParse.jl/pull/28
[PR33]: https://github.com/carlobaldassi/ArgParse.jl/pull/33
