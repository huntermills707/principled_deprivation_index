using CSV
using DataFrames
using DataStructures: OrderedDict
using HTTP
using JSON3

include("census_vars.jl");
include("secrets.jl");

ENV["census_key"] = census_key;

function format_ucgid(;agg="tract", state="", comp="Not a geographic component")
    """
    Function to get US Census query string.

    # Arguments
    - `agg::string`: How to agg geo data. EX: tract, county, ...
    - `state::string`: What state to query. If empty string of default value, query all states.
    - `comp::string`: What US Census component
    # Returns
    - `out::string`: US Census query string.
    """
    if state != ""
        return "pseudo(04000$(geographic_components[comp])US$(states[state])\$$(geographies[agg])0000)"
    end
    return "pseudo(01000$(geographic_components[comp])US\$$(geographies[agg])0000)"
end


function query_census(surv, var; agg="county", state="")
    """
    funtion to query US Census from a specified aggregated survey variable.

    # Arguments
    - `surv::string`: US Census survey
    - `var::string`: US Census survey variable. 
    - `agg::string`: How to agg geo data. EX: tract, county, ...
    - `state::sring`: What state to query. If empty string of default value, query all states.

    # Returns
    - `df::DataFrame`: Dataframe of query results.
    """
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


function pull(group)
    """
    Function to pull all US Census variables defined in census_vars.jl.
    Pulls both from ACS5 and DHC (for rurality).

    # Arguments
    - `group::string`: What group to pull (EX: tract, county, ...)

    # Returns
    - `df::DataFrame`: DataFrame of results. Each column is a varaible, and each row is a location.
    """
    dfs = [
        [query_census(surv_acs, var, agg=group)[!, ["ucgid", "NAME", var]] for (_, var) in vars_acs];
        [query_census(surv_dec, var, agg=group)[!, ["ucgid", "NAME", var]] for (_, var) in vars_dec]
    ]

    df = dfs[1]
    for next_df in dfs[2:end]
        leftjoin!(df, next_df, on=["NAME", "ucgid"])
    end

    return df
end

# Pull census data
df = pull("county")
fname = "raw_data/census/census_data_county_raw.csv"
CSV.write(fname, df)

df = pull("zip code tabulation area")
fname = "raw_data/census/census_data_zcta_raw.csv"
CSV.write(fname, df)

df = pull("tract")
fname = "raw_data/census/census_data_tract_raw.csv"
CSV.write(fname, df)
