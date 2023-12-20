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
              [!"z", q"+=", q"(", !"x", q">", !"y", q")", q"?", !"x", q":", !"y"]
end


@testset "Parser" begin
        @test Caper.ast("x = 4; ") ==
		Pair{Int, Any}[0 => (q";", [!"x", 4, q"="])]
        @test Caper.ast("x = 4 + !y + 1; ") ==
		Pair{Int, Any}[0 => (q";", [!"x", 4, !"y", q"!", q"+", 1, q"+", q"="])]
        @test Caper.ast("return x % b'1';") ==
		Pair{Int, Any}[0 => (:return, [!"x", 0b01, q"%"])]
        @test Caper.ast("return (x % b'1') + 1;") ==
		Pair{Int, Any}[0 => (:return, [!"x", 0b01, q"%", 1, q"+"])]
	@test Caper.ast("return 0 + (1 + 2) * 3;") ==
		Pair{Int, Any}[0 => (:return, [0, 1, 2, q"+", 3, q"*", q"+"])]
        @test Caper.ast("if (x % b'1') { sum += 1; }") ==
		Pair{Int, Any}[0 => (:if, [!"x", 0b01, q"%"]),
				1 => (q";", [!"sum", 1, q"+="])]
        @test Caper.ast("x = add(times(3, 2), 1 + 2);") ==
		Pair{Int, Any}[0 => (q";",
			Any[!"x", !"add", !"times", 3, 2, :CALL => 2, 1, 2, q"+",
				:CALL => 2, q"="])]
	@test Caper.ast("x = func[3](y) + (func[1])(x, y);") ==
		Pair{Int, Any}[0 => (q";",
			Any[!"x", !"func", 3, :INDEX, !"y", :CALL => 1,
				 !"func", 1, :INDEX, !"x", !"y", :CALL => 2, q"+", q"="])]
        @test Caper.ast(""" {
        	if (argc < 2) {
        		return 1;
        	}
        	puts(argv[1]);
        }
        """) == Pair{Int, Any}[
	 1 => (q"if", Any[!"argc", 2, q"<"]),
	 2 => (q"return", Any[1]),
	 1 => (q";", Any[!"puts", !"argv", 1, :INDEX, :CALL => 1]),
	]
        @test Caper.ast("""
		for (i = 0; i != 10; i += 1) {
			printf(Fmt"%d", i);
		}
        """) == Pair{Int, Any}[
	 0 => (q"for", Any[!"i", 0, q"="], Any[!"i", 10, q"!="], Any[!"i", 1, q"+="])
	 1 => (q";", Any[!"printf", "%d", !"i", :CALL => 2])
	]
        @test Caper.ast("""
		outer :: for (i = 0; i != 10; i += 1) {
			if (i == 1) continue;
			for (j = 0; j != 10; j += 1) {
				printf(Fmt"%d", i);
				if (i >= 5) break outer;
			}
		}
        """) == Pair{Int, Any}[
	 0 => (q"::", !"outer")
	 0 => (q"for", Any[!"i", 0, q"="], Any[!"i", 10, q"!="], Any[!"i", 1, q"+="])
	 1 => (q"if", Any[!"i", 1, q"=="])
	 2 => (q"continue", :LOOP)
	 1 => (q"for", Any[!"j", 0, q"="], Any[!"j", 10, q"!="], Any[!"j", 1, q"+="])
	 2 => (q";", Any[!"printf", "%d", !"i", :CALL => 2])
	 2 => (q"if", Any[!"i", 5, q">="])
	 3 => (q"break", !"outer")
	]

	@test Caper.ast("""
	int : delta = 0;
	int^ : ptr = nil;
	: mask = h"ff";
        """) == Pair{Int, Any}[
	 0 => (q":", Any[!"int"], !"delta", Any[0])
	 0 => (q":", Any[!"int", q"^"], !"ptr", Any[q"nil"])
	 0 => (q":", nothing, !"mask", Any[0xff])
	]

	@test Caper.ast("""
	int^[3] : array_of_ptr = @{};
	int[3]^ : ptr_of_array = @{1, 2, 3}^;
        """) == Pair{Int, Any}[
	 0 => (q":", Any[!"int", q"^", 3, :INDEX], !"array_of_ptr", Any[:RECORD => 0])
	 0 => (q":", Any[!"int", 3, :INDEX, q"^"], !"ptr_of_array", Any[1, 2, 3, :RECORD => 3, q"^"])
	]

	@test Caper.ast("""
	int : delta = 0;
	int^ : ptr = delta^;
        """) == Pair{Int, Any}[
	 0 => (q":", Any[!"int"], !"delta", Any[0])
	 0 => (q":", Any[!"int", q"^"], !"ptr", Any[!"delta", q"^"])
	]

	@test Caper.ast("""
	int(int, int) : add = fn (int : x, int : y) {
		return x + y;
	};
        """) == Pair{Int, Any}[
	 0 => (q":", Any[!"int", !"int", !"int", :CALL => 2], !"add",
		(q"fn", Any[(q":", Any[!"int"], !"x", nothing),
			    (q":", Any[!"int"], !"y", nothing)],
			Pair{Int, Any}[1 => (q"return", Any[!"x", !"y", q"+"])]))
	]

	@test Caper.ast("""
	int(int, int) : max = fn (int : x, int : y) {
		if (x < y) return y;
		return x;
	};
        """) == Pair{Int, Any}[
	 0 => (q":", Any[!"int", !"int", !"int", :CALL => 2], !"max",
		(q"fn", Any[(q":", Any[!"int"], !"x", nothing),
			    (q":", Any[!"int"], !"y", nothing)],
			Pair{Int, Any}[
			 1 => (q"if", Any[!"x", !"y", q"<"])
			 2 => (q"return", Any[!"y"])
			 1 => (q"return", Any[!"x"])
			]))
	]

	@test Caper.ast("""
	: max = fn () {
		if (x < y) { if (y == 0) { return 0; } else { return y; } }
		else  return x;
	};
	""") == Caper.ast("""
	: max = fn () {
		if (x < y) { if (y == 0)  return 0;  else return y; }
		else  return x;
	};
	""")
	# TODO: Decide
	# == Caper.ast("""
	# : max = fn () {
	#  	if (x < y) if (y == 0)  return 0;  else return y;
	# 	else  return x;
	# };
        # """)
