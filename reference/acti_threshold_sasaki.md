# Classify hip ActiGraph counts with Sasaki cut-points

Classifies 60-second ActiGraph vector-magnitude counts from a hip-worn
GT3X as less-than-moderate activity, moderate, hard, or very hard
activity. The source provides no sedentary/light boundary, so the first
category is deliberately named `light_or_less`. Do not use these
hip-specific cut-points for wrist data.

## Usage

``` r
acti_threshold_sasaki(data, name = "sasaki_intensity")
```

## Arguments

- data:

  A data frame with `time` and `counts` columns.

- name:

  Name of the added ordered factor column.

## Value

`data` with an ordered factor column named by `name`.

## Details

Sasaki et al. recommend `2690`–`6166` counts/minute for moderate,
`6167`–`9642` for hard, and `>9642` for very hard activity
<doi:10.1016/j.jsams.2011.04.003>.

## References

Sasaki JE, John D, Freedson PS. Validation and comparison of ActiGraph
activity monitors. *Journal of Science and Medicine in Sport*.
2011;14(5):411-416. doi:10.1016/j.jsams.2011.04.003.
