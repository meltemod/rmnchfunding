# Fetch bilateral CRS disbursements for a donor

Pulls a donor's disbursements from the OECD Creditor Reporting System
for the purpose codes the Muskoka method weights, broken down by
recipient and year. The result is what `muskoka()` applies
[sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
to, and is also readable on its own as a picture of which recipient
countries a donor funded and by how much.

## Usage

``` r
oecd_crs(
  donor,
  years,
  sectors = NULL,
  prices = c("constant", "current"),
  base = NULL,
  recipients = c("countries", "all", "aggregates"),
  measure = "100",
  flow_type = "D",
  quiet = FALSE
)
```

## Arguments

- donor:

  OECD donor code, e.g. `"USA"`, `"GBR"`, `"4EU001"` for the EU
  institutions. One or more.

- years:

  Integer vector of years to fetch.

- sectors:

  CRS purpose codes as character. Defaults to the codes the Muskoka
  method weights, taken from
  [sector_weights](https://meltemod.github.io/rmnchfunding/reference/sector_weights.md)
  so the two cannot drift apart.

- prices:

  Either `"constant"` (needs `base`) or `"current"`.

- base:

  Base year for `prices = "constant"`; must not be given for
  `"current"`.

- recipients:

  Which recipient rows to keep. `"countries"` (default) keeps only
  non-aggregate codes and is the only setting whose rows can safely be
  summed. Note that this includes OECD's unallocated `_X` buckets
  ("Developing countries unspecified", "Sub-Saharan Africa unspecified"
  and so on) — they are not countries, but they hold real spending that
  is not attributable to one, and dropping them would understate the
  total. They are marked by `is_unallocated`; see below. `"aggregates"`
  keeps only aggregate codes. `"all"` keeps everything as OECD returned
  it, which is useful for checking a total against its parts but **must
  not be summed**.

- measure:

  CRS measure code. Defaults to `"100"`, Official Development
  Assistance.

- flow_type:

  CRS flow type. Defaults to `"D"`, disbursements.

- quiet:

  Set `TRUE` to suppress the message describing what was fetched and how
  it was priced.

## Value

A tibble of one row per donor, recipient, purpose code and year:

- donor, donor_name:

  Provider code and label.

- recipient, recipient_name:

  Recipient code and label.

- purpose_code, purpose_name:

  CRS purpose code and label.

- year:

  Calendar year of the disbursement.

- value:

  Disbursement in millions of USD, in the prices described by the
  `prices` and `base` attributes.

- is_aggregate:

  Whether the recipient is an aggregate of other recipients. Always
  `FALSE` under the default `recipients` setting; retained so that a
  summed frame can be checked.

- is_unallocated:

  Whether the row is one of OECD's `_X` buckets, holding spending not
  attributable to a country. Substantial: over 40% of United States
  disbursements in 2022. Sum without these for a country-attributable
  figure, and with them for a donor total.

with attributes `prices`, `base_year` and `fetched_on`.

A donor that funded nothing in the requested sectors and years returns
**0 rows with those same columns**, and warns. That is a legitimate
answer rather than a failure — small providers routinely report no
reproductive-health disbursements at all — and erroring would abort any
loop over donors on its first sparse one.

## Details

Recipient rows are de-duplicated by default. This matters more than it
sounds: a CRS query with the recipient dimension open returns aggregates
and countries as sibling rows, so "Developing countries", "Africa" and
"Kenya" all come back together and summing them counts Kenya four times.
Nothing in the response marks which rows are aggregates. See
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md)
and the `recipients` argument.

De-duplicating is not the same as reducing to countries. OECD reports
the part of a donor's spending it cannot attribute to any one country in
`_X` buckets — "Developing countries unspecified", "Sub-Saharan Africa
unspecified" — which have no members and so are kept, correctly, since
they do not overlap anything. They are a large share of the total, so
they are flagged with `is_unallocated` rather than silently mixed in
with countries or silently dropped.

## Prices

`prices = "current"` returns each year in that year's own prices.
Nothing is converted, and the function says so.

`prices = "constant"` requires a `base` year, and the values are
deflated to it with OECD's own per-donor ODA deflators. The base is
explicit rather than inherited because **OECD rebases its constant
series with each release** — it is 2024 at the time of writing and was
2023 a few months earlier — so code that trusted the default would
silently change meaning between releases. Deflators are per donor and
vary widely between them, so a DAC-wide average is not used.

To reproduce a published Donors Delivering figure, match its edition's
base: 2022 for the 2025 edition, 2023 for the 2026 edition.

## See also

[`oecd_multi()`](https://meltemod.github.io/rmnchfunding/reference/oecd_multi.md)
for the multilateral half,
[crs_recipients](https://meltemod.github.io/rmnchfunding/reference/crs_recipients.md)
for the aggregate/leaf distinction.

## Examples

``` r
if (FALSE) { # interactive()
# Reproduce the price basis of the 2026 report edition
us <- oecd_crs("USA", years = 2022:2024, prices = "constant", base = 2023)

# Which countries, and how much
aggregate(value ~ recipient_name, data = us, FUN = sum)
}
```
