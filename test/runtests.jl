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
        @test Caper.lex("2 + 4") == [2, q"+", 4]
        @test Caper.lex("h'ff' & b'10' | b'1100' ") == [0xff, q"&", 0b10, q"|", 0b1100]
        @test Caper.lex("z += (x > y) ? x : y") ==
              ["z", q"+=", q"(", "x", q">", "y", q")", q"?", "x", q":", "y"]
end


@testset "Parser" begin
        @test Caper.ast("x = 4; ") ==
		Pair{Int, Any}[0 => (q";", ["x", 4, q"="])]
        @test Caper.ast("return x % b'1';") ==
		Pair{Int, Any}[0 => (:return, ["x", 0b01, q"%"])]
        @test Caper.ast("return (x % b'1') + 1;") ==
		Pair{Int, Any}[0 => (:return, ["x", 0b01, q"%", 1, q"+"])]
	@test Caper.ast("return 0 + (1 + 2) * 3;") ==
		Pair{Int, Any}[0 => (:return, [0, 1, 2, q"+", 3, q"*", q"+"])]
        @test Caper.ast("if (x % b'1') { sum += 1; }") ==
		Pair{Int, Any}[0 => (:if, ["x", 0b01, q"%"]),
				1 => (q";", ["sum", 1, q"+="])]
        @test Caper.ast("x = add(times(3, 2), 1 + 2);") ==
		Pair{Int, Any}[0 => (q";",
			Any["x", "add", "times", 3, 2, :CALL => 2, 1, 2, q"+",
				:CALL => 2, q"="])]
	@test Caper.ast("x = fn[3](y) + (fn[1])(x, y);") ==
		Pair{Int, Any}[0 => (q";",
			Any["x", "fn", 3, :INDEX, "y", :CALL => 1,
				 "fn", 1, :INDEX, "x", "y", :CALL => 2, q"+", q"="])]
        @test Caper.ast(""" {
        	if (argc < 2) {
        		return 1;
        	}
        	printf(argv[1]);
        }
        """) == Pair{Int, Any}[
	 1 => (:if, Any["argc", 2, q"<"]),
	 2 => (:return, Any[1]),
	 1 => (q";", Any["printf", "argv", 1, :INDEX, :CALL => 1]),
	]


end


