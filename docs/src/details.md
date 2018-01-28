# Parsing details

During parsing, `parse_args` must determine whether an argument is an option, an option argument, a positional
argument, or a command. The general rules are explained in the [`parse_args`](@ref) documentation, but
ambiguities may arise under particular circumstances. In particular, negative numbers like `-1` or `-.1e5`
may look like options. Under the default settings, such options are forbidden, and therefore those tokens are
always recognized as non-options. However, if the `allow_ambiguous_opts` general setting is `true`, existing
options in the argument table will take precedence: for example, if the option `-1` is added, and it takes an
argument, then `-123` will be parsed as that option, and `23` will be its argument.

Some ambiguities still remains though, because the `ArgParse` module can actually accept and parse expressions,
not only numbers (although this is not the default), and therefore one may try to pass arguments like `-e` or
`-pi`; in that case, these will always be at risk of being recognized as options. The easiest workaround is to
put them in parentheses, e.g. `(-e)`.

When an option is declared to accept a fixed positive number of arguments or the remainder of the command line
(i.e. if `nargs` is a non-zero number, or `'A'`, or `'R'`), `parse_args` will not try to check if the
argument(s) looks like an option.

If `nargs` is one of `'?'` or `'*'` or `'+'`, then `parse_args` will take in only arguments which do not
look like options.

When `nargs` is `'+'` or `'*'` and an option is being parsed, then using the `'='` character will mark what
follows as an argument (i.e. not an option); all which follows goes under the rules explained above. The same is true
when short option groups are being parsed. For example, if the option in question is `-x`, then both
`-y -x=-2 4 -y` and `-yx-2 4 -y` will parse `"-2"` and `"4"` as the arguments of `-x`.

Finally, note that with the `eval_arg` setting expressions are evaluated during parsing, which means that there is no
safeguard against passing things like ```run(`rm -rf someimportantthing`)``` and seeing your data evaporate
(don't try that!). Be careful and generally try to avoid using the `eval_arg` setting.
