using Test, Documenter, Caper

@testset "Reader" begin
        @test Caper.literal("1234") == 1234
        @test Caper.literal("012") == 12
        @test Caper.literal("-1") == -1

        @test Caper.literal("42", :u) == UInt(42)
        @test Caper.literal("11101", :b) == 0b11101
        @test Caper.literal("3ff", :h) == 0x03ff

        @test Caper.literal("1.0", :f) == 1.0
        @test Caper.literal("1e3", :f) == 1e3

        @test Caper.literal("a", :char) == 0x61
        @test Caper.literal("é", :utf) == 0x0000_00_e9

        @test Caper.literal("[0-9]+", :re) == r"[0-9]+"
        @test Caper.literal(raw"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+", :re) ==
              r"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+"
end

@testset "Lexer" begin
        @test Caper.lex("2 + 4") == [2, :+, 4]
        @test Caper.lex("h'ff' & b'10' | b'1100' ") == [0xff, :&, 0b10, :|, 0b1100]
        @test Caper.lex("z += (x > y) ? x : y") ==
              ["z", :+=, Symbol('('), "x", :>, "y", Symbol(')'), :?, "x", :(:), "y"]
end


@testset "Parser" begin
        @test Caper.ast("x = 4; ") ==
              Any[(Symbol(";"), "x", :(=), 4)]
        @test Caper.ast("return x % b'1';") ==
              Any[(Symbol(";"), :return, (:%, "x", 0b01))]
        @test Caper.ast("return (x % b'1') + 1;") ==
              Any[(Symbol(";"), :return, (:+, (Symbol("("), [(:%, "x", 0b01)]), 1))]
        @test Caper.ast("if (x % b'1') { sum += 1; }") ==
              Any[(:if, Any[(:%, "x", 0x01)]),
                (Symbol("{"), Any[(Symbol(";"), "sum", :+=, 1)])]
        @test Caper.ast("x = add(times(3, 2), 1 + 2);") ==
              Any[(Symbol(";"), "x", :(=),
                (:call, "add",
                        Any[(:call, "times", Any[3, 2]), (:+, 1, 2)]))]
        @test Caper.ast(""" {
        	if (argc < 2) {
        		return 1;
        	}
        	printf(argv[1]);
        }
        """) == Any[(Symbol("{"), Any[
		(:if, Any["argc", :<, 2]), (Symbol("{"), Any[
			(Symbol(";"), :return, 1)]),
		(Symbol(";"), (:call, "printf", Any[(:index, "argv", 1)]))])]
end


