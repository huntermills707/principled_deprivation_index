using CSV
include("model_training.jl")

# load data set
fname = "datasets/county_dataset.csv"
df = DataFrame(CSV.File(fname));

# check missingness
cols = names(df)
for col in cols
    m = .!isnan.(df[:,col])
    println("$(col) $(sum(.!m))")
end

# convert to Matrix, calculate missing mask, and run
(n, m) = size(df[!, cols[2:end]])

A = Matrix(df[:, cols[2:end]])
M = isnan.(A)

X, Y, k = train(A, M)

# convert to DataFrames and save
df_Y = DataFrame(Y, cols[2:end])
fname = "weights/county_Y.csv"
CSV.write(fname, df_Y)

df_X = df[:, ["COUNTY"]]
for i in 1:k
    df_X[:, "$i"] = X[:, i]
end

fname = "weights/county_X.csv"
CSV.write(fname, df_X)
