## module Caper, lexer functions

Base.:|(fn::Vararg{<:Function,N}) where {N} = x -> mapreduce(f -> f(x), |, fn)
Base.:&(fn::Vararg{<:Function,N}) where {N} = x -> mapreduce(f -> f(x), &, fn)


struct Lookahead
	text::String
	ℓ::Int
	Lookahead(text::AbstractString) =
		new(text, length(text))
end

emit(L::Lookahead, index::Int) = L.text[index]
emit(L::Lookahead, index) = view(L.text, index)

find(L::Lookahead, p::Function, index::Int) = findnext(p, L.text, index)
seek(L::Lookahead, p::Function, index::Int) = something(find(L, p, index), L.ℓ+1)

rfind(L::Lookahead, p::Function, index::Int) = findprev(p, L.text, index)
rseek(L::Lookahead, p::Function, index::Int) = something(rfind(L, p, index), 0)

function Base.iterate(L::Lookahead, state=1)
	local i = find(L, !isspace, state)
	!isnothing(i) || return nothing
	local s = find(L, isdigit | in("'+-~^&|"), i)
        !isnothing(s) || return nothing
	local c = emit(L, s)
        if isdigit(c)
		t = seek(L, !isdigit, s)
		r = literal(emit(L, s:t-1))
		(r, t)
	elseif c == '\''
		p = rseek(L, !isletter, s-1)
		t = find(L, ==('\''), s+1)
		!isnothing(t) || return nothing
		r = literal(emit(L, s+1:t-1), Symbol(emit(L, p+1:s-1)))
		(r, t+1)
	else
		r = Symbol(emit(L, s))
		(r, s+1)
        end
end

Base.IteratorEltype(::Type{Lookahead}) = Base.EltypeUnknown()
Base.IteratorSize(::Type{Lookahead}) = Base.SizeUnknown()

"""
Methods for lexing files
"""


"""
	lex(text)

Reads a text into a datastructure.

# Examples

```jldoctest
julia> using Caper

julia> Caper.lex("1 + 2")
3-element Vector{Any}:
 1
  :+
 2

julia> Caper.lex("h'ff' ~ h'e4'")
3-element Vector{Any}:
 0xff
     :~
 0xe4
```
"""
function lex(text::AbstractString)
	collect(Lookahead(text))
end

