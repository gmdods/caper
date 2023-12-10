## module Caper, parsing functions

const Binary = Symbol.([collect(MathChar); collect(CmpChar) .* '='])
const Assign = Symbol.(['='; collect(MathChar) .* '='])

"""
Methods for parsing files
"""


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
		if next isa AbstractString
			push!(stack, next)
		elseif next isa Number
			if length(stack) >= 2 && stack[end] in Binary
				op = pop!(stack)
				prev = pop!(stack)
				node = (op, prev, next)
			else
				node = next
			end
			push!(stack, node)
		elseif next == Symbol(";")
			@assert length(stack) > 0
			stmt = pop!(stack)
			if stack[end] in Assign
				equal = pop!(stack)
				name = pop!(stack)
				@assert name isa AbstractString
				node = (next, name, equal, stmt)
			elseif stack[end] in Keywords
				keyword = pop!(stack)
				node = (next, Symbol(keyword), stmt)
			else
				node = (next, stmt)
			end
			push!(stack, node)
		elseif next isa Symbol
			if next in Binary || next in Assign
				push!(stack, next)
			else
				arg = pop!(stack)
				push!(stack, (next, arg))
			end
		end
	end
	return stack
end

