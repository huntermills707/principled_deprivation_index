using CSV
using DataFrames
using XLSX
using Statistics

geog = CSV.read("derived_data/geography.csv", DataFrame)

df_state = CSV.read(
    "raw_data/states_fips.csv",
    DataFrame;
    delim = ", ",
    ignoreemptylines = true,

)

dfs = DataFrame[]   # empty vector to collect DataFrames

for row in eachrow(df_state)
    state = row[1]      # state name
    fips  = row[2]      # numeric FIPS
    abv   = row[3]      # abbreviation

    # Build the path – replace spaces with '_' like the Python code
    fname = joinpath(
        "raw_data/fbi_cde/stateTables",
        replace(state, " " => "_") * "_Offense_Type_by_Agency_2023.xlsx"
    )

    # Load the sheet, skip the first 5 rows and the last 2 rows
    # XLSX.readtable returns a DataFrame; we slice columns 1:7 (Julia is 1‑based)
    raw = XLSX.readtable(fname, "Sheet1"; range = "A6:G$(XLSX.nrows(fname)-2)") |> DataFrame
    df_crime = raw[:, 1:7]   # keep only first 7 columns

    rename!(df_crime, Dict(
        1 => :AGENCY,
        2 => :LOCATION,
        3 => :POPULATION,
        4 => Symbol("Total Offenses"),
        5 => Symbol("Crimes Against Persons"),
        6 => Symbol("Crimes Against Property"),
        7 => Symbol("Crimes Against Society")
    ))

    # Forward‑fill AGENCY (equivalent to ffill)
    df_crime.AGENCY = coalesce.(df_crime.AGENCY, forwardfill(df_crime.AGENCY))

    df_crime[!, :STATENAME] = state
    df_crime[!, :STATE]     = fips
    df_crime[!, :STATEABV]  = abv
    df_crime[!, :LOCATION] = lowercase.(df_crime.LOCATION)

    push!(dfs, df_crime)
end

# Concatenate all state tables
df_crime = vcat(dfs...)

# Keep only city‑level and county‑level agencies
filter!(row -> row.AGENCY in ["Cities", "Metropolitan Counties", "Nonmetropolitan Counties"],
        df_crime)

# City‑level populations
crime_cities = Dict{Tuple{String,String}, Float64}()
for row in eachrow(filter(:AGENCY => ==("Cities"), df_crime))
    key = (row.STATEABV, row.LOCATION)
    crime_cities[key] = row.POPULATION
end

# County identifiers (set of (state, location) tuples)
crime_counties = Set{Tuple{String,String}}()
for row in eachrow(filter(:AGENCY => in(["Metropolitan Counties","Nonmetropolitan Counties"]), df_crime))
    push!(crime_counties, (row.STATEABV, row.LOCATION))
end

city2county = unique(select(geog, [:CITYNAME, :COUNTYNAME, :STATEABV, :COUNTY]))

diffs = Dict{Tuple{String,String}, Float64}()

for row in eachrow(city2county[:, [:CITYNAME, :COUNTYNAME, :STATEABV]])
    city   = lowercase(row.CITYNAME)
    county = row.COUNTYNAME
    state  = row.STATEABV

    if haskey(crime_cities, (state, city))
        diffs[(state, county)] = get(diffs, (state, county), 0.0) +
                                 crime_cities[(state, city)]
    end
end

# Convert diffs dict to DataFrame
diffs_df = DataFrame(
    STATEABV = String[],
    LOCATION = String[],
    diff     = Float64[]
)

for ((st, cnty), d) in diffs
    push!(diffs_df, (st, lowercase(cnty), d))
end

# Merge diffs back onto the main crime table
df_crime = leftjoin(df_crime, diffs_df, on = [:STATEABV, :LOCATION])
replace!(df_crime.diff, missing=>0.0)

df_pop = CSV.read("raw_data/census/census_data_county_raw.csv", DataFrame)[!, [:ucgid, :B01001_001E]]
df_pop[!, :COUNTY] = parse.(Int, replace.(df_pop.ucgid, r"^US" => ""))

# Join with city‑to‑county mapping to get STATEABV for each COUNTY
df_pop = leftjoin(
    select(city2county, [:COUNTY, :COUNTYNAME, :STATEABV]),
    df_pop,
    on = :COUNTY
)

rename!(df_pop, Dict(
    :B01001_001E => :COUNTYPOP,
    :COUNTYNAME   => :LOCATION
))
df_pop[!, :LOCATION] = lowercase.(df_pop.LOCATION)
unique!(df_pop)   # drop duplicates just in case

df_crime = leftjoin(df_crime, df_pop, on = [:LOCATION, :STATEABV])
df_crime[!, :POP_EST] = df_crime.COUNTYPOP .- df_crime.diff

# Replace non‑positive estimates with missing
df_crime.POP_EST .= ifelse.(df_crime.POP_EST .<= 0, missing, df_crime.POP_EST)

# Fill original POPULATION where missing with POP_EST
df_crime[!, :POPULATION] = coalesce.(df_crime.POPULATION, df_crime.POP_EST)

