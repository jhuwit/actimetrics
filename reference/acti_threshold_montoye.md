# Classify wrist ActiGraph counts with Montoye cut-points

Classifies 60-second ActiGraph vector-magnitude counts from a
non-dominant wrist as sedentary, light activity, or moderate-to-vigorous
physical activity (MVPA). These cut-points were developed in free-living
adults with a GT9X Link and should not be used for another placement,
device, or epoch.

## Usage

``` r
acti_threshold_montoye(data, name = "montoye_intensity")
```

## Arguments

- data:

  A data frame with `time` and `counts` columns.

- name:

  Name of the added ordered factor column.

## Value

`data` with an ordered factor column named by `name`.

## Details

Montoye et al. recommend `<2860` counts/minute for sedentary activity,
`2860`–`3940` for light activity, and `>=3941` for MVPA
<doi:10.1080/02640414.2020.1794244>.

## References

Montoye AH, Clevenger KA, Pfeiffer KA, et al. Development of cut-points
for determining activity intensity from a wrist-worn ActiGraph
accelerometer in free-living adults. *Journal of Sports Sciences*.
2020;38(22):2569-2578. doi:10.1080/02640414.2020.1794244.
