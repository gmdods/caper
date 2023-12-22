## module Caper, codegen functions

_tab(io, n) = for _ = 1:n; write(io, '\t') end

_translate_type(io::IO, name::Label, ty::Label) =
	write(io, string(ty), ' ', string(name))

function _translate_type(io::IO, name::Label, types::Vector{Any})
	size = nothing
	named = false
	for ty = types
		if ty isa Label
			write(io, string(ty))
		elseif ty == q"^"
			write(io, " *")
		elseif ty == q"_"
			size = nothing
		elseif ty == :INDEX
			write(io, ' ', string(name), '[')
			named = true
			isnothing(size) || write(io, string(size))
			write(io, ']')
		elseif ty isa Number
			size = ty
		else
			@assert false "Not implemented"
		end
	end
	if !named
		write(io, ' ', string(name))
	end
end

function _translate_expression(io::IO, expression::Vector{Any})
	isempty(expression) && return
	stack = String[]
	for e = expression
		if e isa Symbol
			if e in Operator2
				rhs = pop!(stack)
				lhs = pop!(stack)
				bin = (e == q"~") ? q"^" : e
				push!(stack, string('(', lhs, ' ', bin, ' ', rhs, ')'))
			elseif e in Operator1_Pre
				arg = pop!(stack)
				push!(stack, string("(!", arg, ')'))
			elseif e == q"^"
				arg = pop!(stack)
				push!(stack, string("(*", arg, ')'))
			elseif e == :INDEX
				arg = pop!(stack)
				name = pop!(stack)
				push!(stack, string(name, '[', arg, ']'))
			else
				@assert false "Not implemented $e"
			end
		elseif e isa Pair
			argnum = e[2]
			arglist = reverse!([pop!(stack) for _ = 1:argnum])
			args = join(arglist, ", ")
			if e[1] == :CALL
				name = pop!(stack)
				push!(stack, string(name, '(', args, ')'))
			elseif e[1] == :RECORD
				args = isempty(args) ? "0" : args
				push!(stack, string('{', args, '}'))

			else
				@assert false "Expected CALL or RECORD, got $(e[1])"
			end
		elseif e isa AbstractString
			push!(stack, string('"', escape_string(e), '"'))
		else
			push!(stack, string(e))
		end
		# @info "translate" _row(stack)
	end
	@assert length(stack) == 1 "Constructed $stack"
	write(io, pop!(stack))
end

function _translate_scope(io::IO, scope::Vector{Pair{Int, Any}})
	local level = 0
	for item = scope
		(depth, node) = item
		# @info "scope" node depth level
		if level > depth
			_tab(io, depth)
			write(io, "}\n")
		end
		_tab(io, depth)
		if node[1] in Conditionals
			write(io, string(node[1]), " (")
			_translate_expression(io, node[2])
			if node[1] == q"for" # special form
				write(io, ";")
				_translate_expression(io, node[3])
				write(io, ";")
				_translate_expression(io, node[4])
			end
			write(io, ") {\n")
			indent = true
		elseif node[1] == q"defer" # special form
			@assert false "Not implemented $node"
		elseif node[1] in Statements
			write(io, string(node[1]), " {\n")
			indent = true
		elseif node[1] == q"return"
			write(io, "return ")
			_translate_expression(io, node[2])
			write(io, ";\n")
		elseif node[1] == q";"
			_translate_expression(io, node[2])
			write(io, ";\n")
		elseif node[1] == q":"
			_translate_declaration(io, node)
		else
			@assert false "Not implemented $node"
		end
		level = depth
	end
end

function _translate_function(io::IO, func_node)
	@assert func_node[1] == q"fn"
	write(io, '(')
	for (i, arg) = enumerate(func_node[2])
		@assert arg[1] == q":"
		i > 1 && write(io, ", ")
		_translate_type(io, arg[2], arg[3])
	end
	write(io, ')')
end

function _translate_declaration(io::IO, node)
	func_node = node[4]
	func_node isa Tuple && return
	@assert func_node isa AbstractVector
	_translate_type(io, node[2], node[3])
	if !isnothing(node[4])
		write(io, " = ")
		_translate_expression(io, node[4])
	end
	write(io, ";\n")
end

function _forward(io::IO, node)
	node[1] == q":" || return
	func_node = node[4]
	func_node isa Tuple || return
	@assert func_node[1] == q"fn"
	_translate_type(io, node[2], func_node[3])
	_translate_function(io, func_node)
	write(io, ";\n")
	for (_, node) = func_node[4]
		_forward(io, node)
	end
	_translate_type(io, node[2], func_node[3])
	_translate_function(io, func_node)
	write(io, " {\n")
	_translate_scope(io, func_node[4])
	write(io, "}\n")
end

"""
Methods for generating C code
"""

"""
	gen(text)

Translates Caper into C.

# Examples

```jldoctest
using Caper

Caper.gen(\"""
include C_lib"stdio.h";

main: fn (): int {
\tputs("Hello, world!");
\treturn 0;
};
\""") |> print
# output
#include <stdio.h>
int main() {
\tputs("Hello, world!");
\treturn 0;
}
```
"""
function gen(text::AbstractString)
	local astree = ast(text)
	local io = IOBuffer(read=false)
	for (depth, node) = astree
		@assert depth == 0
		if node[1] == q"include"
			write(io, "#include ", node[2], '\n')
		elseif node[1] == q":"
			_forward(io, node)
			_translate_declaration(io, node)
		end
	end
	String(take!(io))
end


