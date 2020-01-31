using BenchmarkTools
const BT = BenchmarkTools

using Printf

"""
    compare(res1, res2)

"""
function compare(res1, res2)
    m1, m2 = BT.median(res1), BT.median(res2)

    ratios = ratio(m1, m2)

    nwin = 0
    ndef = 0
    ntie = 0

    mem_tot_1 = 0
    mem_tot_2 = 0

    time_tot_1 = 0
    time_tot_2 = 0

    # Display per-instance results
    for (k, g) in ratios
        println(k)
        for (finst, r) in g
            tj = judge(r)

            if time(tj) == :improvement
                nwin += 1
            elseif time(tj) == :invariant
                ntie += 1
            else
                ndef += 1
            end

            mem_tot_1 += memory(m1[k][finst])
            mem_tot_2 += memory(m2[k][finst])
            time_tot_1 += time(m1[k][finst])
            time_tot_2 += time(m2[k][finst])

            @printf("%18s | %+8.2f%% => %-12s | %+8.2f%% => %-12s |\n",
                finst[1:end-4],
                (memory(r)-1), "$(memory(tj))",
                (time(r)-1), "$(time(tj))"
            )
        end
    end

    println()
    @printf "  Total  | %14s | %14s | %8s  |\n" "Old" "New" "% var"
    @printf "%s+%s+%s+%s+\n" "-"^9 "-"^16 "-"^16 "-"^11
    @printf "  time   | %12.2fs  | %12.2fs  | %+8.2f%% |\n" (time_tot_2 / 1e9) (time_tot_1 / 1e9) 100*((time_tot_1 / time_tot_2)-1)
    @printf "  memory | %12.2fkb | %12.2fkb | %+8.2f%% |\n" (mem_tot_2 / 1024^2) (mem_tot_1 / 1024^2) 100*((mem_tot_1 / mem_tot_2)-1)
    @printf "%s+%s+%s+%s+\n" "-"^9 "-"^16 "-"^16 "-"^11
    println("\nSummary: $nwin improvements, $ndef regressions, $ntie invariants")
end

compare(BT.load(ARGS[1])[1], BT.load(ARGS[2])[1])