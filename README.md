# principled_deprivation_index
## WIP
Using GLRM to calculate principled deprivation indexes using public data.

There are several social indexes that currently exist
* ADI: Area Deprivation Index
* NDI: Neighborhood Deprivation Index
* SVI: Social Vulnerability Index

Many use US census data, and utilize well known dimension reduction techniques.

However, there are potential issues here. 
* Missing Data: Many data reduction techniques require complete data, and the existing indexes use crude data imputation.
* Interpretability: Many techniques also transform the data in ways that obscure the underlying meaning.

Utilizing Generalized Low Rank Matrix (GLRM) approximations, can help mitigate these issues with principled mathematical modeling.

## Missing Data

GLRMs can natively handle missing data, and make approximations with the data available.
In areas of high missingness, it is most often the case that mean/median imputation falls short (yes--I need a citation)

## Interpretability

Many indexes utilize PCA (a great method), but PCA needs to be centered. So the resulting loadings are looking at deviations from the mean. In this regard, Non-Negative Matrix Factorization (NNMF) can make a lot of sense.

# Data Sources

* US Census
* FBI Crime Data Explorer
* FEMA Expected Annual Loss
* USDA Food Insecurity

# The Model 

We want an interpretable index. Data consistently oriented low deprivation to high deprivation make for a more interpretable index (NDI). The primary component should be Non-Negative and subsequent components should also be regularized. The representation of the primary component should also be non-negative.

If subsequent components are constrained to be non-negative, then the primary component would act as a lower bound. Without the non-negative constraint, these components can describe deviations from the primary component. These components are also regularized this pushes greater explain-ability to the primary component.

Data is also quantized. Absolute row sums of representations are limited to be at most one.

Huber function $(f_h)$ is used to further reduce effects of outliers.

Here is the model:

```math
\begin{equation*}
\begin{aligned}
    \min_{X,Y} \quad & \sum_{(i,j) \in \Omega} f_h \left(  A_{i,j} - \left( XY \right)_{i,j} \right)+ \gamma_1 \left\Vert Y_{2:k,:} \right\Vert_1 + \gamma_2 \left\Vert Y_{2:k,:} \right\Vert_2 \\
    s.t. \quad & X_{1,:} \geq 0 \\
    & Y_{1,:} \geq 0 \\
    & \max_{i} \sum_{j=1} \left|X_{i,j}\right| \leq 1 \\
\end{aligned}
\end{equation*}
```

Where

```math
\begin{equation*}
    f_h(x) = \begin{cases} 
      x^2 & |x| \leq c \\
      2c\cdot |x| - c^2 & |x| > c
   \end{cases}
\end{equation*}
```


