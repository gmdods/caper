"A module for reading and interpreting macros"
module Reader

export literal

"""
	literal(text)

Tries to read the given text as a literal

# Examples

```jldoctest
julia> using Caper

julia> Caper.literal("01234")
1234
```
"""
literal(text::AbstractString) = parse(Int, text)



end # module Reader
