using Test, Documenter, Caper

@testset "Reader" begin
	@test Caper.literal("1234") == 1234
	@test Caper.literal("012") == 12
	@test Caper.literal("-1") == -1
	@test Caper.literal("42"; prefix=:u) == UInt(42)
	@test Caper.literal("11101"; prefix=:b) == 0b11101
	@test Caper.literal("3f"; prefix=:h) == 0x3f
end
