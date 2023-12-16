## module Caper, parsing functions

"""
Methods for parsing files
"""

const Operator1 = Symbol.(collect("!^"))
const Operator2 = Symbol.([
	'='; collect(MathChar) .* '=';
	collect(MathChar); collect(CmpChar); collect(CmpChar) .* '='; "!="
])

const OpenBraces = Symbol.(collect("([{"))
const CloseBraces = Symbol.(collect(")]}"))

const Keywords = Symbol.(KeywordString)
const Statements = [q"if", q"while", q"for"]
const Commands = [q"break", q"continue", q"goto"] # gasp!

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

_preceeds(lhs, rhs) = (rhs in Operator1) ||
	((lhs in Operator2) && (rhs in Operator2) && Precedence[lhs] <= Precedence[rhs])
_preceeds(token::Symbol) = Base.Fix1(_preceeds, token)

_isa(T::Type) = Base.Fix2(isa, T)

_guard(f::Function, stack) = !isempty(stack) && f(stack[end])

_ifmove(f::Function, stack, out) =
	_guard(f, stack) && (push!(out, pop!(stack)); true)

_row(a) = permutedims(copy(a))

Base.:(==)(a::Pair{Symbol, Int}, b::Symbol) = a.first == b

struct Automata
	lexer::Lookahead
end

# https://en.wikipedia.org/wiki/Shunting_yard_algorithm#The_algorithm_in_detail
function _expression(auto::Automata, index::Int; type=false)
	local out = Any[]
	local stack = Any[]

	intro = nothing
	while (iter = iterate(auto.lexer, index); !isnothing(iter))
		(token, next) = iter
		# @info "postfix" intro token _row(stack) _row(out)
		if !(token isa Symbol)
			push!(out, token)
		elseif token == q";"
			break
		elseif token == q"["
			push!(stack, token)
		elseif token == q"]"
			while _ifmove(!=(q"["), stack, out); end
			isempty(stack) && break
			_ = pop!(stack) # sentinel
			push!(out, :INDEX)
		elseif token == q"("
			if intro in Operator2 || isnothing(intro)
				push!(stack, token)
			else
				push!(stack, token => 0)
			end
		elseif token == q")"
			while _ifmove(!=(q"("), stack, out); end
			isempty(stack) && break
			sentinel = pop!(stack)
			if sentinel isa Pair
				push!(out, :CALL => sentinel.second + 1)
			end
		elseif token == q","
			while _ifmove(!=(q"("), stack, out); end
			isempty(stack) && break
			if stack[end] isa Pair
				n = stack[end].second
				stack[end] = q"(" => n + 1
			end
		elseif token in Operator2
			while _ifmove(!=(q"(") & _preceeds(token), stack, out); end
			push!(stack, token)
		elseif token in Operator1
			if type
				push!(out, token)
			else
				push!(stack, token)
			end
		elseif token == q"::"
			break
		elseif token == q"nil"
			push!(out, token)
		end
		intro = token
		index = next
	end
	while _ifmove(!=(q")"), stack, out); end
	@assert isempty(stack)
	return (out, index)
end


function _expect(auto::Automata, index, cond::Function)
	state = iterate(auto.lexer, index)
	@assert !isnothing(state)
	(token, index) = state
	@assert cond(token)
	(token, index)
end

_expect(auto::Automata, index, expected::Symbol) = _expect(auto, index, ==(expected))

function _declare(auto::Automata, index)
	intro = index
	(out, index) = _expression(auto, index)
	state = iterate(auto.lexer, index)
	@assert !isnothing(state)
	(token, index) = state
	if token == q";"
		node = (q";", out)
	elseif token == q"::"
		(type, _) = _expression(auto, intro; type=true)
		type = isempty(type) ? nothing : type
		(token, index) = _expect(auto, index, _isa(AbstractString))
		(_, index) = _expect(auto, index, q"=")
		(out, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q";")
		node = (q"::", type, token, out)
	else
		@assert false
	end
	(node, index)
end

function _scope(auto::Automata, token, depth, intro, index)
	# @info "scope" token depth intro index
	node = nothing
	if token == q"for" # special form
		(_, index) = _expect(auto, index, q"(")
		(pre, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q";")
		(cond, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q";")
		(post, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q")")
		node = (token, pre, cond, post)
	elseif token in Statements
		(_, index) = _expect(auto, index, q"(")
		(out, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q")")
		node = (token, out)
	elseif token == q"return"
		(out, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q";")
		node = (token, out)
	elseif token in Commands
		state = iterate(auto.lexer, index)
		@assert !isnothing(state)
		(label, index) = state
		if label == q";"
			node = (token, :LOOP)
		else
			@assert label isa AbstractString
			(_, index) = _expect(auto, index, q";")
			node = (token, label)
		end
	elseif token == q"{"
		depth += 1
	elseif token == q"}"
		@assert depth > 0
		depth -= 1
	else
		state = iterate(auto.lexer, index)
		@assert !isnothing(state)
		(peek, ahead) = state
		if peek == q":"
			node = (q":", token)
			index = ahead
		else
			(node, index) = _declare(auto, intro)
		end
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

