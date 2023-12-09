## module Caper, reader functions

"""
Methods for reading and interpreting macros
"""

const UnsignedTypes = [UInt8, UInt16, UInt32, UInt64, UInt]
const UnsignedWidths = [8, 16, 32, 64]

function _shrink(::Type{UInt}, nbits::Int)
        local r = searchsortedfirst(UnsignedWidths::Vector{Int}, nbits)
        (UnsignedTypes::Vector{DataType})[r]
end

function _single_character(s::AbstractString)
        local e = unescape_string(s)
        length(e) == 1 || return nothing
        e[1]
end

ascii(c::Char) = isascii(c) ? UInt8(c) : nothing

struct BitNumeric{B} <: Function end
(reader::BitNumeric{B})(s::AbstractString) where {B} =
        parse(_shrink(UInt, length(s) * B), s; base=1 << B)

struct Numeric{N,T} <: Function end
(reader::Numeric{N,T})(s::AbstractString) where {N,T<:Integer} = parse(T, s; base=N)

const Literals = Dict{Symbol,Function}(
        :i => Numeric{10,Int}(),
        :u => Numeric{10,UInt}(),
        :b => BitNumeric{1}(),
        :o => BitNumeric{3}(),
        :h => BitNumeric{4}(),
        :f => (s -> parse(Float64, s)),
        :char => ascii ∘ _single_character,
        :utf => codepoint ∘ _single_character,
        :re => (s -> Regex(s)),
)

"""
	literal(text, prefix=:i)

Tries to read the given text as a literal

# Examples

```jldoctest
julia> using Caper

julia> Caper.literal("01234")
1234

julia> Caper.literal("ff", :h)
0xff
```
"""
function literal(text::AbstractString, prefix::Symbol=:i)
        local fn = get(Literals::Dict{Symbol,Function}, prefix, nothing)
        isnothing(fn) && return nothing
        fn(text)
end

