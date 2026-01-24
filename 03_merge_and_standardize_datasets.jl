using CSV
using DataFrames

function merge(dfs, merge_col)
    """
    function to merge array of DataFrames on specific merge column.
    """
    df = dfs[1]
    for next_df in dfs[2:end]
        leftjoin!(df, next_df, on=merge_col)
    end

    for e in names(df)
        replace!(df[!, e], missing=>NaN)
    end

    return df
end

cols2inv = [
    "wfh", "public_transit_commute", "walking_commute", "biking_commute",
    "median_income"
]

function orient(df)
    """
    function to flip a subset of meaures to align inequity.
    """
    for col in cols2inv
        df[!, "$(col)_inv"] = -1 .* df[:, col]
    end
    return df
end

cols = [
    #"single_parent_household", "youth_not_in_school", "sex_pay_inequity", "race_pay_inequity", "house_pay_inequity",
    #"snap_household", "snap_vulnerabe_household", "no_internet_household", 
    #"no_broadband_internet_household", "no_smartphone_household", "no_car_household", "no_plumbing_household", 
    #"no_kitchen_household", "over_60min_commute", "wfh_inv", "public_transit_commute_inv", 
    #"walking_commute_inv", "biking_commute_inv", "rural_household",
    #"working_class_workers", "unemployment_rate", "renter_occupied", "median_income_inv",
    "single_parent_household", "youth_not_in_school", "sex_pay_inequity", "race_pay_inequity",
    "snap_household", "snap_vulnerabe_household", "no_internet_household", 
    "no_smartphone_household", "no_car_household", "no_plumbing_household", 
    "over_60min_commute", "wfh_inv", "biking_commute_inv",
    "working_class_workers", "unemployment_rate", "renter_occupied", "median_income_inv",

    #"Total Offenses Rate", "Crimes Against Persons Rate", "Crimes Against Property Rate", "Crimes Against Society Rate",
    "Crimes Against Persons Rate", "Crimes Against Property Rate", "Crimes Against Society Rate",

    #"ALR_VALB", "ALR_VALP", "ALR_VALA", 
    "ALR_VALB", "ALR_VALP", 

    #"lahunv1share", "lahunv10share", "lasnap1share", "lasnap10share"
    "lahunv1share", "lasnap1share"
];

function ntile(s)
    """
    fucntion to convert the meaures to "percentiles."
    """
    x = sort(s)

    i = 0
    v_i = x[1]
 
    d = Dict([(v_i, 0.0)])

    for v in x[2:end]
        if v != v_i
            d[v] = i
        end
        i += 1
        v_i = v
    end

    n = maximum(values(d))

    return [d[v] / n for v in s]
end;


function get_ntiles(df)
    """
    function to convert relavent columns to "percentiles."
    """
    for col in cols
        m = .!isnan.(df[:, col])
        df[m, col] = ntile(df[m, col])
    end
 
    return df
end;


# load data sets
dfs_county = [
    DataFrame(CSV.File("derived_data/county/census.csv")),
    DataFrame(CSV.File("derived_data/county/fbi_cde.csv")),
    DataFrame(CSV.File("derived_data/county/fema_eal.csv")),
    DataFrame(CSV.File("derived_data/county/usda_food_insecure.csv")),
];

dfs_zcta = [
    DataFrame(CSV.File("derived_data/zcta/census.csv")),
    DataFrame(CSV.File("derived_data/zcta/fbi_cde.csv")),
    DataFrame(CSV.File("derived_data/zcta/fema_eal.csv")),
    DataFrame(CSV.File("derived_data/zcta/usda_food_insecure.csv")),
];

dfs_tract = [
    DataFrame(CSV.File("derived_data/tract/census.csv")),
    DataFrame(CSV.File("derived_data/tract/fbi_cde.csv")),
    DataFrame(CSV.File("derived_data/tract/fema_eal.csv")),
    DataFrame(CSV.File("derived_data/tract/usda_food_insecure.csv")),
];

# drop extra fields
select!(dfs_county[2], Not(["STATE", "COUNTYNAME"]))
select!(dfs_county[3], Not(["STATE", "COUNTYNAME"]))

# combine data sets
df_county = merge(dfs_county, :COUNTY)
df_zcta = merge(dfs_zcta, :ZIP);
df_tract = merge(dfs_tract, :TRACT);

# parse income and float
df_county[!,"median_income"] = convert.(Float64,df_county[!,"median_income"]);
df_zcta[!,"median_income"] = convert.(Float64,df_zcta[!,"median_income"]);
df_tract[!,"median_income"] = convert.(Float64,df_tract[!,"median_income"]);

# align data
df_county = orient(df_county);
df_zcta = orient(df_zcta);
df_tract = orient(df_tract);

# standaridize data
df_county = get_ntiles(df_county);
df_zcta = get_ntiles(df_zcta);
df_tract = get_ntiles(df_tract);

# filter
df_county = df_county[:, ["COUNTY"; cols]];
df_zcta = df_zcta[:, ["ZIP"; cols]];
df_tract = df_tract[:, ["TRACT"; cols]];

mkpath("datasets")

CSV.write("datasets/county_dataset.csv", df_county);
CSV.write("datasets/zcta_dataset.csv", df_zcta);
CSV.write("datasets/tract_dataset.csv", df_tract);
