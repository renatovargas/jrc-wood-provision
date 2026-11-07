# Extract the net annual increment estimated with the carbon budget model.
#
# Why    : INCA Part III fills the gaps in the reported increment with these estimates, and the source workbook
#          holds one sheet per country, so the series is reduced to one small table.
# Input  : refs/efa_fra_cbm/EFA_FRA_CBM_Data_analysis_20210121.xlsx, downloaded from the JRC data catalogue if absent.
# Output : data/inputs/carbon_budget/cbm_nai.rds, with the total forest increment in thousand m3 by country and
#          year, 2000 to 2019, and the share of forest available for wood supply in the growing stock.
# Run    : source("scripts/03_prepare_carbon_budget.R", encoding = "UTF-8"), from the project root.

library(dplyr)
library(readxl)

source_file <- "refs/efa_fra_cbm/EFA_FRA_CBM_Data_analysis_20210121.xlsx"
source_url <- "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/EFA/EFA_FRA_CBM/LATEST/EFA_FRA_CBM_Data_analysis_20210121.xlsx"
if (!file.exists(source_file)) {
  dir.create(dirname(source_file), showWarnings = FALSE, recursive = TRUE)
  download.file(source_url, source_file, mode = "wb")
}

# Every member state except Malta, which has no sheet because it has no forest available for wood supply.
sheets <- c("BE", "BG", "CZ", "DE", "EE", "IE", "EL", "ES", "FR", "HR", "DK", "IT", "CY", "LV", "LT", "LU",
            "HU", "NL", "AT", "PL", "PT", "RO", "SI", "SK", "FI", "SE")

read_country <- function(sheet) {
  m <- as.data.frame(suppressMessages(read_excel(source_file, sheet = sheet, col_names = FALSE, n_max = 27)))
  header <- trimws(as.character(m[3, ]))
  tibble(
    geo = sheet,
    year = suppressWarnings(as.integer(m[[1]])),
    cbm_total_forest = suppressWarnings(as.numeric(m[[which(header == "Tot NAI")]])),
    share_available = suppressWarnings(as.numeric(m[[grep("FAWS/Tot", header)]]))
  ) |>
    filter(year %in% 2000:2019)
}

cbm_nai <- bind_rows(lapply(sheets, read_country))
stopifnot(nrow(cbm_nai) == 26 * 20, !anyNA(cbm_nai$cbm_total_forest), all(cbm_nai$cbm_total_forest > 0))

dir.create("data/inputs/carbon_budget", showWarnings = FALSE, recursive = TRUE)
saveRDS(cbm_nai, "data/inputs/carbon_budget/cbm_nai.rds")
