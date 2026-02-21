using CSV, DataFrames
using HypothesisTests, StatsAPI

include("helpers/analysis.jl")
include("helpers/plots.jl")

df_x = DataFrame(CSV.File("weights/county_X.csv"))[:, ["COUNTY", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-2026-01-27-county.csv"))

rename!(df_ha, [(:GEOID => :COUNTY)]);

df = leftjoin(df_ha, df_x, on=:COUNTY);

new_names = [
    :x => :PDI
    :ndi => :NDI
    :RPL_THEMES => :SVI
    :risk_score => :NRI
]

rename!(df, new_names...)

indices = [
    :PDI,
    :NDI,
    :SVI,
    :NRI,
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
    plot_county(df, condition, name)
end

mkpath("final")

CSV.write("final/county_results.csv", df);

df_y = DataFrame(CSV.File("weights/county_Y.csv"));

for r in zip(names(df_y), permutedims(df_y)[:,1])
    println(r);
end
