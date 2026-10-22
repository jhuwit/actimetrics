# Classify adult ENMO with Hildebrand cut-points

Classifies one-second, raw ActiGraph GT3X+ ENMO values in mg from adults
as light-or-less, moderate, or vigorous physical activity. The source
used a 60-Hz device at the right hip or non-dominant wrist; select the
matching placement and do not apply these adult thresholds to children.

## Usage

``` r
acti_threshold_hildebrand(
  data,
  placement = c("wrist", "hip"),
  name = "hildebrand_intensity",
  enmo = "enmo"
)

acti_threshold_hildebrand_wrist(..., placement = "wrist")

acti_threshold_hildebrand_hip(..., placement = "hip")
```

## Arguments

- data:

  A data frame with a `time` and an ENMO column.

- placement:

  Body placement used in the original calibration: `"hip"` or `"wrist"`.

- name:

  Name of the added ordered factor column.

- enmo:

  Name of the ENMO column, in mg.

- ...:

  not used, but used to pass arguments to acti_threshold_hildebrand from
  acti_threshold_hildebrand_wrist and acti_threshold_hildebrand_hip

## Value

`data` with an ordered factor column named by `name`.

## Details

Hildebrand et al. report lower bounds of 69.1 and 258.7 mg at the hip,
and 100.6 and 428.8 mg at the wrist, for moderate and vigorous activity,
respectively <doi:10.1249/MSS.0000000000000289>.

## References

Hildebrand M, van Hees VT, Hansen BH, Ekelund U. Age group comparability
of raw accelerometer output from wrist- and hip-worn monitors. *Medicine
& Science in Sports & Exercise*. 2014;46(9):1816-1824.
doi:10.1249/MSS.0000000000000289.
