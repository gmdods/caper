## module Caper, lexer functions

"""
Methods for lexing files
"""

struct Lookahead
        text::String
        ℓ::Int
        Lookahead(text::AbstractString) =
                new(text, length(text))
end

_emit(L::Lookahead, index::Int) = L.text[index]
_emit(L::Lookahead, index) = view(L.text, index)
_checkemit(L::Lookahead, index::Int) = (index <= L.ℓ) ? _emit(L, index) : nothing

_find(L::Lookahead, p::Function, index::Int) = findnext(p, L.text, index)
_seek(L::Lookahead, p::Function, index::Int) = something(_find(L, p, index), L.ℓ + 1)

_rfind(L::Lookahead, p::Function, index::Int) = findprev(p, L.text, index)
_rseek(L::Lookahead, p::Function, index::Int) = something(_rfind(L, p, index), 0)

function _enclose(L::Lookahead, s::Int)
        _emit(L, s) == '\'' || return nothing
end

const CharEqual = "<=>~&|+-*/%"
const SpecialChar = "'[]{}()@#!?^,.:;" * CharEqual

function Base.iterate(L::Lookahead, state=1)
        local i = _find(L, !isspace, state)
        !isnothing(i) || return nothing

        local s = _find(L, isdigit | isletter | in(SpecialChar), i)
        !isnothing(s) || return nothing

        local c = _emit(L, s)
        if isletter(c)
                w = _seek(L, !(isdigit | isletter), s)
                v = _emit(L, s:w-1)
                _checkemit(L, w) == '\'' || return (v, w) # Name

		# Literal
                t = _find(L, ==('\''), w + 1)
                !isnothing(t) || return nothing

                r = literal(_emit(L, w+1:t-1), Symbol(v))
                (r, t + 1)
        elseif isdigit(c)
                t = _seek(L, !isdigit, s)
                r = literal(_emit(L, s:t-1))
                (r, t)
        elseif c in CharEqual && _checkemit(L, s + 1) == '='
                r = Symbol(c * '=')
                (r, s + 2)
        else
                r = Symbol(c)
                (r, s + 1)
        end
end

Base.IteratorEltype(::Type{Lookahead}) = Base.EltypeUnknown()
Base.IteratorSize(::Type{Lookahead}) = Base.SizeUnknown()

"""
	lex(text)

Reads a text into a datastructure.

# Examples

```jldoctest
julia> using Caper

julia> Caper.lex("1 + h'1f'")
3-element Vector{Any}:
    1
     :+
 0x1f

julia> Caper.lex("x |= h'1f'")
3-element Vector{Any}:
     "x"
     :|=
 0x1f
```
"""
function lex(text::AbstractString)
        collect(Lookahead(text))
end

