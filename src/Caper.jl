## module Caper

"""
An attempt at a compile-time C.
"""
module Caper

export @q_str

include("./tools.jl")
include("./Reader.jl")
include("./Lexer.jl")
include("./Parser.jl")
include("./Codegen.jl")

end # module Caper
