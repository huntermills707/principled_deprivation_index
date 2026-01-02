using CSV
using DataFrames
using DataStructures: OrderedDict
using HTTP
using JSON3

include("census_vars.jl");
include("secrets.jl");

ENV["census_key"] = census_key;

function format_ucgid(;agg="tract", state="", comp="Not a geographic component")
    if state != ""
        return "pseudo(04000$(geographic_components[comp])US$(states[state])\$$(geographies[agg])0000)"
    end
    return "pseudo(01000$(geographic_components[comp])US\$$(geographies[agg])0000)"
end

function query_census(surv, var; agg="county", state="")
    if var[1] == 'D'
        url = "https://api.census.gov/data/$surv/profile"
    elseif var[1] == 'S'
        url = "https://api.census.gov/data/$surv/subject"
    else
        url = "https://api.census.gov/data/$surv"
    end
    
    ucgid = format_ucgid(agg=agg, state=state)
    query = Dict([
        ("key", ENV["census_key"]),
        ("get", join(("NAME", var), ",")),
        ("ucgid", ucgid)
    ])

    println(var)
    println(url)
    println(query)
    println()
    
    r = HTTP.get(
        url;
        query = query
    )
    
    body = JSON3.read(r.body)
    header, data = body[1], body[2:end]
    
    df = OrderedDict{Symbol, Vector}()
    for (i, col_name) in enumerate(header)
        df[Symbol(col_name)] = [row[i] for row in data]
    end

    sleep(5)
    
    return DataFrame(df);
end

surv_dec = "2020/dec/dhc"
vars_dec = [
    # rurality
    "Rural" => "H2_003N"
    "Urban" => "H2_002N"
    "Urban + Rural" => "H2_001N"
]

surv_acs = "2023/acs/acs5"
vars_acs = [
    "TotalPopulation" => "B01001_001E"
    
    # Single-Parent Households
    "Male led Household with childeren" => "B11005_006E"
    "Female led Household with childeren" => "B11005_007E"
    # Nonfamilty household with child
    "NonFamily Household with childeren" => "B11005_008E"
    "Households with childeren" => "B11005_002E"

    # youth not in school
    "Male 16-19 no HS" => "B14005_012E"
    "Female 16-19 no HS" => "B14005_026E"
    "Female + Male 16-19" => "B14005_001E"

    # Pay Gap Sex
    "Male median earnings" => "B20001_002E"
    "Female median earnings" => "B20001_023E"

    # Pay Gap Race
    "White median earnings" => "B20017A_001E"
    "Black median earnings" => "B20017B_001E"

    # Housing Gap
    "Median House Price" => "B19013_001E"
    "Median Salary" => "B25077_001E"

    "Unemployment Rate" => "S2301_C04_001E"
    "Owner Occupied Housing" => "DP04_0046PE"

    #white collar jobs
    "White collar workers" => "C24060_002E"
    "Total workers" => "C24060_001E"

    # SNAP
    "Total Households" => "B22002_001E"
    "Total Households w/ SNAP" => "B22002_002E"
    "Total Households w/ SNAP + childeren" => "B22002_003E"
    "Total Households w/ SNAP + elders" => "B22001_003E"

    #tech
    "Households w/o Internet" => "B28002_013E"
    "Households w/ Broadband Internet" => "B28002_004E"
    "Households w/ Smartphone" => "B28010_005E"

    # char
    "Households w/o Car" => "DP04_0058E"
    "Households w/o Complete Plumbing" => "DP04_0073PE"
    "Households w/o Complete Kitchen" => "DP04_0074E"
    
    # transport
    "Over 60 min commuting" => "S0801_C01_045E"
    "WFH" => "S0801_C01_013E"
    "Public Transit to Work" => "S0801_C01_009E"
    "Walked to Work" => "S0801_C01_010E"
    "Biked to Work" => "S0801_C01_011E"
    "Total Workers" => "S0801_C01_001E"
];

# US Census County
dfs = [
    [query_census(surv_acs, var, agg="county")[!, ["ucgid", "NAME", var]] for (_, var) in vars_acs];
    [query_census(surv_dec, var, agg="county")[!, ["ucgid", "NAME", var]] for (_, var) in vars_dec]
]

df = dfs[1]
for next_df in dfs[2:end]
    leftjoin!(df, next_df, on=["NAME", "ucgid"])
end

fname = "raw_data/census/census_data_county_raw.csv"
CSV.write(fname, df)

# US Census D ZCTA
dfs = [
    [query_census(surv_acs, var, agg="zip code tabulation area")[!, ["ucgid", "NAME", var]] for (_, var) in vars_acs];
    [query_census(surv_dec, var, agg="zip code tabulation area")[!, ["ucgid", "NAME", var]] for (_, var) in vars_dec]
]

df = dfs[1]
for next_df in dfs[2:end]
    leftjoin!(df, next_df, on=["NAME", "ucgid"])
end

fname = "raw_data/census/census_data_zcta_raw.csv"
CSV.write(fname, df)

# US Census TRACTS
dfs = [
    [query_census(surv_acs, var, agg="tract")[!, ["ucgid", "NAME", var]] for (_, var) in vars_acs];
    [query_census(surv_dec, var, agg="tract")[!, ["ucgid", "NAME", var]] for (_, var) in vars_dec]
]

df = dfs[1]
for next_df in dfs[2:end]
    leftjoin!(df, next_df, on=["NAME", "ucgid"])
end

fname = "raw_data/census/census_data_tract_raw.csv"
CSV.write(fname, df)
