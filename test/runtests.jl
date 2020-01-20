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

@testset "Test @comeagain" begin
    @test @comeagain sin(0) == 0
    @test isnothing(@comeagain sin("a"))
end

@testset "Test help" begin
    help("5")
    help("6")
end

@testset "Test showerror" begin
    showerror("5")
    showerror()

    @test showerror("6") == nothing
    @test showerror("1") == nothing
end

BegYourPardon.setticketdir(original)
