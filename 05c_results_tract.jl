using CSV, DataFrames
using HypothesisTests, StatsAPI

include("helpers/analysis.jl")
include("helpers/plots.jl")

df_x = DataFrame(CSV.File("weights/tract_X.csv"))[:, ["TRACT", "1"]]
rename!(df_x, [("1" => :x)]);

df_ha = DataFrame(CSV.File("raw_data/ucsf_health_atlas/health-atlas-tract.csv"))
df_adi = DataFrame(CSV.File("raw_data/stanford_readi/ReADI_CT_2022.csv"))[:, [:GEOID, :ReADI_CT_Raw]]
df_ha = leftjoin(df_ha, df_adi, on=:GEOID)
rename!(df_ha, [(:GEOID => :TRACT)]);

df = leftjoin(df_ha, df_x, on=:TRACT);

new_names = [
    :x => :PDI
    :ReADI_CT_Raw => :ReADI
    :ndi => :NDI
    :RPL_THEMES => :SVI
    :risk_score => :NRI
    :nses_index => :nSES
]

rename!(df, new_names...)

indices = [
    :PDI,
    :ReADI,
    :NDI,
    :SVI,
    :NRI,
    :nSES,
]

df[:, :nSES] .*= -1;

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
    plot_tract(df, condition, name)
end

df_y = DataFrame(CSV.File("weights/tract_Y.csv"));

for r in zip(names(df_y), permutedims(df_y)[:,1])
    println(r);
end
