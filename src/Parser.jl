## module Caper, parsing functions

"""
Methods for parsing files
"""

const Semicolon = Symbol(";")
const Binary = Symbol.([collect(MathChar); collect(CmpChar) .* '='])
const Assign = Symbol.(['='; collect(MathChar) .* '='])
const OpenBraces = Symbol.(collect("([{"))
const CloseBraces = Symbol.(collect(")]}"))
const Keywords = Symbol.(KeywordString)
const Statements = Symbol.(["if", "while", "for"])

const Precedence = Dict{Symbol, Int}(
	:(=) => 1,
	:(|=) => 1, Symbol("~=") => 1, :(&=) => 1,
	:(+=) => 1, :(-=) => 1, :(*=) => 1,
	:(/=) => 1, :(%=) => 1,

	:(|) => 2,
	:(~) => 3,
	:(&) => 4,
	:(==) => 5, :(!=) => 5,
	:(<) => 6, :(>) => 6, :(<=) => 6, :(>=) => 6,
	:(+) => 7, :(-) => 7,
	:(*) => 8, :(/) => 8, :(%) => 8,
)

@assert all((b in keys(Precedence)) for b = Binary)

mutable struct Pushdown
	stack::Vector{Any}
	precedence::Int
	Pushdown() = new(Any[], 0)
end

_top(stack) = isempty(stack) ? nothing : stack[end]

function _semicolon(stack)
	@assert length(stack) > 0
	stmt = pop!(stack)
	if isempty(stack)
		(Semicolon, stmt)
	elseif _top(stack) in Assign
		equal = pop!(stack)
		name = pop!(stack)
		@assert name isa AbstractString
		(Semicolon, name, equal, stmt)
	elseif _top(stack) in Keywords
		keyword = pop!(stack)
		(Semicolon, keyword, stmt)
	else
		(Semicolon, stmt)
	end
end

function _args(stack, n)
	ret = Any[]
	sizehint!(ret, n)
	for _ = 1:n
		push!(ret, pop!(stack))
	end
	return reverse!(ret)
end

function _unbrace(brace::Symbol, stack)
	sentinel = OpenBraces[findfirst(==(brace), CloseBraces)]
	opening = findlast(==(sentinel), stack)
	@assert !isnothing(opening)

	args = _args(stack, length(stack)-opening)
	_ = pop!(stack) # sentinel

	if _top(stack) in Statements
		keyword = pop!(stack)
		(keyword, args)
	elseif _top(stack) isa AbstractString && brace == Symbol("]")
		array = pop!(stack)
		return (:index, array, args[1])
	elseif _top(stack) isa AbstractString && brace == Symbol(")")
		fn = pop!(stack)
		@assert all(==(Symbol(",")), args[2:2:end])
		(:call, fn, args[1:2:end])
	else
		(sentinel, args)
	end
end

_ingest(auto::Pushdown, next::AbstractString) = push!(auto.stack, next)

function _ingest(auto::Pushdown, next::T) where {T<:Number}
	if length(auto.stack) >= 2 && _top(auto.stack) in Binary
                op = pop!(auto.stack)
                prev = pop!(auto.stack)
                node = (op, prev, next)
        else
                node = next
        end
        push!(auto.stack, node)
end

function _ingest(auto::Pushdown, next::Symbol)
        if next == Semicolon
		node = _semicolon(auto.stack)
        elseif next in OpenBraces
                node = next
        elseif next in CloseBraces
		node = _unbrace(next, auto.stack)
        elseif next in Binary || next in Assign
		auto.precedence = Precedence[next]
		node = next
        else
		node = next
        end
	push!(auto.stack, node)
end

"""
	ast(text)

Reads a text into a datastructure.

# Examples

```jldoctest
julia> using Caper

julia> Caper.ast("x |= h'1f'; ")
1-element Vector{Any}:
 (Symbol(";"), "x", :|=, 0x1f)

julia> Caper.ast("return 1 + h'1f';")
1-element Vector{Any}:
 (Symbol(";"), :return, (:+, 1, 0x1f))
```
"""
function ast(text::AbstractString)
	auto = Pushdown()
        for next = lex(text)
                _ingest(auto, next)
        end
        return auto.stack
end

