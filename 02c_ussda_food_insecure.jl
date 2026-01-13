using CSV
using DataFrames

df_food = DataFrame(CSV.File("raw_data/usda/2019 Food Access Research Atlas Data/Food Access Research Atlas.csv"))

geog = DataFrame(CSV.File("derived_data/geography.csv"))

cols = [
    :CensusTract,
    :lahunv1share,
    :lahunv1,
    :lahunv10share,
    :lahunv10,
    :lasnap1share,
    :lasnap1,
    :lasnap10share,
    :lasnap10,
    :TractHUNV,
    :TractSNAP,
]

df_food = df_food[:, cols]

rename!(df_food, (:CensusTract => :TRACT))

food_data_tract = df_food[:, [
    :TRACT,
    :lahunv1share,
    :lahunv10share,
    :lasnap1share,
    :lasnap10share,
]]

unique!(food_data_tract)

df_food = innerjoin(df_food, geog, on=:TRACT)

df_food[:, :lahunv1] .*= df_food[:, :TZ_RATIO]
df_food[:, :lahunv10] .*= df_food[:, :TZ_RATIO]
df_food[:, :lasnap1] .*= df_food[:, :TZ_RATIO]
df_food[:, :lasnap10] .*= df_food[:, :TZ_RATIO]
df_food[:, :TractHUNV] .*= df_food[:, :TZ_RATIO]
df_food[:, :TractSNAP] .*= df_food[:, :TZ_RATIO]


