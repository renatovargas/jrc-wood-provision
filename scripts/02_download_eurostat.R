# Download the Eurostat extracts behind the accounts.
#
# Why    : the physical and monetary accounts start from these four tables, which Eurostat revises, so the
#          extract used is kept in the repository and rerunning this script can change the results.
# Inputs : Eurostat, through the eurostat R package (SDMX API):
#            for_vol_efa    Volume of timber over bark, thousand m3. Kept: NAI and removals, all forest classes.
#            for_sup_cp     Supply and use of products within forestry, million euro. Kept: P1_TR, forest trees.
#            for_basic      Roundwood, fuelwood and other basic products. Kept: roundwood exports, value and volume.
#            prc_hicp_aind  HICP, annual average index, 2015 = 100, all items, EU27 (2020 composition).
# Outputs: data/inputs/eurostat/for_vol_efa_thsm3.rds, for_sup_cp_p1tr.rds, for_basic_rw_exports.rds, hicp_eu27.rds
# Run    : source("scripts/02_download_eurostat.R", encoding = "UTF-8"), from the project root. Needs internet access.

library(eurostat)
library(dplyr)
library(tidyr)

out_dir <- "data/inputs/eurostat"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

for_vol_efa <- get_eurostat("for_vol_efa", time_format = "num", cache = FALSE) |>
  filter(unit == "THS_M3", stk_flow %in% c("NAI", "RMOV"), between(TIME_PERIOD, 2000, 2024)) |>
  transmute(geo, year = as.integer(TIME_PERIOD), flow = stk_flow, forest_class = indic_fo, thousand_m3 = values) |>
  filter(!is.na(thousand_m3)) |>
  arrange(geo, year, flow, forest_class)
saveRDS(for_vol_efa, file.path(out_dir, "for_vol_efa_thsm3.rds"))

for_sup_cp <- get_eurostat("for_sup_cp", time_format = "num", cache = FALSE) |>
  filter(unit == "MIO_EUR", for_acc == "P1_TR", between(TIME_PERIOD, 2000, 2024)) |>
  transmute(geo, year = as.integer(TIME_PERIOD), value_mio_eur = values) |>
  filter(!is.na(value_mio_eur)) |>
  arrange(geo, year)
saveRDS(for_sup_cp, file.path(out_dir, "for_sup_cp_p1tr.rds"))

for_basic <- get_eurostat("for_basic", time_format = "num", cache = FALSE) |>
  filter(prod_wd == "RW", treespec == "TOTAL", stk_flow == "EXP",
         unit %in% c("THS_EUR", "THS_M3"), between(TIME_PERIOD, 2000, 2024)) |>
  transmute(geo, year = as.integer(TIME_PERIOD), unit, values) |>
  pivot_wider(names_from = unit, values_from = values) |>
  rename(exports_ths_eur = THS_EUR, exports_ths_m3 = THS_M3) |>
  arrange(geo, year)
saveRDS(for_basic, file.path(out_dir, "for_basic_rw_exports.rds"))

hicp <- get_eurostat("prc_hicp_aind", time_format = "num", cache = FALSE,
                     filters = list(geo = "EU27_2020", coicop = "CP00", unit = "INX_A_AVG")) |>
  transmute(year = as.integer(time), hicp_2015 = values) |>
  arrange(year)
saveRDS(hicp, file.path(out_dir, "hicp_eu27.rds"))
