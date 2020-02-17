@testset "Rim data" begin

    @testset "Objective" begin

        qp = @test_logs(
            (:warn, "Detected rim objective row obj2."),
            (:warn, "Detected rim objective row obj3."),
            (:error, "Ignoring coefficient (obj2, c1) with value 2.2"),
            (:error, "Ignoring coefficient (obj2, c2) with value -2.2"),
            (:error, "Ignoring coefficient (obj3, c1) with value 2.3"),
            (:error, "Ignoring coefficient (obj3, c2) with value -2.3"),
            (:error, "Ignoring RHS for rim objective obj2"),
            (:info, "Problem name     : RimObj"),
            (:info, "Objective sense  : notset"),
            (:info, "Objective name   : obj1"),
            (:info, "RHS              : rhs1"),
            match_mode = :all,
            readqps("dat/rim_obj.qps")
        )

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
        qp = @test_logs(
            # These logs should appear in exactly this order
            (:error, "Skipping line with rim RHS rhs2"),
            (:error, "Skipping line with rim RHS rhs2"),
            (:error, "Skipping line with rim RHS rhs3"),
            (:info, "Problem name     : RimRHS"),
            (:info, "Objective sense  : notset"),
            (:info, "Objective name   : obj1"),
            (:info, "RHS              : rhs1"),
            match_mode = :all,
            readqps("dat/rim_rhs.qps")
        )

        @test qp.rhsname == "rhs1"

        @test qp.c0 == 4.1

        @test qp.lcon == [2.0, -Inf]
        @test qp.ucon == [Inf, 6.0]
    end

    @testset "Range" begin
        qp = @test_logs(
            # These logs should appear in exactly this order
            # (:warn, "Detected rim range rng2"),
            (:error, "Skipping line with rim RANGES rng2"),
            (:info, "Problem name     : RimRANGES"),
            (:info, "Objective sense  : notset"),
            (:info, "Objective name   : obj1"),
            (:info, "RHS              : rhs1"),
            (:info, "RANGES           : rng1"),
            match_mode = :all,
            readqps("dat/rim_rng.qps")
        )

        @test qp.rngname == "rng1"

        @test qp.lcon == [2.0, 3.9]
        @test qp.ucon == [3.1, 6.0]
    end

    @testset "Bounds" begin
        qp = @test_logs(
            # These logs should appear in exactly this order
            # (:warn, "Detected rim range rng2"),
            (:error, "Skipping line with rim bound bnd2"),
            (:error, "Skipping line with rim bound bnd2"),
            (:info, "Problem name     : RimObj"),
            (:info, "Objective sense  : notset"),
            (:info, "Objective name   : obj"),
            (:info, "BOUNDS           : bnd1"),
            match_mode = :all,
            readqps("dat/rim_bnd.qps")
        )

        @test qp.bndname == "bnd1"

        @test qp.lvar == [0.0, 1.0]
        @test qp.uvar == [20.0, Inf]
    end

end