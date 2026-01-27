using CSV, DataFrames
using Statistics, HypothesisTests
using Plots
using StatsPlots

df_x = DataFrame(CSV.File("weights/county_X.csv"))[:, ["COUNTY", "1"]]
rename!(df_x, [("1" => :x)]);

bhd = DataFrame(CSV.File("raw_data/cdc_places/PLACES__Local_Data_for_Better_Health__County_Data_2024_release_20250523.csv"))

m = [v == "Crude prevalence" for v in bhd[:, "Data_Value_Type"]]
bhd = bhd[m,:]

m = [v == 2022 for v in bhd[:, "Year"]]
bhd = bhd[m,:]

l = [
    "Frequent physical distress among adults",
    "Stroke among adults",
    "Feeling socially isolated among adults",
    "Fair or poor self-rated health status among adults",
    "All teeth lost among adults aged >=65 years",
    "Vision disability among adults",
    "Cognitive disability among adults",
    "Frequent mental distress among adults",
    "Lack of social and emotional support among adults",
    "Mobility disability among adults",
    "Current asthma among adults",
    "Chronic obstructive pulmonary disease among adults",
    "Coronary heart disease among adults",
    "Diagnosed diabetes among adults",
    "Hearing disability among adults",
    "Depression among adults",
    "Short sleep duration among adults",
    "Obesity among adults",
]

df = DataFrame([l], ["BRFSS"])

bhd_t = unique(bhd[:, [:LocationID]])
dropmissing!(bhd_t)

for (i, v) in enumerate(l)
    local m = bhd[:, :Measure] .== v
    y = bhd[m, [:LocationID, :Data_Value]]
    y = combine(groupby(y, :LocationID), :Data_Value=>first=>:Data_Value)
    dropmissing!(y)
    global bhd_t = leftjoin(bhd_t, y, on=:LocationID)
    rename!(bhd_t, [(:Data_Value => v)])
end

ha = DataFrame(CSV.File("raw_data/Health-Atlas-data_county.csv"))

rename!(bhd_t, [(:LocationID => :COUNTY)]);
rename!(ha, [(:GEOID => :COUNTY)]);

res = outerjoin(outerjoin(bhd_t, df_x, on=:COUNTY), ha, on=:COUNTY);

println("\nPDI")
res[:, "x"] = coalesce.(res[:, "x"], NaN)
vals = zeros(size(l))
for (i, v) in enumerate(l)
    res[:, v] = coalesce.(res[:, v], NaN)
    local m = (isnan.(res[:, v]) .+ isnan.(res[:, "x"])) .== 0
    vals[i] = cor(res[m, "x"], res[m, v])
    println(cor(res[m, "x"], res[m, v]), "  ", v)
end
df[!, "x"] = vals;

println("\nNDI")
res[:, "ndi"] = coalesce.(res[:, "ndi"], NaN)
vals = zeros(size(l))
for (i, v) in enumerate(l)
    res[:, v] = coalesce.(res[:, v], NaN)
    local m = (isnan.(res[:, v]) .+ isnan.(res[:, "ndi"])) .== 0
    vals[i] = cor(res[m, "ndi"], res[m, v])
    println(cor(res[m, "ndi"], res[m, v]), "  ", v)
end
df[!, "ndi"] = vals;

println("\nSVI")
res[:, "RPL_THEMES"] = coalesce.(res[:, "RPL_THEMES"], NaN)
vals = zeros(size(l))
for (i, v) in enumerate(l)
    res[:, v] = coalesce.(res[:, v], NaN)
    local m = (isnan.(res[:, v]) .+ isnan.(res[:, "RPL_THEMES"])) .== 0
    vals[i] = cor(res[m, "RPL_THEMES"], res[m, v])
    println(cor(res[m, "RPL_THEMES"], res[m, v]), "  ", v)
end
df[!, "svi"] = vals;


