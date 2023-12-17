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
	q"I" => Numeric{10,Int}(),
	q"U" => Numeric{10,UInt}(),
	q"B" => BitNumeric{1}(),
	q"O" => BitNumeric{3}(),
	q"H" => BitNumeric{4}(),
	q"F" => (s -> parse(Float64, s)),
	q"Char" => Character{UInt8}(),
	q"Utf" => Character{UInt32}(),
	q"Re" => (s -> Regex(s)),
	q"Fmt" => identity,
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

julia> Caper.literal("ff", :H)
0xff
```
"""
function literal(text::AbstractString, prefix::Symbol=:I)
        local fn = get(Literals::Dict{Symbol,Function}, prefix, nothing)
	# N.B. if nothing, can look in environment for user-defined readers
        isnothing(fn) && return nothing
        fn(text)
end

