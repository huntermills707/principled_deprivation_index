using CSV, DataFrames
using Statistics, HypothesisTests, StatsAPI
using Plots
using StatsPlots

include("analysis.jl")
include("plots.jl")

df_x = DataFrame(CSV.File("weights/zcta_X.csv"))[:, ["ZIP", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-2026-01-27-zip.csv"))

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

for (condition, name) in conditions
    plot_zip(df, condition, name)
end
