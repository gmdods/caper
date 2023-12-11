## module Caper, parsing functions

"""
Methods for parsing files
"""

const Binary = Symbol.([collect(MathChar); collect(CmpChar) .* '='])
const Assign = Symbol.(['='; collect(MathChar) .* '='])
const OpenBraces = Symbol.(collect("([{"))
const CloseBraces = Symbol.(collect(")]}"))
const Keywords = Symbol.(KeywordString)
const Statements = Symbol.(["if", "while", "for"])

_top(stack) = isempty(stack) ? nothing : stack[end]

const Semicolon = Symbol(";")
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

function _unbrace(brace::Symbol, stack)
	sentinel = OpenBraces[findfirst(==(brace), CloseBraces)]
	opening = findlast(==(sentinel), stack)
	@assert !isnothing(opening)
	if brace == Symbol("]")
		index = pop!(stack)
		_ = pop!(stack) # sentinel
		array = pop!(stack)
		return (:index, array, index)
	end

	pops = reverse!(Any[pop!(stack) for _ = 1:(length(stack)-opening)])
	_ = pop!(stack) # sentinel

	if _top(stack) in Statements
		keyword = pop!(stack)
		(keyword, pops)
	elseif _top(stack) isa AbstractString && brace == Symbol(")")
		fn = pop!(stack)
		@assert all(==(Symbol(",")), pops[2:2:end])
		(:call, fn, pops[1:2:end])
	else
		(sentinel, pops)
	end
end

_ingest(next::AbstractString, stack) = push!(stack, next)

function _ingest(next::T, stack) where {T<:Number}
        if length(stack) >= 2 && stack[end] in Binary
                op = pop!(stack)
                prev = pop!(stack)
                node = (op, prev, next)
        else
                node = next
        end
        push!(stack, node)
end

function _ingest(next::Symbol, stack)
        if next == Semicolon
		node = _semicolon(stack)
		push!(stack, node)
        elseif next in OpenBraces
                push!(stack, next)
        elseif next in CloseBraces
		node = _unbrace(next, stack)
		push!(stack, node)
        elseif next in Binary || next in Assign
                push!(stack, next)
        else
                push!(stack, next)
        end
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
        stack = Any[]
        for next = lex(text)
                _ingest(next, stack)
        end
        return stack
end

