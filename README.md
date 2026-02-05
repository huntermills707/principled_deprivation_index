
# Principled Deprivation Index

A Julia-based pipeline for calculating a Principled Deprivation Index (PDI) using Generalized Low Rank Models (GLRM). The project aims to create an interpretable social index that natively handles missing data and reduces the influence of outliers, validated against public health outcomes.

## Overview

Existing social indices (e.g., ADI, NDI) often rely on PCA or similar techniques that struggle with missing data or produce "centered" results that obscure absolute deprivation levels. This project utilizes **Generalized Low Rank Models (GLRM)** to:

*   **Handle Missing Data**: GLRM approximates the data matrix only using available observations, avoiding crude mean/median imputation.
*   **Ensure Interpretability**: By enforcing non-negativity constraints on the primary latent factors, the index represents a "lower bound" of deprivation that is easy to interpret.
*   **Robustness**: Utilizes a Huber loss function to minimize the impact of outliers.

## Installation

This project requires **Julia**. To set up the environment, clone the repository and run the following commands in the Julia REPL:

```julia
using Pkg
Pkg.activate(".")        # Activate the project environment
Pkg.instantiate()       # Install dependencies listed in Project.toml
```

### Dependencies

Key packages used include `CSV`, `DataFrames`, `Convex`, `SCS` (for optimization), `Plots`, and `Impute`. See `Project.toml` for the full list.

## Project Workflow

The pipeline is numbered sequentially (01–05) to guide the user from data ingestion to validation.

### 1. Geography & Census Data
*   **`01a_geography.jl`**: Loads and merges geographical crosswalks (HUD, Census) to map Tracts, ZCTAs (ZIP codes), and Counties.
*   **`01b_census_pull.jl`**: Pulls raw US Census variables using the API (defined in `census_vars.jl`).

### 2. Feature Engineering
These scripts ingest and clean specific open data sources to generate feature sets for the model.
*   **`02a_fbi_cde.jl`**: Processes FBI Crime Data Explorer (NIBRS) to calculate crime rates by agency, aggregating up to County/ZCTA/Tract levels.
*   **`02b_fema_eal.jl`**: ingests FEMA Expected Annual Loss data for natural disaster risk.
*   **`02c_usda_food_insecure.jl`**: Processes USDA Food Access Research Atlas data.
*   **`02d_census_wrangle.jl`**: Cleans and synthesizes features from the raw Census pull.

### 3. Data Merging & Standardization
*   **`03_merge_and_standardize_datasets.jl`**: Merges all disparate sources (Crime, Risk, Food, Census) into unified datasets for County, ZCTA, and Tract levels. It standardizes variables (orienting them "low deprivation to high deprivation") and converts them to percentiles.

### 4. Modeling (GLRM)
*   **`04a_modeling_county.jl`**: Trains the primary model on County-level data. This generates the foundational weights (`county_Y.csv`).
*   **`04b_modeling_zcta.jl`** & **`04c_modeling_tract.jl`**: Trains models for ZCTA and Tract levels. These levels leverage the weights learned at the County level (`Y_prev_fp`) to ensure consistency across geographies while allowing local representations (`X`) to vary.

### 5. Validation & Results
*   **`05a_results_county.jl`**: Validates the County-level index against CDC Places data and compares it to SVI, NDI, and NRI.
*   **`05b_results_zcta.jl`** & **`05c_results_tract.jl`**: Performs similar validation at the ZCTA and Tract levels.

## Methodology

We define a GLRM with constraints to ensure a principled, interpretable index.

**The Optimization Problem**

We minimize a loss function subject to constraints that encourage non-negativity and sparsity:

$$
\begin{aligned}
\min_{X,Y} \quad & \sum_{(i,j) \in \Omega} f_h \left( A_{i,j} - \left( XY \right)_{i,j} \right)+ \gamma_1 \left\Vert Y_{2:k,:} \right\Vert_1 + \gamma_2 \left\Vert Y_{2:k,:} \right\Vert_2 \\
\text{s.t.} \quad & X_{1,:} \geq 0 \\
& Y_{1,:} \geq 0 \\
& \max_{i} \sum_{j=1} \left|X_{i,j}\right| \leq 1
\end{aligned}
$$

