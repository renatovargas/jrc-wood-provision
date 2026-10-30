# Download the Eurostat extract used by the wood provision document.
#
# Source : Eurostat dataset for_vol_efa, "Volume of timber over bark (EFA questionnaire)",
#          doi:10.2908/FOR_VOL_EFA, retrieved with the eurostat R package (SDMX API).
# Keeps  : unit THS_M3 (thousand cubic metres), stk_flow NAI (net annual increment) and
#          RMOV (removals), all forest categories, years 2000 to 2024.
# Output : data/inputs/eurostat/for_vol_efa_thsm3.rds and .csv  (long format, a few hundred KB)
# Run    : source("scripts/03_download_eurostat.R", encoding = "UTF-8"), from the project root.
#          Needs internet access; the committed output is what the document reads.
# Note   : the Excel file in data/inputs/eurostat/ is the default view (million euro,
#          2015 to 2024) and holds no volumes, so it is kept only as provenance.

library(eurostat)
library(dplyr)
library(readr)

out_dir <- "data/inputs/eurostat"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

raw <- get_eurostat("for_vol_efa", time_format = "num", cache = FALSE)

for_vol_efa <- raw |>
  filter(
    unit == "THS_M3",
    stk_flow %in% c("NAI", "RMOV"),
    between(TIME_PERIOD, 2000, 2024)
  ) |>
  transmute(
    geo,
    year = as.integer(TIME_PERIOD),
    flow = stk_flow,
    forest_class = indic_fo,
    thousand_m3 = values
  ) |>
  # Keep rows with a reported value; gaps are handled explicitly in the document
  filter(!is.na(thousand_m3)) |>
  arrange(flow, forest_class, geo, year)

attr(for_vol_efa, "retrieved") <- format(Sys.time(), "%Y-%m-%d")

saveRDS(for_vol_efa, file.path(out_dir, "for_vol_efa_thsm3.rds"))
write_csv(for_vol_efa, file.path(out_dir, "for_vol_efa_thsm3.csv"))
