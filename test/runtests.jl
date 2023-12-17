using Test, Documenter, Caper

using Dates

@testset "Reader" begin
        @test Caper.literal("1234") == 1234
        @test Caper.literal("012") == 12
        @test Caper.literal("-1") == -1

        @test Caper.literal("42", q"U") == UInt(42)
        @test Caper.literal("11101", q"B") == 0b11101
        @test Caper.literal("3ff", q"H") == 0x03ff

        @test Caper.literal("1.0", q"F") == 1.0
        @test Caper.literal("1e3", q"F") == 1e3

        @test Caper.literal("a", q"Char") == 0x61
        @test Caper.literal("é", q"Utf") == 0x0000_00_e9

        @test Caper.literal("[0-9]+", q"Re") == r"[0-9]+"
        @test Caper.literal(raw"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+", q"Re") ==
              r"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+"

	@test Caper.literal("2000-01-01", q"D") == Date(2000, 01, 01)
	@test Caper.literal("12:00:01", q"T") == Time(12, 00, 01)
end

@testset "Lexer" begin
        @test Caper.lex("2 + 4") == [2, q"+", 4]
        @test Caper.lex("h'ff' & b'10' | b'1100'") == [0xff, q"&", 0b10, q"|", 0b1100]
        @test Caper.lex("z += (x > y) ? x : y") ==
              ["z", q"+=", q"(", "x", q">", "y", q")", q"?", "x", q":", "y"]
end


@testset "Parser" begin
        @test Caper.ast("x = 4; ") ==
		Pair{Int, Any}[0 => (q";", ["x", 4, q"="])]
        @test Caper.ast("x = 4 + !y + 1; ") ==
		Pair{Int, Any}[0 => (q";", ["x", 4, "y", q"!", q"+", 1, q"+", q"="])]
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
        	print(argv[1]);
        }
        """) == Pair{Int, Any}[
	 1 => (q"if", Any["argc", 2, q"<"]),
	 2 => (q"return", Any[1]),
	 1 => (q";", Any["print", "argv", 1, :INDEX, :CALL => 1]),
	]
        @test Caper.ast("""
		for (i = 0; i != 10; i += 1) {
			print(Fmt"%d", i);
		}
        """) == Pair{Int, Any}[
	 0 => (q"for", Any["i", 0, q"="], Any["i", 10, q"!="], Any["i", 1, q"+="])
	 1 => (q";", Any["print", "%d", "i", :CALL => 2])
	]
        @test Caper.ast("""
		outer: for (i = 0; i != 10; i += 1) {
			if (i == 1) continue;
			for (j = 0; j != 10; j += 1) {
				print(Fmt"%d", i);
				if (i >= 5) break outer;
			}
		}
        """) == Pair{Int, Any}[
	 0 => (q":", "outer")
	 0 => (q"for", Any["i", 0, q"="], Any["i", 10, q"!="], Any["i", 1, q"+="])
	 1 => (q"if", Any["i", 1, q"=="])
	 1 => (q"continue", :LOOP)
	 1 => (q"for", Any["j", 0, q"="], Any["j", 10, q"!="], Any["j", 1, q"+="])
	 2 => (q";", Any["print", "%d", "i", :CALL => 2])
	 2 => (q"if", Any["i", 5, q">="])
	 2 => (q"break", "outer")
	]

	@test Caper.ast("""
	int :: delta = 0;
	int^ :: ptr = nil;
	:: mask = h"ff";
        """) == Pair{Int, Any}[
	 0 => (q"::", Any["int"], "delta", Any[0])
	 0 => (q"::", Any["int", q"^"], "ptr", Any[q"nil"])
	 0 => (q"::", nothing, "mask", Any[0xff])
	]


end


