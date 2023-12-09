using Test, Documenter, Caper

@testset "Reader" begin
	@test Caper.literal("1234") == 1234
	@test Caper.literal("012") == 12
end
