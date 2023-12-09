"A module for reading and interpreting macros"
module Reader

export width, literal

const UnsignedTypes = [UInt8, UInt16, UInt32, UInt64, UInt];

"""
	width(n)

Returns the smallest Unsigned type that fits `n` bits.

# Examples

```jldoctest
julia> using Caper

julia> Caper.width(8)
UInt8

julia> Caper.width(41)
UInt64
```
"""
function width(n::Int)
	local r = searchsortedfirst([8, 16, 32, 64], n)
	(UnsignedTypes::Vector{DataType})[r]
end


const Literals = Dict{Symbol, Function}(
	:i => (s -> parse(Int, s)),
	:u => (s -> parse(UInt, s)),
	:b => (s -> parse(width(length(s)), s; base=2)),
	:h => (s -> parse(width(4 * length(s)), s; base=16)),
)

"""
	literal(text; prefix=:i)

Tries to read the given text as a literal

# Examples

```jldoctest
julia> using Caper

julia> Caper.literal("01234")
1234

julia> Caper.literal("ff"; prefix=:h)
0xff
```
"""
function literal(text::AbstractString; prefix::Symbol=:i)
	local fn = get(Literals::Dict{Symbol, Function}, prefix, nothing)
	isnothing(fn) && return nothing
	fn(text)
end



end # module Reader
