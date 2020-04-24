import QPSReader:
    MPSCard, FreeMPS, FixedMPS, read_card!

function test_parser(card::MPSCard)
    @testset "Comment line" begin test_parser_comment!(card) end

    @testset "Header line" begin test_parser_header!(card) end

    @testset "Regular line" begin test_parser_general!(card) end
end

function test_parser_comment!(card)
    read_card!(card, "* This line is a comment")
    @test card.iscomment
    @test !card.isheader
    @test card.nfields == 0

    return
end

function test_parser_header!(card)
    read_card!(card, "COLUMNS")
    @test !card.iscomment
    @test card.isheader
    @test card.nfields == 1
    @test card.f1 == "COLUMNS"

    read_card!(card, "NAME          QPexample")
    @test !card.iscomment
    @test card.isheader
    @test card.nfields == 2
    @test card.f1 == "NAME"
    @test card.f2 == "QPexample"

    return
end 

function test_parser_general!(card)
    # 2 fields
    read_card!(card, " N  obj")
    @test !card.iscomment
    @test !card.isheader
    @test card.nfields == 2
    @test card.f1 == "N"
    @test card.f2 == "obj"
    # Same, but 3rd character is non-empty instead of 2nd
    read_card!(card, "  N obj")
    @test !card.iscomment
    @test !card.isheader
    @test card.nfields == 2
    @test card.f1 == "N"
    @test card.f2 == "obj"

    # 3 fields (1st fixed field empty)
    read_card!(card, "    rhs1       r1              -4.0")
    @test !card.iscomment
    @test !card.isheader
    @test card.nfields == 3
    @test card.f1 == "rhs1"
    @test card.f2 == "r1"
    @test card.f3 == "-4.0"

    # 4 fields (1st fixed field non-empty)
    read_card!(card, " UP  bnd1      c1               20.0")
    @test !card.iscomment
    @test !card.isheader
    @test card.nfields == 4
    @test card.f1 == "UP"
    @test card.f2 == "bnd1"
    @test card.f3 == "c1"
    @test card.f4 == "20.0"

    # 5 fields (1st fixed field empty)
    read_card!(card, "    c1        r1                2.0    r2               -1.0")
    @test !card.iscomment
    @test !card.isheader
    @test card.nfields == 5
    @test card.f1 == "c1"
    @test card.f2 == "r1"
    @test card.f3 == "2.0"
    @test card.f4 == "r2"
    @test card.f5 == "-1.0"
end

@testset "Line parser" begin
@testset "Fixed" begin
    test_parser(MPSCard{FixedMPS}(0, false, false, 0, "", "", "", "", "", ""))
end

@testset "Free" begin
test_parser(MPSCard{FreeMPS}(0, false, false, 0, "", "", "", "", "", ""))
end
end