using BegYourPardon
using Test

tmp = mktempdir()
original = BegYourPardon.ticketdir
BegYourPardon.setticketdir(tmp)

@testset "Test uniqueid()" begin
    @test BegYourPardon.uniqueid() == "1"
    @test BegYourPardon.uniqueid() == "1"

    touch(joinpath(tmp, "1"))
    @test BegYourPardon.uniqueid() == "2"

    touch(joinpath(tmp, "4"))
    @test BegYourPardon.uniqueid() == "5"

    touch(joinpath(tmp, "2"))
    @test BegYourPardon.uniqueid() == "5"
end

@testset "Test @createticket" begin
    @test @createticket sin(0) == 0
    @test isnothing(@createticket sin("a") == 0)
end

@testset "Test help" begin
    help("5")
    help("6")
end

@testset "Test showticket" begin
    showticket("5")

    @test showticket("6") == nothing
    @test showticket("1") == nothing
end

BegYourPardon.setticketdir(original)
