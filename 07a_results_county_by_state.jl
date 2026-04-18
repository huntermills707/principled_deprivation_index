using CSV, DataFrames
using HypothesisTests, StatsAPI
using Statistics

include("helpers/analysis.jl")

# ── Load data (same as 05a) ──────────────────────────────────────────────────
df_x = DataFrame(CSV.File("weights/county_X.csv"))[:, ["COUNTY", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-county.csv"))
df_adi = DataFrame(CSV.File("raw_data/stanford_readi/ReADI_C_2022.csv"))[:, [:GEOID, :ReADI_C_Raw]]
df_ha = leftjoin(df_ha, df_adi, on=:GEOID)

rename!(df_ha, [(:GEOID => :COUNTY)]);

df = leftjoin(df_ha, df_x, on=:COUNTY);

new_names = [
    :x => :PDI
    :ReADI_C_Raw => :ReADI
    :ndi => :NDI
    :RPL_THEMES => :SVI
    :risk_score => :NRI
]

rename!(df, new_names...)

# ── Derive state FIPS from county FIPS ───────────────────────────────────────
df[:, :STATE] = div.(df[:, :COUNTY], 1000);

indices = [
    :PDI,
    :ReADI,
    :NDI,
    :SVI,
    :NRI,
]

# ── State-level correlation function ─────────────────────────────────────────
function compare_state(df_state, col)
    """
    Same as `compare`, but operates on a state-subset DataFrame.
    Returns NaN when fewer than 10 non-missing pairs exist.
    """
    vals = zeros(length(conditions))
    for (i, (condition, _)) in enumerate(conditions)
        x = dropmissing(df_state[:, [condition, col]])
        if nrow(x) >= 10
            vals[i] = cor(x[:, condition], x[:, col])
        else
            vals[i] = NaN
        end
    end
    return vals
end

# ── Load state names for display ─────────────────────────────────────────────
df_states = DataFrame(CSV.File("raw_data/states_fips.csv"; delim=", "))
state_lookup = Dict(row.st => row.stname for row in eachrow(df_states))

# ── Compute correlations grouped by state ────────────────────────────────────
states = sort(unique(skipmissing(df[:, :STATE])))

# Collect all state results into a single DataFrame
all_state_results = DataFrame()

for st in states
    df_st = df[df[:, :STATE] .== st, :]
    state_name = get(state_lookup, st, string(st))

    state_results = DataFrame(
        Condition = [name for (_, name) in conditions]
    )

    for index in indices
        state_results[:, index] = compare_state(df_st, index)
    end

    # Add state identifiers
    state_results[:, :STATE_FIPS] .= st
    state_results[:, :STATE_NAME] .= state_name
    state_results[:, :N_COUNTIES] .= nrow(df_st)

    append!(all_state_results, state_results)
end

# ── Print per-state results ──────────────────────────────────────────────────
println("=" ^ 80)
println("COUNTY-LEVEL CORRELATIONS BY STATE")
println("=" ^ 80)

for st in states
    state_name = get(state_lookup, st, string(st))
    mask = all_state_results[:, :STATE_FIPS] .== st
    state_df = all_state_results[mask, :]
    n = first(state_df[:, :N_COUNTIES])

    println("\n── $state_name (FIPS: $st, N=$n counties) ──")
    println(state_df[:, [:Condition; indices]])
end

# ── Interstate rankings ─────────────────────────────────────────────────────
# For each index, compute the mean correlation across conditions per state,
# then rank states.
println("\n\n")
println("=" ^ 80)
println("INTERSTATE RANKINGS (by mean |correlation| across conditions)")
println("=" ^ 80)

for index in indices
    rank_df = DataFrame(
        STATE_FIPS = Int[],
        STATE_NAME = String[],
        N_COUNTIES = Int[],
        MEAN_COR = Float64[],
        MEAN_ABS_COR = Float64[],
        MEDIAN_COR = Float64[]
    )

    for st in states
        state_name = get(state_lookup, st, string(st))
        mask = all_state_results[:, :STATE_FIPS] .== st
        cors = all_state_results[mask, index]
        valid = filter(!isnan, cors)

        if length(valid) >= 5
            push!(rank_df, (
                st,
                state_name,
                first(all_state_results[mask, :N_COUNTIES]),
                mean(valid),
                mean(abs.(valid)),
                median(valid)
            ))
        end
    end

    sort!(rank_df, :MEAN_ABS_COR, rev=true)
    rank_df[:, :RANK] = 1:nrow(rank_df)

    println("\n── Rankings for $index ──")
    println(rank_df[:, [:RANK, :STATE_NAME, :N_COUNTIES, :MEAN_COR, :MEAN_ABS_COR, :MEDIAN_COR]])
end

# ── Pairwise t-tests on mean correlations across states ──────────────────────
println("\n\n")
println("=" ^ 80)
println("INTERSTATE PAIRWISE T-TESTS (comparing index performance across states)")
println("=" ^ 80)

# Build a matrix: rows = states, cols = indices, values = mean correlation
state_means = DataFrame()
for index in indices
    means = Float64[]
    for st in states
        mask = all_state_results[:, :STATE_FIPS] .== st
        cors = all_state_results[mask, index]
        valid = filter(!isnan, cors)
        push!(means, length(valid) >= 5 ? mean(valid) : NaN)
    end
    state_means[:, index] = means
end

n = length(indices)
pvals = DataFrame([[NaN for _ in 1:n] for _ in 1:n], indices)

for i in 1:n
    for j in i+1:n
        v1 = filter(!isnan, state_means[:, i])
        v2 = filter(!isnan, state_means[:, j])
        if length(v1) >= 3 && length(v2) >= 3
            ttest = OneSampleTTest(
                collect(skipmissing(state_means[:, i] .- state_means[:, j]))
            )
            pvals[i, j] = pvalue(ttest)
        end
    end
end

println(pvals)

# ── Export results ───────────────────────────────────────────────────────────
CSV.write("derived_data/07a_county_by_state_correlations.csv", all_state_results)
println("\nResults saved to derived_data/07a_county_by_state_correlations.csv")
