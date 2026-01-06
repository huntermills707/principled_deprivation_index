using CSV, DataFrames
using LinearAlgebra, Random, Statistics
using Convex, SCS

function get_nfa(A, M)
    (n, m) = size(A);

    corr = zeros(m,m);
    for i in 1:m
        for j in i:m
            mask = (M[:,i] .+ M[:,j]) .== 0;
            x = cor(Vector(df[mask ,cols[1+i]]), Vector(df[mask ,cols[1+j]]));
            corr[i, j] = x;
            corr[j, i] = x;
        end
    end

    eigs = eigvals(corr);
    nfa = sum(eigs .> 1);
    return nfa;
end


function opt_Y(A, H, X_0, Y_0, k, m, residual, i)

    Y = Variable((k,m))
    set_value!(Y, Y_0)
    X = X_0

    constraint = [Y[1,:] >= 0]

    obj = sum(huber(A - X*Y.*H, .4)) + 12 * norm(Y[2:k,:], 1) + 6 * norm(Y[2:k,:], 2)

    p = minimize(obj, constraint)
    solve!(p, SCS.Optimizer; silent = false)

    if p.status != Convex.MOI.OPTIMAL
        println("Failed to Converge")
    end

    Y_0 = Y.value

    residual[i] = p.optval
    println("$i, $(residual[i])")

    return Y_0, residual
end


function opt_X(A, H, X_0, Y_0, i, dim, k, residual, i)

    X = Variable((dim, k))
    set_value!(X, X_0[j:j+dim-1, :])
    Y = Y_0

    constraint = [X[:,1] >= 0, opnorm(X, Inf) <= 1]

    obj = sum(huber(A[j:j+dim-1, :] - X*Y.*H[j:j+dim-1, :], .4))

    p = minimize(obj, constraint)
    solve!(p, SCS.Optimizer; silent = false)

    if p.status != Convex.MOI.OPTIMAL
        println("Failed to Converge")
    end

    residual[i] += p.optval

    X_0[j:j+dim-1, :] = X.value

    return X_0, residual
end


function train(A, M; Y_prev_fp="")

    (n, m) = size(A);

    k = get_nfa(A)

    MAX_ITERS = 20 
    residual = zeros(MAX_ITERS);
    rng = Xoshiro(42)

    X_0 = rand(rng, Float64,(n, k));
    X_0 = X_0 ./ (X_0 * ones(k, 1))

    Y_0 = rand(rng, Float64,(k, m));

    if Y_prev_fp != ""
        df_Y = DataFrame(CSV.File(Y_prev_fp))
        k_init = minimum([size(df_Y)[1], k])
        Y_prev = Matrix(df_Y)[1:k_init, :];
        Y_0[1:k_init, :] = Y_prev
    end
 
    H = ones((n, m))
    p = 0
    constraint = []

    A[M] .= 0
    H[M] .= 0

    step = 3500

    for i = 1:MAX_ITERS
        if (i % 2) == 0
            Y_0, residual = opt_Y(A, H, X_0, Y_0, k, m, residual, i)

        else
            for j in 1:step:n
                if j + step > n
                    dim = n - j + 1
                else
                    dim = step
                end
                X_0, residual = opt_X(A, H, X_0, Y_0, j, dim, k, residual, i)
            end
            println("$i, $(residual[i])")
        end
    end

    println()

    w = mean(abs.(X_0), dims=1) .* mean(abs.(Y_0), dims=2)'
    w = w ./ sum(w)
    println(w)

    return X_0, Y_0
end
