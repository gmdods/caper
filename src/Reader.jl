"A module for reading and interpreting macros"
module Reader

export shrink, literal


const UnsignedTypes = [UInt8, UInt16, UInt32, UInt64, UInt]
const UnsignedWidths = [8, 16, 32, 64]

"""
	shrink(type, nbits)

Returns the smallest restricted type that fits `n` bits.

# Examples

```jldoctest
julia> using Caper

julia> Caper.shrink(UInt, 8)
UInt8

julia> Caper.shrink(UInt, 41)
UInt64
```
"""
function shrink(::Type{UInt}, nbits::Int)
        local r = searchsortedfirst(UnsignedWidths::Vector{Int}, nbits)
        (UnsignedTypes::Vector{DataType})[r]
end

function single_character(s::AbstractString)
        local e = unescape_string(s)
        length(e) == 1 || return nothing
        e[1]
end

ascii(c::Char) = isascii(c) ? UInt8(c) : nothing

const Literals = Dict{Symbol,Function}(
        :i => (s -> parse(Int, s)),
        :u => (s -> parse(UInt, s)),
        :b => (s -> parse(shrink(UInt, length(s)), s; base=2)),
        :h => (s -> parse(shrink(UInt, 4 * length(s)), s; base=16)),
        :f => (s -> parse(Float64, s)),
        :char => (s -> ascii(single_character(s))),
        :utf => (s -> codepoint(single_character(s))),
        :re => (s -> Regex(s)),
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
        local fn = get(Literals::Dict{Symbol,Function}, prefix, nothing)
        isnothing(fn) && return nothing
        fn(text)
end



end # module Reader
