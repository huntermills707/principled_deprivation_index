using CSV
using DataFrames
using XLSX
using Statistics

geog = CSV.read("derived_data/geography.csv", DataFrame)

df_state = CSV.read(
    "raw_data/states_fips.csv",
    DataFrame;
    delim = ", ",
    ignoreemptyrows = true,
)

ffill(v) = v[accumulate(max, [i*!ismissing(v[i]) for i in 1:length(v)], init=1)]

dfs = DataFrame[]   # empty vector to collect DataFrames

for row in eachrow(df_state)
    state = row[1]      # state name
    fips  = row[2]      # numeric FIPS
    abv   = row[3]      # abbreviation

    println(state)

    fname = joinpath(
        "raw_data/fbi_cde/stateTables_2023",
        replace(state, " " => "_") * "_Offense_Type_by_Agency_2023.xlsx"
    )

    # Load the sheet, skip the first 5 rows and the last 2 rows
    raw = XLSX.readtable(fname, 1; first_row=6, header=false) |> DataFrame
    df_crime = raw[:, 1:7]

    rename!(df_crime, Dict(
        :A => :AGENCY,
        :B => :LOCATION,
        :C => :POPULATION,
        :D => Symbol("Total Offenses"),
        :E => Symbol("Crimes Against Persons"),
        :F => Symbol("Crimes Against Property"),
        :G => Symbol("Crimes Against Society")
    ))

    m = .!ismissing.(df_crime[:, :LOCATION])
    df_crime = df_crime[m, :]
    df_crime.AGENCY = ffill(df_crime.AGENCY)

    df_crime[!, :STATENAME] .= state
    df_crime[!, :STATE] .= fips
    df_crime[!, :STATEABV] .= abv
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

city2county = unique(geog[:, [:CITYNAME, :COUNTYNAME, :STATEABV, :COUNTY]])

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
leftjoin!(df_crime, diffs_df, on = [:STATEABV, :LOCATION])
replace!(df_crime.diff, missing=>0.0)

df_pop = CSV.read("raw_data/census/census_data_county_raw.csv", DataFrame)[!, [:ucgid, :B01001_001E]]
df_pop[!, :COUNTY] = parse.(Int, replace.(df_pop.ucgid, r"500000US" => ""))

# Join with city‑to‑county mapping to get STATEABV for each COUNTY
df_pop = innerjoin(
    select(city2county, [:COUNTY, :COUNTYNAME, :STATEABV]),
    df_pop,
    on = :COUNTY
)

rename!(df_pop, Dict(
    :B01001_001E => :COUNTYPOP,
    :COUNTYNAME   => :LOCATION
))
df_pop[!, :LOCATION] = lowercase.(df_pop.LOCATION)
unique!(df_pop)

df_crime = leftjoin(df_crime, df_pop, on = [:LOCATION, :STATEABV])
df_crime[!, :POP_EST] = df_crime.COUNTYPOP .- df_crime.diff

# Replace non‑positive estimates with missing
m = ismissing.(df_crime.POP_EST) .| (df_crime.POP_EST .<= 0)
df_crime[m, :POP_EST] .= missing

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
dropmissing!(crime_data)

# Keep first occurrence for duplicate tract/zip/county combos
crime_data = unique(crime_data, [:TRACT, :ZIP, :COUNTY]; keep=:first)

crime_data_zcta = unique(
    select(crime_data,
        [:ZIP,
         Symbol("Total Offenses Rate"),
         Symbol("Crimes Against Persons Rate"),
         Symbol("Crimes Against Property Rate"),
         Symbol("Crimes Against Society Rate")]
    ),
    :ZIP; keep=:first
)

grouped = groupby(crime_data, :TRACT)
tract_rows = DataFrame(
    :TRACT => Int[],
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

unique!(crime_data, [:STATE, :COUNTY, :COUNTYNAME, rate_cols...])

grouped = groupby(crime_data, [:STATE, :COUNTY, :COUNTYNAME])
county_rows = DataFrame(
    :STATE => Int[],
    :COUNTY => Int[],
    :COUNTYNAME => String[],
    Symbol("Total Offenses") => Int[],
    Symbol("Crimes Against Persons") => Int[],
    Symbol("Crimes Against Property") => Int[],
    Symbol("Crimes Against Society") => Int[]
)

for g in grouped
    sub = dropmissing(g)
    if size(sub)[1] > 0
    push!(county_rows, (
        first(sub.STATE),
        first(sub.COUNTY),
        first(sub.COUNTYNAME),
        sum(sub[!, Symbol("Total Offenses")]),
        sum(sub[!, Symbol("Crimes Against Persons")]),
        sum(sub[!, Symbol("Crimes Against Property")]),
        sum(sub[!, Symbol("Crimes Against Society")])
    ))
  end
end

crime_data_county = county_rows

crime_data_county = innerjoin(crime_data_county, df_pop[:, [:COUNTY, :COUNTYPOP]], on=:COUNTY)

unique!(crime_data_county)

# Compute rates
for col in [Symbol("Total Offenses"), Symbol("Crimes Against Persons"),
            Symbol("Crimes Against Property"), Symbol("Crimes Against Society")]
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
