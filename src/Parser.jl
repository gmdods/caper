## module Caper, parsing functions

"""
Methods for parsing files
"""

const Binary = Symbol.([collect(MathChar); collect(CmpChar) .* '='])
const Assign = Symbol.(['='; collect(MathChar) .* '='])
const Operator2 = [Binary; Assign]

const OpenBraces = Symbol.(collect("([{"))
const CloseBraces = Symbol.(collect(")]}"))

const Keywords = Symbol.(KeywordString)
const Statements = [q"if", q"while", q"for"]

const Precedence = Dict{Symbol, Int}(
	q"=" => 1,
	q"|=" => 1, q"~=" => 1, q"&=" => 1,
	q"+=" => 1, q"-=" => 1, q"*=" => 1,
	q"/=" => 1, q"%=" => 1,

	q"|" => 2,
	q"~" => 3,
	q"&" => 4,
	q"==" => 5, q"!=" => 5,
	q"<" => 6, q">" => 6, q"<=" => 6, q">=" => 6,
	q"+" => 7, q"-" => 7,
	q"*" => 8, q"/" => 8, q"%" => 8,
)

@assert all((o in keys(Precedence)) for o = Operator2)

_preceeds(lhs::Symbol, rhs::Symbol) =
	(lhs in Operator2) && (rhs in Operator2) && Precedence[lhs] <= Precedence[rhs]
_preceeds(token::Symbol) = Base.Fix1(_preceeds, token)

_isa(T::Type) = Base.Fix2(isa, T)

_guard(f::Function, stack) = !isempty(stack) && f(stack[end])

_ifmove(f::Function, stack, out) =
	_guard(f, stack) && (push!(out, pop!(stack)); true)

_row(a) = permutedims(copy(a))

struct Automata
	lexer::Lookahead
end

# https://en.wikipedia.org/wiki/Shunting_yard_algorithm#The_algorithm_in_detail
function _expression(auto::Automata, index::Int)
	local out = Any[]
	local stack = Any[]

	while (iter = iterate(auto.lexer, index); !isnothing(iter))
		(token, next) = iter
		# @info "postfix" token _row(stack) _row(out)
		if token isa AbstractString
			push!(stack, token)
		elseif !(token isa Symbol)
			push!(out, token)
		elseif token == q";"
			break
		elseif token == q"["
			push!(stack, token)
		elseif token == q"]"
			while _ifmove(!=(q"["), stack, out); end
			isempty(stack) && break
			_ = pop!(stack) # sentinel
			if _ifmove(_isa(AbstractString), stack, out)
				push!(out, :INDEX)
			end
		elseif token == q"("
			push!(stack, token)
		elseif token == q")"
			while _ifmove(!=(q"("), stack, out); end
			isempty(stack) && break
			_ = pop!(stack) # sentinel
			if _ifmove(_isa(AbstractString), stack, out)
				push!(out, :CALL)
			end
		elseif token == q","
			while _ifmove(!=(q"("), stack, out); end
			isempty(stack) && break
		elseif token in Operator2
			while _ifmove(!=(q"("), stack, out); end
			_ifmove(_isa(AbstractString), stack, out)
			_ifmove(_preceeds(token), stack, out)
			push!(stack, token)
		end
		index = next
	end
	while _ifmove(!=(q")"), stack, out); end
	@assert isempty(stack)
	return (out, index)
end

function _scope(auto::Automata, token, depth, intro, index)
	# @info "scope" token depth intro index
	node = nothing
	if token in Statements
		(parenthesis, index) = iterate(auto.lexer, index)
		@assert parenthesis == q"("
		(out, index) = _expression(auto, index)
		(parenthesis, index) = iterate(auto.lexer, index)
		@assert parenthesis == q")"
		node = (token, out)
	elseif token == :return
		(out, index) = _expression(auto, index)
		(semicolon, index) = iterate(auto.lexer, index)
		@assert semicolon == q";"
		node = (token, out)
	elseif token == q"{"
		depth += 1
	elseif token == q"}"
		@assert depth > 0
		depth -= 1
	else
		(out, index) = _expression(auto, intro)
		(semicolon, index) = iterate(auto.lexer, index)
		@assert semicolon == q";"
		node = (semicolon, out)
	end
	(node, depth, index)
end

@enum AutomataState TopLevel Scope

function Base.iterate(auto::Automata, stateful=(TopLevel, 0, 1))
	(state, depth, index) = stateful
	iter = iterate(auto.lexer, index)
	!isnothing(iter) || return nothing
	((token, index), intro) = iter, index

	if state == TopLevel || state == Scope
		node = nothing
		while ((node, depth, index) = _scope(auto, token, depth, intro, index);
			isnothing(node))
			iter = iterate(auto.lexer, index)
			!isnothing(iter) || return nothing
			((token, index), intro) = iter, index
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

