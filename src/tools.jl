## module Caper, extending Base functions

Base.ascii(c::Char) = isascii(c) ? UInt8(c) : nothing

function Base.tryparse(::Type{Char}, s::AbstractString)
        local char = unescape_string(s)
        length(char) == 1 || return nothing
        char[1]
end

Base.parse(::Type{Char}, s::AbstractString) = convert(Char, tryparse(Char, s))

Base.:|(fn::Vararg{<:Function,N}) where {N} = x -> mapreduce(f -> f(x), |, fn)
Base.:&(fn::Vararg{<:Function,N}) where {N} = x -> mapreduce(f -> f(x), &, fn)