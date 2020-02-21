# ArgParse.jl

| **Documentation**                                                         | **Build Status**                                             |
|:-------------------------------------------------------------------------:|:------------------------------------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][travis-img]][travis-url][![][codecov-img]][codecov-url] |

ArgParse.jl is a package for parsing command-line arguments to
[Julia][julia] programs.

### Installation and usage

To install the module, use Julia's package manager: start pkg mode by pressing `]` and then enter:

```
(v1.3) pkg> add ArgParse
```

Dependencies will be installed automatically.
The module can then be loaded like any other Julia module:

```
julia> using ArgParse
```

### Documentation

- [**STABLE**][docs-stable-url] &mdash; **most recently tagged version of the documentation.**
- [**DEV**][docs-dev-url] &mdash; *in-development version of the documentation.*

See also the examples in the [examples directory](examples).

## Changes in release 1.1.0

* Try using the constructor for types that don't define a `convert` method from `AbstractString`

## Changes in release 1.0.1

* Small fixes in docs

## Changes in release 1.0.0

* Drop support for Julia versions v0.6/v0.7
* Renamed a few functions and macros (old versions can be used but produce deprecation warnings):
  + `@add_arg_table` → `@add_arg_table!`
  + `add_arg_table` → `add_arg_table!`
  + `add_arg_group` → `add_arg_group!`
  + `set_default_arg_group` → `set_default_arg_group!`
  + `import_settings` → `import_settings!`. The signature of this function has also changed:
    `args_only` is now a keyword argument
* Parsing does not exit julia by default when in interactive mode now
* Added mutually-exclusive and/or required argument groups
* Added command aliases

## Changes in release 0.6.2

* Fix a remaining compatibility issue (`@warn`)

## Changes in release 0.6.1

* Testing infrastructure update, tiny docs fixes

## Changes in release 0.6.0

* Added support for Julia v0.7, dropped support for Julia v0.5.
* Added `exit_after_help` setting to control whether to exit julia after help/version info is displayed
  (which is still the defult) or to just abort the parsing and return `nothing` instead.

## Changes in release 0.5.0

* Added support for Julia v0.6, dropped support for Julia v0.4.
* The default output type is now `Dict{String,Any}`, as stated in the docs,
  rather than `Dict{AbstractString,Any}`.
* Added docstrings, moved documentation to Documenter.jl

## Changes in release 0.4.0

### New features

* Added support for vectors of METAVAR names (see [#33][PR33])

### Other changes

* Support for Julia v0.3 was dropped.

## Changes in release 0.3.1

### New available settings

* `fromfile_prexif_chars` (see [#27][PR27])
* `preformatted_desciption`/`preformatted_epilog` (see [#28][PR28])

## Changes in release 0.3.0

### Breaking changes

Upgrading from versions 0.2.X to 0.3.X, the following API changes were made,
which may break existing code:

* Option arguments are no longer evaluated by default. This is for security
  reasons. Evaluation can be forced on a per-option basis with the
  `eval_arg=true` setting (although this is discuraged).
* The syntax of the `add_arg_table` function has changed, it now takes a `Dict`
  object instead of an `@options` opbject, since the dependency on the
  Options.jl module was removed. (The `@add_arg_table` macro is unchanged
  though.)

### Other changes

* Documented that overloading the function `ArgParse.parse_item` can be used to
  instruct ArgParse on how to parse custom types. Parse error reporting was
  also improved
* Removed dependecy on the Options.jl module
* Enabled precompilation on Julia 0.4


[Julia]: http://julialang.org

[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://carlobaldassi.github.io/ArgParse.jl/stable
[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://carlobaldassi.github.io/ArgParse.jl/dev

[travis-img]: https://travis-ci.com/carlobaldassi/ArgParse.jl.svg?branch=master
[travis-url]: https://travis-ci.com/carlobaldassi/ArgParse.jl

[codecov-img]: https://codecov.io/gh/carlobaldassi/ArgParse.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/carlobaldassi/ArgParse.jl

[PR27]: https://github.com/carlobaldassi/ArgParse.jl/pull/27
[PR28]: https://github.com/carlobaldassi/ArgParse.jl/pull/28
[PR33]: https://github.com/carlobaldassi/ArgParse.jl/pull/33
