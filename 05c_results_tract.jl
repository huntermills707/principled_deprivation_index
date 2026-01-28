using CSV, DataFrames
using Statistics, HypothesisTests, StatsAPI
using Plots
using StatsPlots

include("analysis.jl")

df_x = DataFrame(CSV.File("weights/tract_X.csv"))[:, ["TRACT", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-2026-01-27-tract.csv"))

rename!(df_ha, [(:GEOID => :TRACT)]);

df = leftjoin(df_ha, df_x, on=:TRACT);

indices = [
    :x,
    :ndi,
    :RPL_THEMES,
    :risk_score,
    :nses_index,
]

df[:, :nses_index] .*= -1;

results = DataFrame([[name for (_, name) in conditions]], ["Condition"])

for index in indices
    results[:, index] = compare(df, index)
end

println(results)

n = length(indices)
X = [[NaN for _ in 1:n] for _ in 1:n]

pvals = DataFrame(X, indices)

for i in 1:n
    for j in i+1:n
        ttest = OneSampleTTest(results[:, i+1], results[:, j+1])
        pvals[i,j] = pvalue(ttest)
    end
end

println(pvals)
