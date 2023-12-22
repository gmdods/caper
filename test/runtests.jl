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
		for (i: int{0}; i != 10; i += 1) {
			printf(Fmt"%d", i);
		}
        """) == Pair{Int, Any}[
	 0 => (q"for", (q":", !"i", Any[!"int"], Any[0, :RECORD => 1]),
		 Any[!"i", 10, q"!="], Any[!"i", 1, q"+="])
	 1 => (q";", Any[!"printf", "%d", !"i", :CALL => 2])
	]
        @test Caper.ast("""
		#outer for (i = 0; i != 10; i += 1) {
			if (i == 1) continue;
			for (j = 0; j != 10; j += 1) {
				printf(Fmt"%d", i);
				if (i >= 5) break outer;
			}
		}
        """) == Pair{Int, Any}[
	 0 => (q"#", !"outer")
	 0 => (q"for", (q";", Any[!"i", 0, q"="]), Any[!"i", 10, q"!="], Any[!"i", 1, q"+="])
	 1 => (q"if", Any[!"i", 1, q"=="])
	 2 => (q"continue", :LOOP)
	 1 => (q"for", (q";", Any[!"j", 0, q"="]), Any[!"j", 10, q"!="], Any[!"j", 1, q"+="])
	 2 => (q";", Any[!"printf", "%d", !"i", :CALL => 2])
	 2 => (q"if", Any[!"i", 5, q">="])
	 3 => (q"break", !"outer")
	]

	@test Caper.ast("""
	delta: int{0};
	ptr: int^{nil};
	array: int[3]{1, 2, 3};
	mask: _{h"ff"};
        """) == Pair{Int, Any}[
	 0 => (q":", !"delta", Any[!"int"], Any[0, :RECORD => 1])
	 0 => (q":", !"ptr", Any[!"int", q"^"], Any[q"nil", :RECORD => 1])
	 0 => (q":", !"array", Any[!"int", 3, :INDEX], Any[1, 2, 3, :RECORD => 3])
	 0 => (q":", !"mask", Any[q"_"], Any[0xff, :RECORD => 1])
	]

	@test Caper.ast("""
	array_of_ptr: int^[3]{};
	ptr_of_array: int[3]^{@{1, 2, 3}^};
        """) == Pair{Int, Any}[
	 0 => (q":", !"array_of_ptr", Any[!"int", q"^", 3, :INDEX], Any[:RECORD => 0])
	 0 => (q":", !"ptr_of_array", Any[!"int", 3, :INDEX, q"^"], Any[1, 2, 3, :RECORD => 3, q"^", :RECORD => 1])
	]

	@test Caper.ast("""
	delta: int{0};
	ptr: int^{delta^};
        """) == Pair{Int, Any}[
	 0 => (q":", !"delta", Any[!"int"], Any[0, :RECORD => 1])
	 0 => (q":", !"ptr", Any[!"int", q"^"], Any[!"delta", q"^", :RECORD => 1])
	]

	@test Caper.ast("""
	add: fn (x: int, y: int): int {
		return x + y;
	};
        """) == Pair{Int, Any}[
	 0 => (q":", !"add", nothing,
		(q"fn", Any[(q":", !"x", Any[!"int"], nothing),
			    (q":", !"y", Any[!"int"], nothing)],
			Any[!"int"],
			Pair{Int, Any}[1 => (q"return", Any[!"x", !"y", q"+"])]))
	]

	@test Caper.ast("""
	max: fn (x: int, y: int): int {
		if (x < y) return y;
		return x;
	};
        """) == Pair{Int, Any}[
	 0 => (q":", !"max", nothing,
		(q"fn", Any[(q":", !"x", Any[!"int"], nothing),
			    (q":", !"y", Any[!"int"], nothing)],
			Any[!"int"],
			Pair{Int, Any}[
			 1 => (q"if", Any[!"x", !"y", q"<"])
			 2 => (q"return", Any[!"y"])
			 1 => (q"return", Any[!"x"])
			]))
	]

	@test Caper.ast("""
	max: fn (): void {
		if (x < y) { if (y == 0) { return 0; } else { return y; } }
		else  return x;
	};
	""") == Caper.ast("""
	max: fn (): void {
		if (x < y) { if (y == 0)  return 0;  else return y; }
		else  return x;
	};
	""")
	# TODO: Decide
	# == Caper.ast("""
	# max: fn (): void {
	#  	if (x < y) if (y == 0)  return 0;  else return y;
	# 	else  return x;
	# };
        # """)
end

@testset "Files" begin
	@test Caper.ast("""
	memcpy: fn (src: byte[_], dst: byte[_], nbytes: size_t): void {
	    for (; nbytes > 0; nbytes -= 1) {
		dst[nbytes] = src[nbytes];
	    }
	};
	""") == Pair{Int, Any}[
	 0 => (q":", !"memcpy", nothing,
		(:fn, Any[
			(q":", !"src", Any[!"byte", q"_", :INDEX], nothing),
			(q":", !"dst", Any[!"byte", q"_", :INDEX], nothing),
			(q":", !"nbytes", Any[!"size_t"], nothing)],
			Any[!"void"],
			Pair{Int, Any}[
			 1 => (q"for", (q";", Any[]),
				Any[!"nbytes", 0, q">"], Any[!"nbytes", 1, q"-="]),
			 2 => (q";", Any[!"dst", !"nbytes", :INDEX, !"src", !"nbytes", :INDEX, q"="])
			]))
	]

	file = read("test/echo.ca", String)
	@test Caper.ast(file) == Pair{Int, Any}[
	 0 => (q"include", "<stdio.h>")
	 0 => (q":", !"main", nothing,
		(q"fn", Any[
			(q":", !"argc", Any[!"int"], nothing),
			(q":", !"argv", Any[!"char", q"^", q"_", :INDEX], nothing)],
			Any[!"int"],
			Pair{Int, Any}[
			 1 => (q"if", Any[!"argc", 2, q"<"]),
			 2 => (q"return", Any[1]),
			 1 => (q";", Any[!"puts", !"argv", 1, :INDEX, :CALL => 1]),
			 1 => (q"return", Any[0])
			]))
	]
end

@testset "Codegen" begin
	for f = ["echo", "cat", "rec", "foreach"]
		file = read("test/$f.ca", String)
		file_c = read("test/$f.c", String)
		@test Caper.gen(file) == file_c
	end
end

