# Parsing to custom types

If you specify an `arg_type` setting (see the [Argument entry settings](@ref) section) for an
option or an argument, `parse_args` will try to parse it, i.e. to convert the string to the
specified type. For `Number` types, Julia's built-in `parse` function will be used. For other
types, first `convert` and then the type's constructor will be tried. In order to extend this
functionality, e.g. to user-defined custom types, without adding methods to `convert` or the
constructor, you can overload the `ArgParse.parse_item` function. Example:

```julia
struct CustomType
    val::Int
end

function ArgParse.parse_item(::Type{CustomType}, x::AbstractString)
    return CustomType(parse(Int, x))
end
```

Note that the second argument needs to be of type `AbstractString` to avoid ambiguity errors. Also
note that if your type is parametric (e.g. `CustomType{T}`), you need to overload the function like
this: `function ArgParse.parse_item(::Type{CustomType{T}}, x::AbstractString) where {T}`.
