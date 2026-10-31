# Write the 100 m maps of the actual flow of wood provision, in thousand m3 and in constant 2010 euro.
#
# Why    : the 100 m maps are too large to version, so they go to refs/maps_100m/ for delivery
#          outside the repository.
# Inputs : refs/weights_100m/weight_<year>.tif (built from the CLC accounting layers and annual
#          productivity by scripts/05_prepare_weights.R, or on the fly by helpers_weights.R)
#          data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg
#          data/outputs/results/wood_nai_faws_country_year.rds
#          data/outputs/results/wood_value_country_year.rds
# Outputs: refs/maps_100m/wood_nai_clc_gdmp_100m_<year>.tif            (thousand m3 per cell)
#          refs/maps_100m/wood_value_constant_clc_gdmp_100m_<year>.tif (million euro, 2010 prices, per cell)
# Method : The weight of a 100 m cell is 1 for forest (CLC 311, 312, 313 and 324) and 0 otherwise, times
#          the annual productivity of the year resampled to 100 m (bilinear). Each cell receives the
#          national value times its weight divided by the weight total of its country, so the cells of a
#          country add up to the national total. Productivity of 2000, 2006 and 2012 comes from the 1 km
#          product, and that of 2018 and 2024 from the 300 m product.
# Run    : source("scripts/07_write_maps_100m.R", encoding = "UTF-8"), from the project root. Define
#          `years_override` in the session to run a subset of the years. It needs several GB of free
#          disk space for temporary files.

library(terra)
library(dplyr)
source("scripts/helpers_weights.R", encoding = "UTF-8")

out_dir <- "refs/maps_100m"
tmp_dir <- "refs/maps_100m_tmp"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
dir.create("refs/weights_100m", showWarnings = FALSE, recursive = TRUE)

years_report <- c(2000, 2006, 2012, 2018, 2024)
if (exists("years_override")) years_report <- years_override
gdal_opts <- c("COMPRESS=DEFLATE", "PREDICTOR=3", "ZLEVEL=6", "TILED=YES")

nai <- readRDS("data/outputs/results/wood_nai_faws_country_year.rds")
value <- readRDS("data/outputs/results/wood_value_country_year.rds")

template <- template_100m()

countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
countries <- countries[countries$eu27, ]
countries$id <- seq_len(nrow(countries))
ids <- rasterize(countries, template, field = "id", filename = file.path(tmp_dir, "ids.tif"), overwrite = TRUE)
id_table <- tibble(id = countries$id, geo = countries$geo)

write_map <- function(weight, ids, id_table, sums, totals, file, layer_name) {
  per_weight <- id_table |>
    left_join(sums, by = c("id", "geo")) |>
    left_join(totals, by = "geo") |>
    mutate(per_weight = if_else(weight_sum > 0, total / weight_sum, NA_real_)) |>
    filter(!is.na(per_weight))
  factor_raster <- classify(ids, rcl = as.matrix(per_weight[, c("id", "per_weight")]), others = NA)
  map <- weight * factor_raster
  names(map) <- layer_name
  writeRaster(map, file, overwrite = TRUE, datatype = "FLT4S", gdal = gdal_opts)
}

for (yr in years_report) {
  nai_file <- file.path(out_dir, sprintf("wood_nai_clc_gdmp_100m_%s.tif", yr))
  value_file <- file.path(out_dir, sprintf("wood_value_constant_clc_gdmp_100m_%s.tif", yr))
  if (file.exists(nai_file) && file.exists(value_file)) next

  weight_file <- sprintf("refs/weights_100m/weight_%s.tif", yr)
  weight <- if (file.exists(weight_file)) rast(weight_file) else build_weight_100m(yr, ids, weight_file)

  sums <- zonal(weight, ids, fun = "sum", na.rm = TRUE) |>
    setNames(c("id", "weight_sum")) |>
    inner_join(id_table, by = "id")

  write_map(weight, ids, id_table, sums,
            nai |> filter(year == yr) |> transmute(geo, total = nai_faws_1000m3),
            nai_file, paste0("wood_nai_", yr))
  write_map(weight, ids, id_table, sums,
            value |> filter(year == yr) |> transmute(geo, total = value_mio_eur_constant),
            value_file, paste0("wood_value_constant_", yr))

}

unlink(tmp_dir, recursive = TRUE)
