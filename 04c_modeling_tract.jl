using CSV
using model_training.jl

fname = "datasets/tract_dataset.csv"
df = DataFrame(CSV.File(fname));

cols = names(df)
for col in cols
    m = .!isnan.(df[:,col])
    println("$(col) $(sum(.!m))")
end

(n, m) = size(df[!, cols[2:end]])

A = Matrix(df[:, cols[2:end]])
M = isnan.(A)

X, Y = train(A, M; Y_prev_fp="weights/county_Y.csv")

df_Y = DataFrame(Y_0, cols[2:end])
fname = "weights/tract_Y.csv"
CSV.write(fname, df_Y)

df_X = df[:, ["TRACT"]]
for i in 1:k
    df_X[:, "$i"] = X_0[:, i]
end

fname = "weights/tract_X.csv"
CSV.write(fname, df_X)