Where $f_h$ is the Huber loss function, defined as:

$$
f_h(x) = \begin{cases} 
  x^2 & |x| \leq c \\
  2c\cdot |x| - c^2 & |x| > c
\end{cases}
$$

**Key Constraints Explained:**
*   **Non-negativity ($X_{1,:} \geq 0, Y_{1,:} \geq 0$)**: Ensures the primary component represents a positive accumulation of deprivation factors ("lower bound" of deprivation).
*   **Regularization ($L_1, L_2$)**: Applied to subsequent components to push explanatory power to the primary component.
*   **Huber Loss**: Reduces the sensitivity of the model to outliers in the data.

## Data Sources

The model is trained using the following open data sources:

| Source | Category | Variables Used |
| :--- | :--- | :--- |
| **US Census** | Demographics | Population, Housing, Income, Employment |
| **FBI CDE** | Safety | Crime rates (Offenses against Persons/Property/Society) |
| **FEMA** | Risk | Expected Annual Loss (Natural disasters) |
| **USDA** | Access | Food Access Research Atlas (Low access/low income) |
| **HUD** | Geography | USPS Crosswalk files |

**Validation Data**:
*   **CDC PLACES**: Health outcome data (e.g., Poor mental health, Diabetes, Obesity) pulled via UCSF Health Atlas.

**Comparison Indices**:
*   Social Vulnerability Index (SVI)
*   Neighborhood Deprivation Index (NDI)
*   National Risk Index (NRI)
*   Neighborhood Socioeconomic Status (nSES)

## Results

The generated Principled Deprivation Index (PDI) is compared against existing indices by correlating them with various negative health outcomes provided by CDC Places. The scripts in the `05[a-c]` series output these correlations and generate plots to visualize the overlap and performance of the PDI relative to standard metrics. Individual plots are in `plots/`

### County

Condition | PDI | NDI | SVI | NRI |
| :--- | :--- | :--- | :--- | :--- |
| Poor mental health | 0.581173 | 0.676638 | 0.572708 | 0.053637 |
| Cognitive disability | 0.700403 | 0.744145 | 0.649323 | -0.0363669 |
| Disability | 0.637453 | 0.431144 | 0.359293 | -0.214052 |
| Mobility disability | 0.788381 | 0.61525 | 0.541301 | -0.206172 |
| Self-care disability | 0.790203 | 0.776616 | 0.669724 | -0.132481 |
| Independent living disability | 0.800828 | 0.776939 | 0.663769 | -0.12941 |
| Hearing disability | 0.483669 | 0.17211 | 0.157582 | -0.435887 |
| Vision disability | 0.743171 | 0.80615 | 0.727624 | -0.0618675 |
| Poor physical health | 0.763653 | 0.640839 | 0.55533 | -0.210143 |
| Poor self-rated health | 0.790306 | 0.748529 | 0.661219 | -0.117571 |
| Diabetes | 0.76661 | 0.612323 | 0.536549 | -0.173646 |
| Stroke | 0.742518 | 0.548049 | 0.466485 | -0.278155 |
| High blood pressure | 0.71751 | 0.447176 | 0.366137 | -0.251371 |
| Chronic obstructive pulmonary disease | 0.691483 | 0.427013 | 0.323836 | -0.306082 |
| Arthritis | 0.507251 | 0.118534 | 0.0307473 | -0.362742 |
| Obesity | 0.650715 | 0.484567 | 0.334818 | -0.155034 |
| All teeth lost | 0.718803 | 0.701762 | 0.572987 | -0.120109 |
| High cholesterol | 0.47473 | 0.115454 | 0.118794 | -0.287099 |
| Asthma | 0.444139 | 0.465921 | 0.326093 | -0.111794 |
| Cancer (non-skin) or melanoma | -0.0858599 | -0.50805 | -0.462637 | -0.387521 |
| Coronary heart disease | 0.59241 | 0.23196 | 0.197912 | -0.40104 |

