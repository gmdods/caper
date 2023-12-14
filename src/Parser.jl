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

_isoperator(token::Symbol) = token in Binary || token in Assign
_preceeds(lhs::Symbol, rhs::Symbol) =
	_isoperator(lhs) && _isoperator(rhs) && Precedence[lhs] <= Precedence[rhs]

_top(stack) = isempty(stack) ? nothing : stack[end]

struct Automata
	lexer::Lookahead
end

# https://en.wikipedia.org/wiki/Shunting_yard_algorithm#The_algorithm_in_detail
function _expression(auto::Automata, index::Int)
	local out = Any[]
	local stack = Any[]

	while (iter = iterate(auto.lexer, index); !isnothing(iter))
		(token, next) = iter
		if token isa AbstractString
			push!(stack, token)
		elseif !(token isa Symbol)
			push!(out, token)
		elseif token == Symbol(";")
			break
		elseif token == Symbol("[") || token == Symbol("(")
			push!(stack, token)
		elseif token == Symbol("]") || token == Symbol(")")
			opening = (token == Symbol("]")) ? Symbol("[") : Symbol("(")
			while !isempty(stack) && stack[end] != opening
				push!(out, pop!(stack))
			end
			isempty(stack) && break
			_ = pop!(stack) # sentinel
			if !isempty(stack) && stack[end] isa AbstractString
				push!(out, pop!(stack))
			end
			token == Symbol("]") && push!(out, token)
		elseif token == Symbol(",")
			while !isempty(stack) && stack[end] != Symbol("(")
				push!(out, pop!(stack))
			end
			isempty(stack) && break
		elseif token in Binary || token in Assign
			if !isempty(stack) && stack[end] isa AbstractString
				push!(out, pop!(stack))
			end

			while !isempty(stack) && _preceeds(token, stack[end])
				push!(out, pop!(stack))
			end
			push!(stack, token)
		end
		index = next
	end
	while !isempty(stack)
		operator = pop!(stack)
		@assert operator != Symbol(")")
		push!(out, operator)
	end
	return (out, index)
end

function _scope(auto::Automata, token, depth, index, ahead)
	# @info "scope" token depth index ahead
	if token in Statements
		(parenthesis, index) = iterate(auto.lexer, ahead)
		@assert parenthesis == Symbol("(")
		(out, ahead) = _expression(auto, index)
		(parenthesis, index) = iterate(auto.lexer, ahead)
		@assert parenthesis == Symbol(")")
		node = (token, out)
	elseif token == :return
		(out, ahead) = _expression(auto, ahead)
		(semicolon, index) = iterate(auto.lexer, ahead)
		@assert semicolon == Symbol(";")
		node = (token, out)
	elseif token == Symbol("{")
		node = nothing
		depth += 1
		index = ahead
	elseif token == Symbol("}")
		node = nothing
		@assert depth > 0
		depth -= 1
		index = ahead
	else
		(out, ahead) = _expression(auto, index)
		(semicolon, index) = iterate(auto.lexer, ahead)
		@assert semicolon == Symbol(";")
		node = (semicolon, out)
	end
	(node, depth, index)
end

@enum AutomataState TopLevel Scope

function Base.iterate(auto::Automata, stateful=(TopLevel, 0, 1))
	(state, depth, index) = stateful
	iter = iterate(auto.lexer, index)
	!isnothing(iter) || return nothing
	(token, ahead) = iter

	if state == TopLevel || state == Scope
		while ((node, depth, index) = _scope(auto, token, depth, index, ahead);
			isnothing(node))
			iter = iterate(auto.lexer, index)
			!isnothing(iter) || return nothing
			(token, ahead) = iter
		end
		(depth => node, (Scope, depth, index))
	end
end

Base.eltype(::Type{Automata}) = Pair{Int, Any}
Base.IteratorSize(::Type{Automata}) = Base.SizeUnknown()

"""
	ast(text)

Reads a text into a datastructure.

# Examples

```jldoctest
julia> using Caper

julia> Caper.ast("x |= h'1f'; ")
1-element Vector{Pair{Int64, Any}}:
 0 => (Symbol(";"), Any["x", 0x1f, :|=])

julia> Caper.ast("return 1 + h'1f';")
1-element Vector{Pair{Int64, Any}}:
 0 => (:return, Any[1, 0x1f, :+])
```
"""
function ast(text::AbstractString)
	return collect(Automata(Lookahead(text)))
end

