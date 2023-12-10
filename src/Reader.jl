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

struct BitNumeric{B} <: Function end
function (::BitNumeric{B})(s::AbstractString) where {B}
        tryparse(_shrink(UInt, length(s) * B), s; base=1 << B)
end

struct Numeric{N,T} <: Function end
function (::Numeric{N,T})(s::AbstractString) where {N,T<:Integer}
	tryparse(T, s; base=N)
end

struct Character{T} <: Function end
function (::Character{UInt8})(s::AbstractString)
	ascii(tryparse(Char, s))
end
function (::Character{UInt32})(s::AbstractString)
	codepoint(tryparse(Char, s))
end

const Literals = Dict{Symbol,Function}(
	:i => Numeric{10,Int}(),
	:u => Numeric{10,UInt}(),
	:b => BitNumeric{1}(),
	:o => BitNumeric{3}(),
	:h => BitNumeric{4}(),
	:f => (s -> parse(Float64, s)),
	:char => Character{UInt8}(),
	:utf => Character{UInt32}(),
	:re => (s -> Regex(s)),
	# N.B. Add more literals here
)

"""
	literal(text, prefix=:i)

Tries to read the given text as a literal.

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
	# N.B. if nothing, can look in environment for user-defined readers
        isnothing(fn) && return nothing
        fn(text)
end

