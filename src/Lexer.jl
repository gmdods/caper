## module Caper, lexer functions

"""
Methods for lexing files
"""

struct _Lexer
        text::String
        length::Int
        _Lexer(text::AbstractString) = new(text, length(text))
end

_emit(lexer::_Lexer, index::Int) = lexer.text[index]
_emit(lexer::_Lexer, index) = view(lexer.text, index)
_checkemit(lexer::_Lexer, index::Int) = (index <= lexer.length) ? _emit(lexer, index) : nothing
_checkemit(lexer::_Lexer, index) = checkbounds(Bool, lexer.text, index) ? _emit(lexer, index) : nothing

_find(lexer::_Lexer, p, index) = findnext(p, lexer.text, index)
_seek(lexer::_Lexer, p, index) = something(_find(lexer, p, index), lexer.length + 1)

_rfind(lexer::_Lexer, p, index) = findprev(p, lexer.text, index)
_rseek(lexer::_Lexer, p, index) = something(_rfind(lexer, p, index), 0)

const KeywordString = [
	"_", "nil", "fn", "include", "defer",
	"if", "else", "for", "while",
	"return", "break", "continue"
]

const CmpChar = "<=>"
const MathChar = "~&|+-*/%"
const EqualChar = CmpChar * MathChar * '!'
const SpecialChar = "\"'[]{}()@#!?^,.:;" * EqualChar
const Sigils = "@"
const Quoted = "\'\""
const Comment = "//"

function _quoted(lexer::_Lexer, s::Int)
	c = _checkemit(lexer, s)
	@assert c in Quoted
	t = _find(lexer, ==(c), s + 1)
	!isnothing(t) || return nothing
	r = _emit(lexer, s+1:t-1)
	(r, t + 1)
end

_reserved(word::AbstractString) = (word in KeywordString) ? Symbol(word) : Label(word)

function Base.iterate(lexer::_Lexer, index=1)
        index = _find(lexer, !isspace, index)
        !isnothing(index) || return nothing
	while _checkemit(lexer, index:index+1) == Comment
		index = _find(lexer, ==('\n'), index)
		index = _find(lexer, !isspace, index)
		!isnothing(index) || return nothing
	end

        local s = _find(lexer, isdigit | isname | in(SpecialChar), index)
        !isnothing(s) || return nothing

        local c = _emit(lexer, s)
        if isname(c)
                w = _seek(lexer, !(isdigit | isname), s)
                v = _emit(lexer, s:w-1)
		peek = _checkemit(lexer, w)
                peek in Quoted || return (_reserved(v), w)
		(q, t) = _quoted(lexer, w)
		r = literal(q, Symbol(capitalize(v)))
		(r, t)
        elseif isdigit(c)
                t = _seek(lexer, !isdigit, s)
                r = literal(_emit(lexer, s:t-1))
                (r, t)
	elseif c in Quoted
		_quoted(lexer, s)
        elseif c in EqualChar && _checkemit(lexer, s + 1) == '='
                r = Symbol(c * '=')
                (r, s + 2)
        elseif c in Sigils && _checkemit(lexer, s + 1) == '{'
                r = Symbol(c * '{')
                (r, s + 2)
        else
                r = Symbol(c)
                (r, s + 1)
        end
end

Base.IteratorEltype(::Type{_Lexer}) = Base.EltypeUnknown()
Base.IteratorSize(::Type{_Lexer}) = Base.SizeUnknown()

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
     !"x"
     :|=
 0x1f
```
"""
function lex(text::AbstractString)
        collect(_Lexer(text))
end

