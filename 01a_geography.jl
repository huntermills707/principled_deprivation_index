#import pandas as pd
using CSV
using DataFrames
using XLSX

#HUD
println("loading HUD data")
df_tz = DataFrame(XLSX.readtable("raw_data/hud/TRACT_ZIP_032023.xlsx", "TRACT_ZIP_032023"));
df_zc = DataFrame(XLSX.readtable("raw_data/hud/ZIP_COUNTY_032023.xlsx", "ZIP_COUNTY_032023"));

#https://gist.github.com/aodin/24c30ba793e404a0270f8c8ef2be350b
println("loading state data")
df_state = DataFrame(CSV.File("raw_data/states_fips.csv"; delim=", "));

#https://www2.census.gov/geo/docs/reference/codes2020/national_county2020.txt
println("loading county data")
df_county = DataFrame(CSV.File("raw_data/census/national_county2020.txt"; delim="|"));

## derive county fips from state and county ids
println("deriving county FIPs")
df_county[:, :COUNTY] = df_county[:, :STATEFP] .* 1000 + df_county[:, :COUNTYFP]
df_county = df_county[:, [:COUNTY, :COUNTYNAME, :STATE]]

## merge tract+zcta and zcta+county data
## focus on residential (drop when 0)
## rename RES_RATIO for tract+zcta and zcta+county data respetively
println("Merging data")

m = df_zc[:, :RES_RATIO] .!= 0;
cols = [:ZIP, :COUNTY, :USPS_ZIP_PREF_CITY, :RES_RATIO];
df_zc = df_zc[m, cols];
transform!(df_zc, :COUNTY => ByRow(x -> parse(Int, x)), renamecols=false);
transform!(df_zc, :ZIP => ByRow(x -> parse(Int, x)), renamecols=false);

m = df_tz[:, :RES_RATIO] .!= 0;
cols = [:TRACT, :ZIP, :RES_RATIO];
df_tz = df_tz[m, cols];
transform!(df_tz, :ZIP => ByRow(x -> parse(Int, x)), renamecols=false);

geog = innerjoin(df_zc, df_county; on=:COUNTY);
rename!(geog, (:RES_RATIO => :ZC_RATIO));
geog = innerjoin(geog, df_tz; on=:ZIP);
rename!(geog, (:RES_RATIO => :TZ_RATIO));

# define tract county ratio (assume homogenity)
geog[:, :TC_RATIO] = geog[:, :TZ_RATIO] .* geog[:, :ZC_RATIO]

# normalize column names
println("normalize results")
rename!(geog, (:STATE => :stusps));
geog = innerjoin(geog, df_state; on=:stusps);
rename!(geog, [
    (:st => :STATE),
    (:stname => :STATENAME),
    (:stusps => :STATEABV),
    (:USPS_ZIP_PREF_CITY => :CITYNAME)
]);

geog = geog[:, [:TRACT, :ZIP, :COUNTY, :STATE,
             :CITYNAME, :COUNTYNAME, :STATENAME, :STATEABV,
             :TZ_RATIO, :ZC_RATIO, :TC_RATIO]];

# convert to lowercase for easier downstream joining
geog[:, :CITYNAME] = lowercase.(geog[:, :CITYNAME]);
geog[:, :COUNTYNAME] = lowercase.(geog[:, :COUNTYNAME]);
geog[:, :STATENAME] = lowercase.(geog[:, :STATENAME]);

# remove county modifiers
geog[:, :COUNTYNAME] = replace(geog[:, :COUNTYNAME], (" county" => ""));
geog[:, :COUNTYNAME] = replace(geog[:, :COUNTYNAME], (" municipio" => ""));
geog[:, :COUNTYNAME] = replace(geog[:, :COUNTYNAME], (" city" => ""));
geog[:, :COUNTYNAME] = replace(geog[:, :COUNTYNAME], (" census area" => ""));

# export
println("saving results")
fname = "derived_data/geography.csv"
CSV.write(fname, geog)
