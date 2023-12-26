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

# https://en.wikipedia.org/wiki/Shunting_yard_algorithm#The_algorithm_in_detail
@inline function _postfix(token, previous, out, stack; type=false)
	# @info "postfix" token _row(stack) _row(out)
	if !(token isa Symbol)
		push!(out, token)
	elseif token == q"_"
		push!(out, token)
	elseif token == q";"
		return false
	elseif token == q"["
		push!(stack, token)
	elseif token == q"]"
		while _ifmove(!=(q"["), stack, out); end
		isempty(stack) && return false
		_ = pop!(stack) # sentinel
		push!(out, :INDEX)
	elseif token == q"("
		if previous in Operator2 || isnothing(previous)
			push!(stack, token)
		else
			push!(stack, token => 0)
		end
	elseif token == q")"
		nonvoid = q"(" != previous
		while _ifmove(!=(q"("), stack, out); end
		isempty(stack) && return false
		sentinel = pop!(stack)
		if sentinel isa Pair
			push!(out, :CALL => sentinel.second + nonvoid)
		end
	elseif issigil(token)
		type && return false
		push!(stack, token => 0)
	elseif token == q"}"
		nonvoid = !issigil(previous)
		while _ifmove(!issigil, stack, out); end
		isempty(stack) && return false
		sentinel = pop!(stack)
		@assert sentinel isa Pair
		push!(out, :RECORD => sentinel.second + nonvoid)
	elseif token == q","
		while _ifmove(!opening, stack, out); end
		isempty(stack) && return false
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
		return false
	elseif token == q"nil"
		push!(out, token)
	end
	return true
end

struct _Parser
	lexer::_Lexer
	file::String
end

function _error_message(parser::_Parser, index, error)
	local column = 0
	local lastline = index + 1
	while column == 0
		lastline = something(findprev(==('\n'), parser.lexer.text, lastline - 1), 0)
		column = index - lastline
	end
	line = 1 + count(==('\n'), view(parser.lexer.text, 1:lastline))
	endline = something(findnext(==('\n'), parser.lexer.text, index), lastindex(parser.lexer.text))
	span = (1+lastline):endline
	word = view(parser.lexer.text, span)
	remain = index:endline
	underline = string(' '^max(length(span) - length(remain) - 1, 0), '^', ' '^length(remain))
	"$(parser.file):$line:$column $error\n\t$word\t$underline"
end

function _expression(parser::_Parser, index::Int; type=false, init=nothing)
	local out = Any[]
	local stack = Any[]
	local previous = nothing

	if !isnothing(init)
		for token = init
			_postfix(token, previous, out, stack; type) || @goto unstack
			previous = token
		end
	end

	while (iter = iterate(parser.lexer, index); !isnothing(iter))
		(token, next) = iter
		_postfix(token, previous, out, stack; type) || @goto unstack
		previous = token
		index = next
	end

	@label unstack
	while _ifmove(!=(q")"), stack, out); end
	@assert isempty(stack) _error_message(parser, index, "malformed expression.")
	return (out, index)
end

function _required(parser::_Parser, index)
	state = iterate(parser.lexer, index)
	@assert !isnothing(state) _error_message(parser, index, "required token.")
	state
end

function _expected(parser::_Parser, index, T::Type)
	(token, index) = _required(parser, index)
	@assert token isa T _error_message(parser, index, "expected type $T and got $(typeof(token)).")
	(token, index)
end

function _expected(parser::_Parser, index, expected::Symbol)
	(token, index) = _required(parser, index)
	@assert token == expected _error_message(parser, index, "expected `$expected` and got `$token`.")
	(token, index)
end

function _expected(parser::_Parser, index, expected::Vector{Symbol})
	(token, index) = _required(parser, index)
	@assert token in expected _error_message(parser, index,
		"expected one of `$(join(string.(expected)))` and got `$token`.")
	(token, index)
end

function _function(parser::_Parser, index; depth)
	(_, index) = _expected(parser, index, q"(")
	args = Any[]
	(name, index) = _required(parser, index)
	next = name
	if next != q")" # non-void function
		(_, index) = _expected(parser, index, q":")
	end
	while next != q")"
		(var, index) = _declare(parser, index; name)
		push!(args, var)
		# @info "var" index var
		(next, index) = _expected(parser, index, [q",", q")"])
		name = nothing
	end
	(_, index) = _expected(parser, index, q":")
	(type, index) = _expression(parser, index; type=true)
	(state, defn) = _collect(parser, (index, depth, 0))
	node = (q"fn", args, type, defn)
	(node, state[1])
end

