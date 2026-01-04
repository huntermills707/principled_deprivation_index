using CSV
using DataFrames

function fix(s)
    """
    function to clean up messy cenus values.
    replace repeated negative numbers with NaN.
    convert Sting valuse to Float64.
    """
    if ismissing(s)
        return NaN
    elseif s in [-666666666, -999999999, -888888888, -222222222, -333333333, -555555555,
             "-666666666", "-999999999", "-888888888", "-222222222", "-333333333", "-555555555",
             "Varies", "*", "null"]
        return NaN
    elseif typeof(s) == String
        return parse(Float64, s)
    else
        return s
    end
end

vars = [
    "B01001_001E", "B11005_006E", "B11005_007E", "B11005_008E", "B11005_002E", "B14005_012E",
    "B14005_026E", "B14005_001E", "B20001_002E", "B20001_023E", "B20017A_001E", "B20017B_001E", 
    "B22002_001E", "B22002_002E", "B22002_003E", "B22001_003E", "B28002_013E", "B28002_004E",
    "B28010_005E", "DP04_0058E", "DP04_0073PE", "DP04_0074E", "S0801_C01_045E", "S0801_C01_013E",
    "S0801_C01_009E", "S0801_C01_010E", "S0801_C01_011E", "S0801_C01_001E", "H2_003N", "H2_002N",
    "H2_001N"
]

ovars = ["ucgid",
    "single_parent_household", "youth_not_in_school", "sex_pay_inequity", "race_pay_inequity", "house_pay_inequity",
    "snap_household", "snap_vulnerabe_household", "no_internet_household", 
    "no_broadband_internet_household", "no_smartphone_household", "no_car_household", "no_plumbing_household", 
    "no_kitchen_household", "over_60min_commute", "wfh", "public_transit_commute", 
    "walking_commute", "biking_commute", "rural_household",
    "working_class_workers", "unemployment_rate", "renter_occupied", "median_income",
]

function wrangle(df)
    """
    function to fix data, orient data, and synthsize features for modeling (census data).
    """
    for name in vars
        df[!, name] = [fix(e) for e in df[!, name]]
    end

    df[:, "single_parent_household"] = (df[:, "B11005_006E"] .+ df[:, "B11005_007E"] .+ df[:, "B11005_008E"]) ./ df[:, "B11005_002E"]
    df[:, "youth_not_in_school"] = (df[:, "B14005_012E"] .+ df[:, "B14005_026E"]) ./ df[:, "B14005_001E"]

    df[:, "sex_pay_inequity"] = df[:, "B20001_002E"] ./ df[:, "B20001_023E"]
    df[:, "race_pay_inequity"] = df[:, "B20017A_001E"] ./ df[:, "B20017B_001E"]
    df[:, "house_pay_inequity"] = df[:, "B25077_001E"] ./ df[:, "B19013_001E"]
 
    df[:, "snap_household"] = df[:, "B22002_002E"] ./ df[:, "B22002_001E"]
    df[:, "snap_vulnerabe_household"] = (df[:, "B22002_003E"] .+ df[:, "B22001_003E"]) ./ df[:, "B22002_001E"]
 
    df[:, "no_internet_household"] = df[:, "B28002_013E"] ./ df[:, "B22002_001E"]
    df[:, "no_broadband_internet_household"] = 1 .- df[:, "B28002_004E"] ./ df[:, "B22002_001E"]
    df[:, "no_smartphone_household"] = 1 .- df[:, "B28010_005E"] ./ df[:, "B22002_001E"]

    df[:, "no_car_household"] = df[:, "DP04_0058E"] ./ df[:, "B22002_001E"]
    df[:, "no_plumbing_household"] = df[:, "DP04_0073PE"] ./ df[:, "B22002_001E"]
    df[:, "no_kitchen_household"] = df[:, "DP04_0074E"] ./ df[:, "B22002_001E"]

    df[:, "over_60min_commute"] = df[:, "S0801_C01_045E"]
    df[:, "wfh"] = df[:, "S0801_C01_013E"]
    df[:, "public_transit_commute"] = df[:, "S0801_C01_009E"]
    df[:, "walking_commute"] = df[:, "S0801_C01_010E"]
    df[:, "biking_commute"] = df[:, "S0801_C01_011E"]

    df[:, "rural_household"] = df[:, "H2_003N"] ./ df[:, "H2_001N"]

    df[:, "working_class_workers"] = 1 .- df[:, "C24060_002E"] ./ df[:, "C24060_001E"]
    df[:, "unemployment_rate"] = df[:, "S2301_C04_001E"]
    df[:, "renter_occupied"] = 1 .- df[:, "DP04_0046PE"]

    df[:, "median_income"] = df[:, "B25077_001E"]

    return df[:, ovars]
end;

# load data sets
df_county = DataFrame(CSV.File("raw_data/census/census_data_county_raw.csv"));
df_zcta = DataFrame(CSV.File("raw_data/census/census_data_zcta_raw.csv"));
df_tract = DataFrame(CSV.File("raw_data/census/census_data_tract_raw.csv"));

# wrangle data sets
df_county = wrangle(df_county);
df_zcta = wrangle(df_zcta);
df_tract = wrangle(df_tract);

# convet ucgid to Int
df_county[:, "COUNTY"] = [parse(Int, String(split(v, "US")[2])) for v in df_county[:, "ucgid"]];
df_zcta[:, "ZIP"] = [parse(Int, String(split(v, "US")[2])) for v in df_zcta[:, "ucgid"]];
df_tract[:, "TRACT"] = [parse(Int, String(split(v, "US")[2])) for v in df_tract[:, "ucgid"]];

# drop ucgid
select!(df_county, Not("ucgid"));
select!(df_zcta, Not("ucgid"));
select!(df_tract, Not("ucgid"));

# save results
CSV.write("derived_data/county/census.csv", df_county);
CSV.write("derived_data/zcta/census.csv", df_zcta);
CSV.write("derived_data/tract/census.csv", df_tract);
