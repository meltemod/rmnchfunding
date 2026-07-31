# Reference material

Published Muskoka2 output, used to validate this package's weights. Nothing in
the build depends on anything here — `data-raw/rmnch_recipient_weights.R` runs
without it. These files exist so the validation in `?rmnch_recipient_weights`
can be reproduced and re-examined.

## `Muskoka2_imputed_percentages_malaria_HIV_TB_GBS.xlsx` (committed)

The published country-by-year percentages for the four varying purpose codes,
plus their RH/MNH/CH components, the fixed percentages for every other code,
and a method note. Extracted from the workbook below, accessed 2026-07-30.

## `Muskoka2-290120v2.xlsb` (NOT committed)

The full workbook, 187 MB. Excluded from the repository for two reasons: it
exceeds GitHub's 100 MB per-file limit, and it is licensed CC BY-NC 3.0 rather
than this package's MIT, so redistributing it here would be inappropriate.

Download from the LSHTM Data Compass record:

> Dingle A, Schäferhoff M, Borghi J, Lewis Sabin M, Arregoces L,
> Martinez-Alvarez M, Pitt C. (2020). *Aid for reproductive, maternal, newborn
> and child health: data and analysis from application of the Muskoka2 method,
> 2002-2017.* [Data Collection]. London School of Hygiene & Tropical Medicine.
> <https://doi.org/10.17037/DATA.00001526>
>
> Version 1.4, released 24 March 2020. **Accessed 2026-07-30.**

It is a binary `.xlsb`, which neither `readxl` nor `openxlsx` reads. Python's
`pyxlsb` does.

### What it was consulted for

Its `Recipients & regions` sheet, which the published extract does not include.
That sheet records, for each of 176 recipients, the OECD code and name, the
World Bank name, the **IHME location**, and the OECD region name.

It settled one question and raised another.

**Settled.** For recipients GBD does not cover separately, Muskoka2 sets the
IHME location to a GBD *region* — Anguilla to "Caribbean", Cook Islands to
"Oceania" — so the imputed value is that region's aggregate ratio, which is a
ratio of summed cases and therefore burden-weighted. This package weights its
regional substitution the same way, and that sheet is the evidence for doing
so rather than an unweighted mean.

**Raised.** Two of its assignments contradict its own region column:

| recipient | its OECD region | its IHME location | |
|---|---|---|---|
| Wallis and Futuna | Oceania | Caribbean | a Pacific territory |
| Mayotte | South of Sahara | Oceania | Indian Ocean, off Africa |

Every other territory is internally consistent. These look like fill errors in
the source, and they are part of why this package does not adopt the mapping
wholesale — see `?rmnch_recipient_weights` for the grouping this package uses
instead.