### ZCTA

Condition | PDI | NDI |
| :--- | :--- | :--- |
| Poor mental health | 0.508889 | 0.650338 |
| Cognitive disability | 0.590761 | 0.748416 |
| Disability | 0.332662 | 0.495785 |
| Mobility disability | 0.577281 | 0.748231 |
| Self-care disability | 0.591028 | 0.735242 |
| Independent living disability | 0.641557 | 0.776931 |
| Hearing disability | 0.393629 | 0.540589 |
| Vision disability | 0.568622 | 0.687255 |
| Poor physical health | 0.594838 | 0.766897 |
| Poor self-rated health | 0.618174 | 0.774293 |
| Diabetes | 0.517832 | 0.689963 |
| Stroke | 0.527929 | 0.674312 |
| High blood pressure | 0.456319 | 0.616938 |
| Chronic obstructive pulmonary disease | 0.532827 | 0.701266 |
| Arthritis | 0.337966 | 0.468132 |
| Obesity | 0.574869 | 0.768275 |
| All teeth lost | 0.611383 | 0.744392 |
| High cholesterol | 0.177648 | 0.303227 |
| Asthma | 0.451912 | 0.504253 |
| Cancer (non-skin) or melanoma | -0.0918394 | -0.0943093 |
| Coronary heart disease | 0.398257 | 0.553607 |

### Tract

Condition | PDI | NDI | SVI | NRI | nSES |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Poor mental health | 0.617391 | 0.756312 | 0.611679 | 0.0526768 | 0.721862 |
| Cognitive disability | 0.702095 | 0.827733 | 0.707837 | 0.128541 | 0.792472 |
| Disability | 0.544312 | 0.499616 | 0.381473 | 0.0452995 | 0.496748 |
| Mobility disability | 0.756119 | 0.757189 | 0.626418 | 0.123755 | 0.716391 |
| Self-care disability | 0.734778 | 0.786704 | 0.704046 | 0.103686 | 0.761842 |
| Independent living disability | 0.766361 | 0.832248 | 0.725802 | 0.0919571 | 0.810972 |
| Hearing disability | 0.473216 | 0.450109 | 0.273731 | 0.137822 | 0.440102 |
| Vision disability | 0.719596 | 0.783042 | 0.758535 | 0.138183 | 0.76813 |
| Poor physical health | 0.771566 | 0.826383 | 0.681032 | 0.137639 | 0.800541 |
| Poor self-rated health | 0.771259 | 0.834159 | 0.75399 | 0.150808 | 0.801609 |
| Diabetes | 0.693826 | 0.684211 | 0.579362 | 0.140436 | 0.625801 |
| Stroke | 0.688796 | 0.664193 | 0.523901 | 0.0919557 | 0.638529 |
| High blood pressure | 0.586178 | 0.522268 | 0.313248 | 0.0518131 | 0.441673 |
| Chronic obstructive pulmonary disease | 0.659803 | 0.65797 | 0.405772 | 0.0503004 | 0.606046 |
| Arthritis | 0.388372 | 0.321127 | 0.035744 | -0.0257132 | 0.26116 |
| Obesity | 0.677252 | 0.752842 | 0.468255 | 0.00992877 | 0.646724 |
| All teeth lost | 0.721536 | 0.790117 | 0.667015 | 0.049354 | 0.757987 |
| High cholesterol | 0.242123 | 0.152609 | 0.0301885 | 0.0985966 | 0.112359 |
| Asthma | 0.585764 | 0.652264 | 0.435436 | -0.149716 | 0.633907 |
| Cancer (non-skin) or melanoma | -0.168344 | -0.284778 | -0.417213 | -0.00903761 | -0.271392 |
| Coronary heart disease | 0.504145 | 0.448662 | 0.255676 | 0.0915533 | 0.420965 |



