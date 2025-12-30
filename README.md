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

We want an interpretable index. Data consistently oriented low deprivation to high deprivation make for a more interpretable index (NDI). The primary component should be Non-Negative and subsequent components should also be regularized. 

If subsequent components are constrained to be non-negative, then the primary component would act as a lower bound. Without the non-negative constraint, these components can describe deviations from the primary component, and reduce the effect of outliers. These components are also regularized.
