## module Caper, codegen functions

_tab(io, n) = for _ = 1:n; write(io, '\t') end

function _translate_type(io::IO, name::Label, types::Vector{Any})
	isempty(types) && return
	@assert types[1] isa Label
	ind = lastindex(types)

	retptr = something(findnext(!=(q"^"), types, 2), ind+1)
	write(io, string(types[1]), ' ', '*'^(retptr-2), ' '^min(retptr-2, 1))
	if retptr == ind + 1
		write(io, string(name))
		return
	end

	varptr = ind - something(findprev(!=(q"^"), types, ind), 0)

	name_ptr = (varptr == 0) ? name : Label(string('(', '*'^(varptr), string(name), ')'))
	_translate_expression(io, [name_ptr; view(types, retptr:ind-varptr)])
end

function _translate_expression(io::IO, expression::Vector{Any})
	isempty(expression) && return
	local stack = String[]
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
			elseif e == q"_"
				push!(stack, "")
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

function _translate_scope(io::IO, scope::Vector{Pair{Int, Any}}; depth=0)
	local indent = depth
	local level = 0
	for item = scope
		(depth, node) = item
		# @info "scope" node depth level
		if level > depth
			_tab(io, depth - indent)
			write(io, "}\n")
		end
		_tab(io, depth - indent)
		if node[1] in Conditionals
			write(io, string(node[1]), " (")
			if node[1] == q"for" # special form
				if node[2] isa Tuple
					_translate_declaration(io, node[2])
				else
					_translate_expression(io, node[2])
					write(io, ";")
				end
				_translate_expression(io, node[3])
				write(io, ";")
				_translate_expression(io, node[4])
			else
				_translate_expression(io, node[2])
			end
			write(io, ") {\n")
		elseif node[1] == q"defer" # special form
			@assert false "Not implemented $node"
		elseif node[1] in Statements
			write(io, string(node[1]), " {\n")
		elseif node[1] == q"return"
			write(io, "return ")
			_translate_expression(io, node[2])
			write(io, ";\n")
		elseif node[1] == q";"
			_translate_expression(io, node[2])
			write(io, ";\n")
		elseif node[1] == q":"
			if _translate_declaration(io, node)
				write(io, '\n')
			else
				write(io, "extern ")
				_forward(io, node; forward=false)
			end
		else
			@assert false "Not implemented $node"
		end
		level = depth
	end
	if level > indent + 1
		_tab(io, indent + 1)
		write(io, "}\n")
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
	func_node isa Tuple && return false
	@assert func_node isa Union{AbstractVector, Nothing} "Expected declaration, got $func_node."
	_translate_type(io, node[2], node[3])
	if !isnothing(node[4])
		write(io, " = ")
		_translate_expression(io, func_node)
	end
	write(io, ';')
	return true
end

function _forward(io::IO, node; forward=true, depth=0)
	node[1] == q":" || return false
	func_node = node[4]
	func_node isa Tuple || return false
	@assert func_node[1] == q"fn"
	_translate_type(io, node[2], func_node[3])
	_translate_function(io, func_node)
	write(io, ";\n")
	forward || return true
	for (nest, node) = func_node[4]
		_forward(io, node; depth=nest)
	end
	write(io, '\n')
	_translate_type(io, node[2], func_node[3])
	_translate_function(io, func_node)
	write(io, " {\n")
	_translate_scope(io, func_node[4]; depth)
	write(io, "}\n")
	return true
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
int main();

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
			if _translate_declaration(io, node)
				write(io, '\n')
			end
		end
	end
	String(take!(io))
end


