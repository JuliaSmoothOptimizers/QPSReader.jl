@testset "Rim data" begin
    

    @testset "Objective" begin
        qp = readqps("dat/rim_obj.qps", verbose=false)

        @test qp.objname == "obj1"
        @test qp.conindices["obj1"] == 0
        @test qp.conindices["obj2"] == -1
        @test qp.conindices["obj3"] == -1

        @test qp.c0 == 4.1

        @test qp.c == [1.5, -2.1]
    end

    @testset "Columns" begin
    end

    @testset "QuadObj" begin
    end

    @testset "RHS" begin
        qp = readqps("dat/rim_rhs.qps", verbose=false)

        @test qp.rhsname == "rhs1"

        @test qp.c0 == 4.1

        @test qp.lcon == [2.0, -Inf]
        @test qp.ucon == [Inf, 6.0]
    end

    @testset "Range" begin
        qp = readqps("dat/rim_rng.qps", verbose=false) 

        @test qp.rngname == "rng1"

        @test qp.lcon == [2.0, 3.9]
        @test qp.ucon == [3.1, 6.0]
    end

    @testset "Bounds" begin
    end

end