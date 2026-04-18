using CSV, DataFrames
using HypothesisTests, StatsAPI
using Statistics

include("helpers/analysis.jl")

# ── Load data (same as 05b) ─────────────────────────────────────────────────
df_x = DataFrame(CSV.File("weights/zcta_X.csv"))[:, ["ZIP", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-zip.csv"))

rename!(df_ha, [(:GEOID => :ZIP)]);

df = leftjoin(df_ha, df_x, on=:ZIP);

new_names = [
    :x => :PDI
    :ndi => :NDI
]

rename!(df, new_names...)

indices = [
    :PDI,
    :NDI,
]

# ── Derive state from geography crosswalk ────────────────────────────────────
# ZCTAs don't encode state in their FIPS, so use the geography crosswalk.
# Pick the state with the highest residential ratio for each ZIP.
geog = DataFrame(CSV.File("derived_data/geography.csv"))
zip_state = combine(
    groupby(geog[:, [:ZIP, :STATE, :ZC_RATIO]], [:ZIP, :STATE]),
    :ZC_RATIO => sum => :TOTAL_RATIO
)
zip_state = combine(groupby(zip_state, :ZIP)) do sub
    sub[argmax(sub.TOTAL_RATIO), :]
end
zip_state = zip_state[:, [:ZIP, :STATE]]

df = leftjoin(df, zip_state, on=:ZIP);

# ── State-level correlation function ─────────────────────────────────────────
function compare_state(df_state, col)
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

all_state_results = DataFrame()

for st in states
    mask = .!ismissing.(df[:, :STATE]) .& (df[:, :STATE] .== st)
    df_st = df[mask, :]
    state_name = get(state_lookup, st, string(st))

    state_results = DataFrame(
        Condition = [name for (_, name) in conditions]
    )

    for index in indices
        state_results[:, index] = compare_state(df_st, index)
    end

    state_results[:, :STATE_FIPS] .= st
    state_results[:, :STATE_NAME] .= state_name
    state_results[:, :N_ZCTAS] .= nrow(df_st)

    append!(all_state_results, state_results)
end

# ── Print per-state results ──────────────────────────────────────────────────
println("=" ^ 80)
println("ZCTA-LEVEL CORRELATIONS BY STATE")
println("=" ^ 80)

for st in states
    state_name = get(state_lookup, st, string(st))
    mask = all_state_results[:, :STATE_FIPS] .== st
    state_df = all_state_results[mask, :]
    n = first(state_df[:, :N_ZCTAS])

    println("\n── $state_name (FIPS: $st, N=$n ZCTAs) ──")
    println(state_df[:, [:Condition; indices]])
end

# ── Interstate rankings ─────────────────────────────────────────────────────
println("\n\n")
println("=" ^ 80)
println("INTERSTATE RANKINGS (by mean |correlation| across conditions)")
println("=" ^ 80)

for index in indices
    rank_df = DataFrame(
        STATE_FIPS = Int[],
        STATE_NAME = String[],
        N_ZCTAS = Int[],
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
                first(all_state_results[mask, :N_ZCTAS]),
                mean(valid),
                mean(abs.(valid)),
                median(valid)
            ))
        end
    end

    sort!(rank_df, :MEAN_ABS_COR, rev=true)
    rank_df[:, :RANK] = 1:nrow(rank_df)

    println("\n── Rankings for $index ──")
    println(rank_df[:, [:RANK, :STATE_NAME, :N_ZCTAS, :MEAN_COR, :MEAN_ABS_COR, :MEDIAN_COR]])
end

# ── Pairwise t-tests on mean correlations across states ──────────────────────
println("\n\n")
println("=" ^ 80)
println("INTERSTATE PAIRWISE T-TESTS (comparing index performance across states)")
println("=" ^ 80)

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
        valid_pairs = .!isnan.(state_means[:, i]) .& .!isnan.(state_means[:, j])
        diffs = state_means[valid_pairs, i] .- state_means[valid_pairs, j]
        if length(diffs) >= 3
            ttest = OneSampleTTest(diffs)
            pvals[i, j] = pvalue(ttest)
        end
    end
end

println(pvals)

# ── Export results ───────────────────────────────────────────────────────────
CSV.write("derived_data/07b_zcta_by_state_correlations.csv", all_state_results)
println("\nResults saved to derived_data/07b_zcta_by_state_correlations.csv")