function _declare(parser::_Parser, index; depth=0, name=nothing)
	if isnothing(name)
		(name, index) = _expected(parser, index, Label)
		(_, index) = _expected(parser, index, q":")
	end
	(token, index) = _required(parser, index)
	if token == q"fn" # special form
		(out, index) = _function(parser, index; depth)
		type = nothing
	else
		(type, index) = _expression(parser, index; type=true, init=Any[token])
		(out, index) = _expression(parser, index)
		if isempty(out)
			out = nothing
		else
			init = last(out)
			@assert init isa Pair && init.first == :RECORD _error_message(parser, index, "expected a record, got: $init.")
		end
	end
	node = (q":", name, type, out)
	(node, index)
end

function _statement(parser::_Parser, index; depth, init=nothing)
	if isnothing(init)
		(name, index) = _required(parser, index)
	else
		name = init
	end
	name == q";" && return ((name, Any[]), index)
	(peek, index) = _required(parser, index)
	# @info "statement" name peek index
	if peek == q":"
		@assert name isa Label _error_message(parser, index, "expected a name, got: $name.")
		(node, index) = _declare(parser, index; depth, name)
		(_, index) = _expected(parser, index, q";")
	else
		(out, index) = _expression(parser, index; init=Any[name, peek])
		(token, index) = _expected(parser, index, q";")
		node = (token, out)
	end
	(node, index)
end

function _indent(parser::_Parser, index)
	(token, _) = _required(parser, index)
	token != q"{"
end

function _scope(parser::_Parser, token, state)
	(index, depth, indent) = state
	# @info "scope" token depth index indent
	node = nothing
	nest = depth
	nest += indent
	level = indent - (indent > 0)
	if token == q"for" # special form
		(_, index) = _expected(parser, index, q"(")
		(init, index) = _statement(parser, index; depth)
		(cond, index) = _expression(parser, index)
		(_, index) = _expected(parser, index, q";")
		(post, index) = _expression(parser, index)
		(_, index) = _expected(parser, index, q")")
		node = (token, init, cond, post)
		level = indent + _indent(parser, index)
	elseif token in Conditionals
		(_, index) = _expected(parser, index, q"(")
		(out, index) = _expression(parser, index)
		(_, index) = _expected(parser, index, q")")
		node = (token, out)

		level = indent + _indent(parser, index)
	elseif token == q"defer" #special form
		(state, defn) = _collect(parser, (index, depth, indent))
		(index, depth, indent) = state
		node = (token, defn)
	elseif token in Statements
		node = (token,)
		level = indent + _indent(parser, index)
	elseif token == q"return"
		(out, index) = _expression(parser, index)
		(_, index) = _expected(parser, index, q";")
		node = (token, out)
	elseif token == q"include"
		(lib, index) = _expected(parser, index, AbstractString)
		(_, index) = _expected(parser, index, q";")
		node = (token, lib)
	elseif token in Labels
		(label, index) = _required(parser, index)
		if label == q";"
			node = (token, :LOOP)
		else
			@assert label isa Label _error_message(parser, index, "expected a name, got: $token.")
			(_, index) = _expected(parser, index, q";")
			node = (token, label)
		end
	elseif token == q"{"
		depth += 1
		nest = depth
	elseif token == q"}"
		@assert depth > 0 _error_message(parser, index, "too many `}`.")
		depth -= 1
		indent -= (indent > 0)
		nest = depth
	elseif token == q";"
		node = token
	elseif token == q"#"
		(name, index) = _required(parser, index)
		@assert name isa Label _error_message(parser, index, "expected a name, got: $name.")
		node = (q"#", name)
	else
		(node, index) = _statement(parser, index; depth, init=token)
	end
	indent = level
	state = (index, depth, indent)
	(nest => node, state)
end

@inline function _iterate(parser, state)
	iter = iterate(parser.lexer, state[1])
	!isnothing(iter) || return nothing
	(token, index) = iter
	state = (index, state[2:end]...)
	_scope(parser, token, state)
end

const Node = Pair{Int, Any}

function _collect(parser, state)
	defn = Node[]
	depth = state[2]
	while (iter = _iterate(parser, state); !isnothing(iter))
		(link, state) = iter
		link == (depth => nothing) && break
		!isnothing(link.second) && push!(defn, link)
	end
	return state, defn
end

# state = (index, depth, indent)
function Base.iterate(parser::_Parser, state=(1, 0, 0))
	while (iter = _iterate(parser, state); !isnothing(iter))
		(arrow, state) = iter
		isnothing(arrow.second) || return iter
	end
end

Base.eltype(::Type{_Parser}) = Node
Base.IteratorSize(::Type{_Parser}) = Base.SizeUnknown()

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
	return collect(_Parser(_Lexer(text), file))
end

