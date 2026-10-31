# Prepare the share of each NUTS2 and NUTS3 region in the weight of its country, by year.
#
# Input  : refs/INCA_plugin/src/inca/data/NUTS_RG_01M_2024_3035_LEVL0123_INCA.gpkg
#          data/inputs/weights/clc_gdmp_weight_1km_<year>.tif (script 05)
# Output : data/inputs/weights/weight_by_nuts.rds
#          One row per EU27 region of levels 0, 2 and 3 and year, with the sum of the weight of
#          its 1 km cells and the share of the country total.
# Run    : source("scripts/06_prepare_nuts_weights.R", encoding = "UTF-8"), once, from the project root.

library(sf)
library(terra)
library(dplyr)

years_report <- c(2000, 2006, 2012, 2018, 2024)
source_gpkg <- "refs/INCA_plugin/src/inca/data/NUTS_RG_01M_2024_3035_LEVL0123_INCA.gpkg"
eu27 <- sf::st_read("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg", quiet = TRUE) |>
  filter(eu27) |>
  pull(geo)

regions <- st_read(source_gpkg, layer = "NUTS_RG_01M_2024_3035.gpkg", quiet = TRUE) |>
  filter(LEVL_CODE %in% c(0, 2, 3), substr(NUTS_ID, 1, 2) %in% eu27) |>
  transmute(
    level = paste0("NUTS", LEVL_CODE),
    nuts_id = NUTS_ID,
    name = NAME_LATN,
    geo = substr(NUTS_ID, 1, 2)
  ) |>
  arrange(level, nuts_id)

weights_by_year <- lapply(years_report, function(yr) {
  weight <- rast(sprintf("data/inputs/weights/clc_gdmp_weight_1km_%s.tif", yr))
  sums <- extract(weight, vect(regions), fun = sum, na.rm = TRUE, ID = FALSE)[[1]]
  regions |>
    st_drop_geometry() |>
    mutate(year = yr, weight_sum = replace(sums, is.na(sums), 0))
}) |>
  bind_rows()

# Countries take the whole national value, so their share is one
nuts_weights <- weights_by_year |>
  group_by(year, level, geo) |>
  mutate(share = if (level[1] == "NUTS0") 1 else if (sum(weight_sum) > 0) weight_sum / sum(weight_sum) else NA_real_) |>
  ungroup()

saveRDS(nuts_weights, "data/inputs/weights/weight_by_nuts.rds")
