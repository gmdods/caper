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
        if next == Symbol(";")
                @assert length(stack) > 0
                stmt = pop!(stack)
                if isempty(stack)
                        node = (next, stmt)
                elseif stack[end] in Assign
                        equal = pop!(stack)
                        name = pop!(stack)
                        @assert name isa AbstractString
                        node = (next, name, equal, stmt)
                elseif stack[end] in Keywords
                        keyword = pop!(stack)
                        node = (next, keyword, stmt)
                else
                        node = (next, stmt)
                end
                push!(stack, node)
        elseif next in OpenBraces
                push!(stack, next)
        elseif next in CloseBraces
                sentinel = OpenBraces[findfirst(==(next), CloseBraces)]
                opening = findlast(==(sentinel), stack)
                @assert !isnothing(opening)
                pops = Any[pop!(stack) for _ = 1:(length(stack)-opening)]
                _ = pop!(stack) # sentinel

                if stack[end] in Statements
                        keyword = pop!(stack)
                        node = (keyword, pops)
                elseif stack[end] isa AbstractString
                        fn = pop!(stack)
                        node = (:call, fn, pops)
                else
                        node = (sentinel, pops)
                end
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