end

@testset "Files" begin
	@test Caper.ast("""
	void(byte[_], byte[_], size_t) : memcpy = fn (:src, :dst, :nbytes) {
	    for (; nbytes > 0; nbytes -= 1) {
		dst[nbytes] = src[nbytes];
	    }
	};
	""") == Pair{Int, Any}[
	 0 => (q":", Any[!"void", !"byte", q"_", :INDEX, !"byte", q"_", :INDEX, !"size_t", :CALL => 3],
		!"memcpy",
		(:fn, Any[(q":", nothing, !"src", nothing),
			(q":", nothing, !"dst", nothing),
			(q":", nothing, !"nbytes", nothing)],
			Pair{Int, Any}[
			 1 => (q"for", Any[], Any[!"nbytes", 0, q">"], Any[!"nbytes", 1, q"-="]),
			 2 => (q";", Any[!"dst", !"nbytes", :INDEX, !"src", !"nbytes", :INDEX, q"="])
			]))
	]

	file = read("test/echo.ca", String)
	@test Caper.ast(file) == Pair{Int, Any}[
	 0 => (q"include", "<stdio.h>")
	 0 => (q":", Any[!"int", !"int", !"char", q"^", q"_", :INDEX, :CALL => 2],
		!"main",
		(q"fn", Any[(q":", Any[!"int"], !"argc", nothing),
			    (q":", Any[!"char", q"^", q"_", :INDEX], !"argv", nothing)],
			Pair{Int, Any}[
			 1 => (q"if", Any[!"argc", 2, q"<"]),
			 2 => (q"return", Any[1]),
			 1 => (q";", Any[!"puts", !"argv", 1, :INDEX, :CALL => 1]),
			 1 => (q"return", Any[0])
			]))
	]
end

@testset "Codegen" begin
	for f = ["echo", "cat"]
		file = read("test/$f.ca", String)
		file_c = read("test/$f.c", String)
		@test Caper.gen(file) == file_c
	end
end

