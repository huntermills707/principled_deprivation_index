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


function ratio(sub_df, :col1, :col2)
    # Keep only rows where BOTH columns are non‑missing
    clean = dropmissing(sub_df, [:col1, :col2])

    # If everything got dropped, avoid division‑by‑zero
    if nrow(clean) == 0
        return missing
    end

    s1 = sum(skipmissing(clean.col1))
    s2 = sum(skipmissing(clean.col2))
    return s1 / s2
end

food_data_zip = combine(groupby(df_food, :ZIP)) do sub_df
  (:lahunv1share = ratio(sub_df, :lahunv1, :TractHUNV ),
   :lahunv10share = ratio(sub_df, :lahunv10, :TractHUNV ),
   :lasnap1share = ratio(sub_df, :lasnap1, :TractSNAP),
   :lasnap1share = ratio(sub_df, :lasnap1, :TractSNAP))
end

food_data_county = combine(groupby(df_food, :COUNTY)) do sub_df
  (:lahunv1share = ratio(sub_df, :lahunv1, :TractHUNV ),
   :lahunv10share = ratio(sub_df, :lahunv10, :TractHUNV ),
   :lasnap1share = ratio(sub_df, :lasnap1, :TractSNAP),
   :lasnap1share = ratio(sub_df, :lasnap1, :TractSNAP))
end

CSV.write(food_data_county, "derived_data/county/usda_food_insecure.csv")
CSV.write(food_data_zcta, "derived_data/zcta/usda_food_insecure.csv")
CSV.write(food_data_tract, "derived_data/tract/usda_food_insecure.csv")
