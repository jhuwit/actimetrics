# Classify adolescent hip ActiGraph counts with Romanzini cut-points

Classifies 15-second ActiGraph GT3X vector-magnitude counts from an
adolescent hip-worn monitor as sedentary, light, moderate, or vigorous
activity. The cut-points must not be rescaled to another epoch.

## Usage

``` r
acti_threshold_romanzini(data, name = "romanzini_intensity")
```

## Arguments

- data:

  A data frame with `time` and `counts` columns.

- name:

  Name of the added ordered factor column.

## Value

`data` with an ordered factor column named by `name`.

## Details

Romanzini et al. recommend `<=180` counts/15 seconds for sedentary,
`181`–`756` for light, `757`–`1111` for moderate, and `>=1112` for
vigorous activity <doi:10.1080/17461391.2012.732614>.

## References

Romanzini M, Petroski EL, Ohara D, Dourado AC, Reichert FF. Calibration
of ActiGraph GT3X, Actical and RT3 accelerometers in adolescents.
*European Journal of Sport Science*. 2014;14(1):91-99.
doi:10.1080/17461391.2012.732614.
