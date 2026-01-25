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

The following open data sources were used to train and validate the principled deprivation index.

### Training

* US Census (https://data.census.gov/)
* FBI Crime Data Explorer, NIBRS data by state and year (https://cde.ucr.cjis.gov/LATEST/webapp/#/pages/downloads#nibrs-downloads)
* FEMA Expected Annual Loss (https://www.fema.gov/about/openfema/data-sets/national-risk-index-data)
* USDA Food Access Research Atlas (https://www.ers.usda.gov/data-products/food-access-research-atlas/download-the-data)
* US Department of Housing and Urban Development (https://www.huduser.gov/portal/datasets/usps_crosswalk.html)

### Testing

* CDC Places (https://data.cdc.gov/browse?category=500+Cities+%26+Places&q=2024&sortBy=relevance&tags=places&pageSize=20)

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

## Open Data Remixing.
To the best of my understanding, the data shared here is allowed to be reposted and remixed.
* US Census (https://www.census.gov/about/policies/open-gov/open-data.html)
* FBI Crime Data Explorer, NIBRS data by state and year (https://cde.ucr.cjis.gov/LATEST/webapp/#/pages/about)
* FEMA Expected Annual Loss (https://www.fema.gov/about/openfema/terms-conditions)
* USDA Food Access Research Atlas (https://www.usda.gov/about-usda/policies-and-links/open-government-usda)
* US Department of Housing and Urban Development (https://data.hud.gov/open_data)
* CDC Places (https://www.cdc.gov/places/faqs/index.html)
