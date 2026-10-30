# Download the Eurostat extracts used by the monetary valuation document.
#
# Sources (retrieved with the eurostat R package, SDMX API):
#   for_sup_cp      Supply and use of products within forestry, million euro (current prices)
#                   kept: for_acc P1_TR, output of forest trees (standing timber)
#   for_basic       Roundwood, fuelwood and other basic products
#                   kept: prod_wd RW (roundwood), treespec TOTAL, stk_flow EXP (exports),
#                   in thousand euro and thousand m3
#   prc_hicp_aind   HICP, annual average index (2015 = 100), all items, EU27 (2020 composition)
# Output: data/inputs/eurostat/for_sup_cp_p1tr.rds, for_basic_rw_exports.rds, hicp_eu27.rds (and .csv)
# Run   : source("scripts/04_download_eurostat_monetary.R", encoding = "UTF-8"), from the project root.
#         Needs internet access; the committed outputs are what the document reads.

library(eurostat)
library(dplyr)
library(tidyr)
library(readr)

out_dir <- "data/inputs/eurostat"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

save_both <- function(x, name) {
  saveRDS(x, file.path(out_dir, paste0(name, ".rds")))
  write_csv(x, file.path(out_dir, paste0(name, ".csv")))
}

# Output of standing trees, million euro, current prices
for_sup_cp <- get_eurostat("for_sup_cp", time_format = "num", cache = FALSE) |>
  filter(unit == "MIO_EUR", for_acc == "P1_TR", between(TIME_PERIOD, 2000, 2024)) |>
  transmute(geo, year = as.integer(TIME_PERIOD), value_mio_eur = values) |>
  filter(!is.na(value_mio_eur)) |>
  arrange(geo, year)
save_both(for_sup_cp, "for_sup_cp_p1tr")

# Roundwood exports: value and volume in one row per country-year
for_basic <- get_eurostat("for_basic", time_format = "num", cache = FALSE) |>
  filter(
    prod_wd == "RW", treespec == "TOTAL", stk_flow == "EXP",
    unit %in% c("THS_EUR", "THS_M3"), between(TIME_PERIOD, 2000, 2024)
  ) |>
  transmute(geo, year = as.integer(TIME_PERIOD), unit, values) |>
  pivot_wider(names_from = unit, values_from = values) |>
  rename(exports_ths_eur = THS_EUR, exports_ths_m3 = THS_M3) |>
  arrange(geo, year)
save_both(for_basic, "for_basic_rw_exports")

# Deflator: HICP all items, EU27 (2020 composition), 2015 = 100
hicp <- get_eurostat(
  "prc_hicp_aind", time_format = "num", cache = FALSE,
  filters = list(geo = "EU27_2020", coicop = "CP00", unit = "INX_A_AVG")
) |>
  transmute(year = as.integer(time), hicp_2015 = values) |>
  arrange(year)
save_both(hicp, "hicp_eu27")
