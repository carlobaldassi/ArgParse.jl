# Conflicts and overrides

Conflicts between arguments, be them options, positional arguments or commands, can arise for a variety of reasons:

* Two options have the same name (either long or short)
* Two arguments have the same destination key, but different types (e.g. one is `Any` and the other `String`)
* Two arguments have the same destination key, but incompatible actions (e.g. one does `:store_arg` and the other
  `:append_arg`)
* Two positional arguments have the same metavar (and are therefore indistinguishable in the usage and help screens
  and in error messages)
* An argument and a command, or two commands, have the same destination key.

When the general setting `error_on_conflict` is `true`, or any time the specific `force_override` table entry
setting is `false`, any of the above conditions leads to an error.

On the other hand, setting `error_on_conflict` to `false`, or `force_override` to `true`, will try to force
the resolution of most of the conflicts in favor of the newest added entry. The general rules are the following:

* In case of duplicate options, all conflicting forms of the older options are removed; if all forms of an
  option are removed, the option is deleted entirely
* In case of duplicate destination key and incompatible types or actions, the older argument is deleted
* In case of duplicate positional arguments metavars, the older argument is deleted
* A command can override an argument with the same destination key
* However, an argument can never override a command if they have the same destination key; neither can
  a command override another command when added with `@add_arg_table` (compatible commands are merged
  by [`import_settings`](@ref) though)
