## module Caper, lexer functions

"""
Methods for lexing files
"""

struct Lookahead
        text::String
        length::Int
        Lookahead(text::AbstractString) = new(text, length(text))
end

_emit(lexer::Lookahead, index::Int) = lexer.text[index]
_emit(lexer::Lookahead, index) = view(lexer.text, index)
_checkemit(lexer::Lookahead, index) = (index <= lexer.length) ? _emit(lexer, index) : nothing

_find(lexer::Lookahead, p, index) = findnext(p, lexer.text, index)
_seek(lexer::Lookahead, p, index) = something(_find(lexer, p, index), lexer.length + 1)

_rfind(lexer::Lookahead, p, index) = findprev(p, lexer.text, index)
_rseek(lexer::Lookahead, p, index) = something(_rfind(lexer, p, index), 0)

const KeywordString = ["if", "else", "for", "while", "return", "break", "continue"]
const CmpChar = "<=>"
const MathChar = "~&|+-*/%"
const EqualChar = CmpChar * MathChar * '!'
const SpecialChar = "'[]{}()@#!?^,.:;" * EqualChar

_reserved(word::AbstractString) = (word in KeywordString) ? Symbol(word) : word

function Base.iterate(lexer::Lookahead, index=1)
        local i = _find(lexer, !isspace, index)
        !isnothing(i) || return nothing

        local s = _find(lexer, isdigit | isletter | in(SpecialChar), i)
        !isnothing(s) || return nothing

        local c = _emit(lexer, s)
        if isletter(c)
                w = _seek(lexer, !(isdigit | isletter), s)
                v = _emit(lexer, s:w-1)
                _checkemit(lexer, w) == '\'' || return (_reserved(v), w)

                # Literal
                t = _find(lexer, ==('\''), w + 1)
                !isnothing(t) || return nothing

                r = literal(_emit(lexer, w+1:t-1), Symbol(v))
                (r, t + 1)
        elseif isdigit(c)
                t = _seek(lexer, !isdigit, s)
                r = literal(_emit(lexer, s:t-1))
                (r, t)
        elseif c in EqualChar && _checkemit(lexer, s + 1) == '='
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

Emits all tokens in a text.

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

