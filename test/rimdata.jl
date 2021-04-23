@testset "Rim data" begin
  for format in [:fixed, :free]
    @testset "$format" begin
      @testset "Objective" begin
        qp = @test_logs(
          (:info, "Using 'RimObj' as NAME (l. 1)"),
          (:info, "Using 'obj1' as objective (l. 3)"),
          (:warn, "Detected rim objective row obj2 at line 4"),
          (:warn, "Detected rim objective row obj3 at line 7"),
          (:error, "Ignoring coefficient (obj2, c1) with value 2.2 at line 10"),
          (:error, "Ignoring coefficient (obj2, c2) with value -2.2 at line 12"),
          (:error, "Ignoring coefficient (obj3, c1) with value 2.3 at line 13"),
          (:error, "Ignoring coefficient (obj3, c2) with value -2.3 at line 14"),
          (:info, "Using 'rhs1' as RHS (l. 16)"),
          (:error, "Ignoring RHS for rim objective obj2 at line 16"),
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

      @testset "Columns" begin end

      @testset "QuadObj" begin end

      @testset "RHS" begin
        qp = @test_logs(
          # These logs should appear in exactly this order
          (:info, "Using 'RimRHS' as NAME (l. 1)"),
          (:info, "Using 'obj1' as objective (l. 3)"),
          (:info, "Using 'rhs1' as RHS (l. 12)"),
          (:error, "Skipping line 13 with rim RHS rhs2"),
          (:error, "Skipping line 15 with rim RHS rhs2"),
          (:error, "Skipping line 16 with rim RHS rhs3"),
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
          (:info, "Using 'RimRANGES' as NAME (l. 1)"),
          (:info, "Using 'obj1' as objective (l. 3)"),
          (:info, "Using 'rhs1' as RHS (l. 12)"),
          (:info, "Using 'rng1' as RANGES (l. 15)"),
          (:error, "Skipping line 16 with rim RANGES rng2"),
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
          (:info, "Using 'RimBOUNDS' as NAME (l. 1)"),
          (:info, "Using 'obj' as objective (l. 3)"),
          (:info, "Using 'bnd1' as BOUNDS (l. 12)"),
          (:error, "Skipping line 13 with rim bound bnd2"),
          (:error, "Skipping line 15 with rim bound bnd2"),
          match_mode = :all,
          readqps("dat/rim_bnd.qps")
        )

        @test qp.bndname == "bnd1"

        @test qp.lvar == [0.0, 1.0]
        @test qp.uvar == [20.0, Inf]
      end
    end  # testset
  end  # format loop
end  # RimData testset
