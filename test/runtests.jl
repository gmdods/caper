using Test, Documenter, Caper

@testset "Reader" begin
        @test Caper.literal("1234") == 1234
        @test Caper.literal("012") == 12
        @test Caper.literal("-1") == -1

        @test Caper.literal("42"; prefix=:u) == UInt(42)
        @test Caper.literal("11101"; prefix=:b) == 0b11101
        @test Caper.literal("3f"; prefix=:h) == 0x3f

        @test Caper.literal("1.0"; prefix=:f) == 1.0
        @test Caper.literal("1e3"; prefix=:f) == 1e3

        @test Caper.literal("a"; prefix=:char) == 0x61
        @test Caper.literal("é"; prefix=:utf) == 0x0000_00_e9

        @test Caper.literal("[0-9]+"; prefix=:re) == r"[0-9]+"
        @test Caper.literal(raw"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+"; prefix=:re) ==
              r"\p{L}[\p{L}\p{N}]*\s+=\s+\p{N}+"
end
