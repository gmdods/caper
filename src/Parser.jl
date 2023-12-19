## module Caper, parsing functions

"""
Methods for parsing files
"""

const Operator1_Pre = Symbol.(collect("!"))
const Operator1_Post = Symbol.(collect("^"))
const Operator2 = Symbol.([
	'='; collect(MathChar) .* '=';
	collect(MathChar); collect(CmpChar); collect(CmpChar) .* '='; "!="
])

const OpenBraces = Symbol.(collect("([{"))
const CloseBraces = Symbol.(collect(")]}"))
const CSVs = Symbol.(['('; collect(Sigils) .* '{'])

const Keywords = Symbol.(KeywordString)
const Statements = [q"if", q"while", q"for"]
const Labels = [q"break", q"continue", q"goto"] # gasp!

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

_preceeds(lhs, rhs) = (rhs in Operator1_Pre) ||
	((lhs in Operator2) && (rhs in Operator2) && Precedence[lhs] <= Precedence[rhs])
_preceeds(token::Symbol) = Base.Fix1(_preceeds, token)

_guard(f::Function, stack) = !isempty(stack) && f(stack[end])

_ifmove(f::Function, stack, out) =
	_guard(f, stack) && (push!(out, pop!(stack)); true)

_row(a) = permutedims(copy(a))

issigil(c::Symbol) = endswith(string(c), '{')
issigil(c::Pair{Symbol, Int}) = issigil(c.first)
issigil(c) = false

const opening = issigil | ==(q"(")

Base.:(==)(a::Pair{Symbol, Int}, b::Symbol) = a.first == b

struct Automata
	lexer::Lookahead
	file::String
end

function _error_message(auto::Automata, index, error)
	lastline = something(findprev(==('\n'), auto.lexer.text, index), 0)
	column = index - lastline
	line = 1 + count(==('\n'), view(auto.lexer.text, 1:lastline))
	endline = something(findnext(==('\n'), auto.lexer.text, index), lastindex(auto.lexer.text))
	word = view(auto.lexer.text, (1+lastline):endline)
	"$(auto.file):$line:$column $error\n\t $word"
end

# https://en.wikipedia.org/wiki/Shunting_yard_algorithm#The_algorithm_in_detail
function _expression(auto::Automata, index::Int)
	local out = Any[]
	local stack = Any[]

	intro = nothing
	while (iter = iterate(auto.lexer, index); !isnothing(iter))
		(token, next) = iter
		# @info "postfix" intro token _row(stack) _row(out)
		if !(token isa Symbol)
			push!(out, token)
		elseif token == q"_"
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
			nonvoid = q"(" != intro
			while _ifmove(!=(q"("), stack, out); end
			isempty(stack) && break
			sentinel = pop!(stack)
			if sentinel isa Pair
				push!(out, :CALL => sentinel.second + nonvoid)
			end
		elseif issigil(token)
			push!(stack, token => 0)
		elseif token == q"}"
			nonvoid = !issigil(intro)
			while _ifmove(!issigil, stack, out); end
			isempty(stack) && break
			sentinel = pop!(stack)
			@assert sentinel isa Pair
			push!(out, :RECORD => sentinel.second + nonvoid)
		elseif token == q","
			while _ifmove(!opening, stack, out); end
			isempty(stack) && break
			if stack[end] isa Pair
				n = stack[end].second
				stack[end] = stack[end].first => n + 1
			end
		elseif token in Operator2
			while _ifmove(!opening & _preceeds(token), stack, out); end
			push!(stack, token)
		elseif token in Operator1_Pre
			push!(stack, token)
		elseif token in Operator1_Post
			push!(out, token)
		elseif token == q":"
			break
		elseif token == q"nil"
			push!(out, token)
		end
		intro = token
		index = next
	end
	while _ifmove(!=(q")"), stack, out); end
	@assert isempty(stack) _error_message(auto, index, "malformed expression.")
	return (out, index)
end


function _required(auto::Automata, index)
	state = iterate(auto.lexer, index)
	@assert !isnothing(state) _error_message(auto, index, "required token.")
	state
end

function _expect(auto::Automata, index, T::Type)
	(token, index) = _required(auto, index)
	@assert token isa T _error_message(auto, index, "expected type $T and got $(typeof(token)).")
	(token, index)
