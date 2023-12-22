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
const Conditionals = [q"if", q"while", q"for"]
const Statements = [q"else", q"defer"]
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
	span = (1+lastline):endline
	word = view(auto.lexer.text, span)
	remain = index:endline
	underline = string(' '^(length(span) - length(remain) - 1), '^', ' '^length(remain))
	"$(auto.file):$line:$column $error\n\t$word\t$underline"
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
			type && break
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

function _expect(auto::Automata, index, expected::Vector{Symbol})
	(token, index) = _required(auto, index)
	@assert token in expected _error_message(auto, index,
		"expected one of `$(join(string.(expected)))` and got `$token`.")
	(token, index)
end

function _function(auto::Automata, index; depth)
	(_, index) = _expect(auto, index, q"(")
	args = Any[]
	(next, ahead) = _required(auto, index)
	next == q")" && (index = ahead) # void function
	while next != q")"
		(var, index) = _declare(auto, index)
		push!(args, var)
		# @info "var" index var
		(next, index) = _expect(auto, index, [q",", q")"])
	end
	(_, index) = _expect(auto, index, q":")
	(type, index) = _expression(auto, index; type=true)
	(_, ahead) = _expect(auto, index, q"{")

	defn = Pair{Int, Any}[]
	state = (index, depth, 0)
	while (iter = _iterate(auto, state); !isnothing(iter))
		(link, state) = iter
		# @info "fn" iter defn
		link == (depth => nothing) && break
		!isnothing(link.second) && push!(defn, link)
	end
	node = (q"fn", args, type, defn)
	(node, state[1])
end

function _declare(auto::Automata, index; depth=0)
	(name, index) = _expect(auto, index, Label)
	(_, index) = _expect(auto, index, q":")
	(keyword, ahead) = _required(auto, index)
	if keyword == q"fn" # special form
		(out, index) = _function(auto, ahead; depth)
		type = nothing
	else
		(type, index) = _expression(auto, index; type=true)
		(out, index) = _expression(auto, index)
		if isempty(out)
			out = nothing
		else
			init = last(out)
			@assert init isa Pair && init.first == :RECORD _error_message(auto, index, "expected a record, got: $init.")
		end
	end
	node = (q":", name, type, out)
	(node, index)
end

function _statement(auto, index; depth)
	intro = index
	(name, index) = _required(auto, index)
	(peek, _) = _required(auto, index)
	# @info "statement" name peek index
	if peek == q":"
		@assert name isa Label _error_message(auto, index, "expected a name, got: $name.")
		(node, index) = _declare(auto, intro; depth)
		(_, index) = _expect(auto, index, q";")
	else
		(out, index) = _expression(auto, intro)
		(token, index) = _expect(auto, index, q";")
		node = (token, out)
	end
	(node, index)
end

function _indent(auto::Automata, index)
	(token, _) = _required(auto, index)
	token != q"{"
end

function _scope(auto::Automata, token, state; intro)
	(index, depth, indent) = state
	# @info "scope" token depth index indent intro
	node = nothing
	nest = depth
	nest += indent
	level = indent - (indent > 0)
	if token == q"for" # special form
		(_, index) = _expect(auto, index, q"(")
		(init, index) = _statement(auto, index; depth)
		(cond, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q";")
		(post, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q")")
		node = (token, init, cond, post)
		level = indent + _indent(auto, index)
	elseif token in Conditionals
		(_, index) = _expect(auto, index, q"(")
		(out, index) = _expression(auto, index)
		(_, index) = _expect(auto, index, q")")
		node = (token, out)

		level = indent + _indent(auto, index)
	elseif token in Statements
		node = (token,)
		level = indent + _indent(auto, index)
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
			@assert label isa Label _error_message(auto, index, "expected a name, got: $token.")
			(_, index) = _expect(auto, index, q";")
			node = (token, label)
		end
	elseif token == q"{"
		depth += 1
		nest = depth
	elseif token == q"}"
		@assert depth > 0 _error_message(auto, index, "too many `}`.")
		depth -= 1
		indent -= (indent > 0)
		nest = depth
	elseif token == q";"
		node = token
	elseif token == q"#"
		(name, index) = _required(auto, index)
		@assert name isa Label _error_message(auto, index, "expected a name, got: $name.")
		node = (q"#", name)
	else
		(node, index) = _statement(auto, intro; depth)
	end
	indent = level
	state = (index, depth, indent)
	(nest => node, state)
end

@inline function _iterate(auto, state)
	iter = iterate(auto.lexer, state[1])
	!isnothing(iter) || return nothing
	((token, index), intro) = iter, state[1]
	state = (index, state[2:end]...)
	_scope(auto, token, state; intro)
end

# state = (index, depth, indent)
function Base.iterate(auto::Automata, state=(1, 0, 0))
	while (iter = _iterate(auto, state); !isnothing(iter))
		(arrow, state) = iter
		isnothing(arrow.second) || return iter
	end
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

