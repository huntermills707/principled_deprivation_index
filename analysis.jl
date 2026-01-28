using Statistics

conditions = [
     (:mhlth_crudeprev, "Poor mental health"),
     (:cognition_crudeprev, "Cognitive  disability"),
     (:pct_disabled, "Disability"),
     (:mobility_crudeprev, "Mobility  disability"),
     (:selfcare_crudeprev, "Self-care  disability"),
     (:indeplive_crudeprev, "Independent living  disability"),
     (:hearing_crudeprev, "Hearing disability"),
     (:vision_crudeprev, "Vision disability"),
     (:phlth_crudeprev, "Poor physical health"),
     (:ghlth_crudeprev, "Poor self-rated health"),
     (:diabetes_crudeprev, "Diabetes"),
     (:stroke_crudeprev, "Stroke"),
     (:bphigh_crudeprev, "High blood pressure"),
     (:copd_crudeprev, "Chronic obstructive pulmonary disease"),
     (:arthritis_crudeprev, "Arthritis"),
     (:obesity_crudeprev, "Obesity"),
     (:teethlost_crudeprev, "All teeth lost"),
     (:highchol_crudeprev, "High cholesterol"),
     (:casthma_crudeprev, "Asthma"),
     (:cancer_crudeprev, "Cancer (non-skin) or melanoma"),
     (:chd_crudeprev, "Coronary heart disease"),
]

function compare(df, col)
    vals = zeros(size(conditions));
    for (i, (condition, name)) in enumerate(conditions)
        x = dropmissing(df[:, [condition, col]]);
        vals[i] = cor(x[:, condition], x[:, col]);
    end
    return vals;
end