end

function _expect(auto::Automata, index, expected::Symbol)
	(token, index) = _required(auto, index)
	@assert token == expected _error_message(auto, index, "expected `$expected` and got `$token`.")
	(token, index)
end

function _function(auto::Automata, index; depth)
	(_, index) = _expect(auto, index, q"(")
	args = Any[]
	ahead = index
	while ((next, ahead) = _required(auto, index); next != q")")
		(var, index) = _declare(auto, index);
		push!(args, var)
	end
	index = ahead

	defn = Pair{Int, Any}[]
	state = (index, depth, true)
	while (iter = iterate(auto, state); !isnothing(iter))
		(link, state) = iter
		# @info "fn" iter defn
		link == (depth => nothing) && break
		!isnothing(link.second) && push!(defn, link)
	end
	(index, _, _) = state
	node = (q"fn", args, defn)
	(node, index)
end

function _declare(auto::Automata, index; depth=0)
	(out, index) = _expression(auto, index)
	(token, index) = _required(auto, index)
	if token == q";"
		node = (q";", out)
	elseif token == q":"
		type = isempty(out) ? nothing : out
		(token, index) = _expect(auto, index, Label)
		(then, index) = _required(auto, index)
		if then == q"="
			(keyword, ahead) = _required(auto, index)
			if keyword == q"fn" # special form
				(out, index) = _function(auto, ahead; depth)
			else
				(out, index) = _expression(auto, index)
			end
			# @info "decl" index _row(out) _row(type)
			(_, index) = _expect(auto, index, q";")
		else
			@assert then == q";" _error_message(auto, index, "expected `;`.")
			out = nothing
		end
		node = (q":", type, token, out)
	else
		@assert false _error_message(auto, index, "expected one of `;:`.")
	end
	(node, index)
end

function _scope(auto::Automata, token, index; depth, intro)
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
	elseif token == q"include"
		(lib, index) = _expect(auto, index, AbstractString)
		(_, index) = _expect(auto, index, q";")
		node = (token, lib)
	elseif token in Labels
		(label, index) = _required(auto, index)
		if label == q";"
			node = (token, :LOOP)
		else
			@assert label isa Label _error_message(auto, index, "expected a name.")
			(_, index) = _expect(auto, index, q";")
			node = (token, label)
		end
	elseif token == q"{"
		depth += 1
	elseif token == q"}"
		@assert depth > 0 _error_message(auto, index, "too many '}'.")
		depth -= 1
	elseif token == q";"
		node = token
	else
		(peek, ahead) = _required(auto, index)
		if peek == q"::"
			node = (q"::", token)
			index = ahead
		else
			(node, index) = _declare(auto, intro; depth)
		end
	end
	(node, index, depth)
end

@inline function _iterate_all(auto, index, depth)
	iter = iterate(auto.lexer, index)
	!isnothing(iter) || return nothing
	((token, index), intro) = iter, index
	_scope(auto, token, index; depth, intro)
end

@inline function _iterate_none(auto, index, depth)
	while (iter = _iterate_all(auto, index, depth); !isnothing(iter))
		(node, index, depth) = iter
		isnothing(node) || return (node, index, depth)
	end
end

function Base.iterate(auto::Automata, state=(1, 0, false))
	(index, depth, all) = state
	iter = if all
		_iterate_all(auto, index, depth)
	else
		_iterate_none(auto, index, depth)
	end
	!isnothing(iter) || return nothing
	(node, index, depth) = iter
	(depth => node, (index, depth, all))
end

Base.eltype(::Type{Automata}) = Pair{Int, Any}
Base.IteratorSize(::Type{Automata}) = Base.SizeUnknown()

"""
	ast(text; file)

Reads a text into a datastructure.

# Examples

```jldoctest
julia> using Caper

julia> Caper.ast("x |= h'1f';")
1-element Vector{Pair{Int64, Any}}:
 0 => (Symbol(";"), Any[!"x", 0x1f, :|=])

julia> Caper.ast("return 1 + h'1f';")
1-element Vector{Pair{Int64, Any}}:
 0 => (:return, Any[1, 0x1f, :+])
```
"""
function ast(text::AbstractString; file::String="_.ca")
	return collect(Automata(Lookahead(text), file))
end