rate_cols = [
    Symbol("Total Offenses"),
    Symbol("Crimes Against Persons"),
    Symbol("Crimes Against Property"),
    Symbol("Crimes Against Society")
]

for col in rate_cols
    rate_name = Symbol(string(col), " Rate")
    df_crime[!, rate_name] = df_crime[!, col] ./ df_crime.POPULATION
end

select_cols = [
    :AGENCY, :LOCATION,
    Symbol("Total Offenses"), Symbol("Crimes Against Persons"),
    Symbol("Crimes Against Property"), Symbol("Crimes Against Society"),
    :POPULATION,
    Symbol("Total Offenses Rate"), Symbol("Crimes Against Persons Rate"),
    Symbol("Crimes Against Property Rate"), Symbol("Crimes Against Society Rate"),
    :STATENAME, :STATE, :STATEABV
]

df_crime = df_crime[:, select_cols]

cols_for_merge = [
    :STATE, :LOCATION, :POPULATION,
    Symbol("Total Offenses"), Symbol("Crimes Against Persons"),
    Symbol("Crimes Against Property"), Symbol("Crimes Against Society"),
    Symbol("Total Offenses Rate"), Symbol("Crimes Against Persons Rate"),
    Symbol("Crimes Against Property Rate"), Symbol("Crimes Against Society Rate")
]

city_mask = df_crime.AGENCY .== "Cities"

crime_data = vcat(
    leftjoin(
        geog,
        df_crime[city_mask, cols_for_merge],
        on = [:STATE => :STATE, :CITYNAME => :LOCATION]
    ),
    leftjoin(
        geog,
        df_crime[.!city_mask, cols_for_merge],
        on = [:STATE => :STATE, :COUNTYNAME => :LOCATION]
    )
)

# Drop rows with any missing key fields
dropmissing!(crime_data, [:TRACT, :ZIP, :COUNTY])

# Keep first occurrence for duplicate tract/zip/county combos
crime_data = unique(crime_data, [:TRACT, :ZIP, :COUNTY]; keepfirst = true)

crime_data_zcta = unique(
    select(crime_data,
        [:ZIP,
         Symbol("Total Offenses Rate"),
         Symbol("Crimes Against Persons Rate"),
         Symbol("Crimes Against Property Rate"),
         Symbol("Crimes Against Society Rate")]
    ),
    :ZIP; keepfirst = true
)

grouped = groupby(crime_data, :TRACT)
tract_rows = DataFrame(
    TRACT = String[],
    Symbol("Total Offenses Rate") => Float64[],
    Symbol("Crimes Against Persons Rate") => Float64[],
    Symbol("Crimes Against Property Rate") => Float64[],
    Symbol("Crimes Against Society Rate") => Float64[]
)

for g in grouped
    sub = dropmissing(g)
    den = sum(sub.TZ_RATIO)
    if den > 0
        push!(tract_rows, (
            first(sub.TRACT),
            sum(sub[!, Symbol("Total Offenses Rate")] .* sub.TZ_RATIO) / den,
            sum(sub[!, Symbol("Crimes Against Persons Rate")] .* sub.TZ_RATIO) / den,
            sum(sub[!, Symbol("Crimes Against Property Rate")] .* sub.TZ_RATIO) / den,
            sum(sub[!, Symbol("Crimes Against Society Rate")] .* sub.TZ_RATIO) / den
        ))
    end
end

crime_data_tract = tract_rows

county_cols = [
    :STATE, :COUNTY, :COUNTYNAME,
    Symbol("Total Offenses"),
    Symbol("Crimes Against Persons"),
    Symbol("Crimes Against Property"),
    Symbol("Crimes Against Society")
]

crime_data_county = combine(
    groupby(select(crime_data, county_cols), [:STATE, :COUNTY, :COUNTYNAME]),
    names(county_cols, r"^") .=> sum .=> names(county_cols, r"$")
)

# Merge with county population
crime_data_county = leftjoin(
    crime_data_county,
    select(df_pop, [:COUNTY, :COUNTYPOP]),
    on = :COUNTY
)

# Compute rates
for col in [:Total_Offenses, :Crimes_Against_Persons,
            :Crimes_Against_Property, :Crimes_Against_Society]
    rate_name = Symbol(string(col), " Rate")
    crime_data_county[!, rate_name] = crime_data_county[!, col] ./ crime_data_county.COUNTYPOP
end

# Keep final columns and drop rows with missing values
final_cnty_cols = [
    :STATE, :COUNTY, :COUNTYNAME,
    Symbol("Total Offenses Rate"),
    Symbol("Crimes Against Persons Rate"),
    Symbol("Crimes Against Property Rate"),
    Symbol("Crimes Against Society Rate")
]

crime_data_county = dropmissing(select(crime_data_county, final_cnty_cols))

CSV.write("derived_data/county/fbi_cde.csv", crime_data_county)
CSV.write("derived_data/zcta/fbi_cde.csv", crime_data_zcta)
CSV.write("derived_data/tract/fbi_cde.csv", crime_data_tract)
