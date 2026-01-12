using CSV
using DataFrames

geog = DataFrame(CSV.File("derived_data/geography.csv"))

#https://hazards.fema.gov/nri/expected-annual-loss

df_nri_county = DataFrame(CSV.File("raw_data/fema_eal/NRI_Table_Counties/NRI_Table_Counties.csv"))

nri_data_county = df_nri_county[:, [
    :STATEFIPS, :COUNTY, :STCOFIPS,
    :ALR_VALB, :ALR_VALP, :ALR_VALA
]]

rename!(nri_data_county, [
    (:STATEFIPS => :STATE),
    (:COUNTY => :COUNTYNAME),
    (:STCOPIPS => :COUNTY),
])

transform!(nri_data_county, :COUNTYNAME => ByRow(x -> x === missing ? missing : lowercase(x)) => :COUNTYNAME)

df_nri_tract = DataFrame(CSV.File("raw_data/fema_eal/NRI_Table_CensusTracts/NRI_Table_CensusTracts.csv"))

nri_data_tract = df_nri_tract[: [
    :TRACTFIPS, :ALR_VALB, :ALR_VALP, :ALR_VALA
]]

rename!(nri_data_tract, (:TRACTFIPS => :TRACT))

nri_data_zip = df_nri_tract[[
    :TRACTFIPS,
    :ALR_VALB, :ALR_VALP, :ALR_VALA,
    :EAL_VALB, :EAL_VALP, :EAL_VALA,
    :POPULATION, :BUILDVALUE, :AGRIVALUE
]]


rename!(nri_data_zip, (:TRACTFIPS => :TRACT))

nri_data_zip = innerjoin(nri_data_zip, geog, on=:Tract)

nri_data_zip[:, :EAL_VALB] .*= nri_data_zip[:, :TZ_RATIO]
nri_data_zip[:, :EAL_VALP] .*= nri_data_zip[:, :TZ_RATIO]
nri_data_zip[:, :EAL_VALA] .*= nri_data_zip[:, :TZ_RATIO]
nri_data_zip[:, :POPULATION] .*= nri_data_zip[:, :TZ_RATIO]
nri_data_zip[:, :BUILDVALUE] .*= nri_data_zip[:, :TZ_RATIO]
nri_data_zip[:, :AGRIVALUE] .*= nri_data_zip[:, :TZ_RATIO]

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

nri_data_zip = combine(groupby(nri_data_zip, :ZIP)) do sub_df
    (ALR_VALB = ratio(sub_df, :EAL_VALB, :BUILDVALUE),
     ALR_VALP = ratio(sub_df, :EAL_VALP, :POPULATION),
     ALR_VALA = ratio(sub_df, :EAL_VALA, :AGRIVALUE))
end

CSV.write(nri_data_county, "derived_data/county/fema_eal.csv")
CSV.write(nri_data_zip, "derived_data/zcta/fema_eal.csv")
CSV.write(nri_data_tract, "derived_data/tract/fema_eal.csv")

