# Write the 100 m maps of the actual flow, sustainable flow and overuse, in physical and monetary terms.
#
# Why    : these are the published maps of the accounts. They are too large to version, so they go to
#          refs/maps_100m/ and are published outside the repository.
# Inputs : refs/weights_100m/weight_<year>.tif (script 05)
#          data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg (script 01)
#          data/outputs/results/wood_overuse_country_year.rds (script 07)
#          data/outputs/results/wood_value_country_year.rds (script 08)
# Outputs: refs/maps_100m/wood_<quantity>_100m_<year>.tif. Values are whole numbers per cell in small units, which
#          keeps the files several times smaller than decimals with no loss that matters:
#            flow_dm3, sustainable_dm3, overuse_dm3           cubic decimetres (litres) of wood
#            flow_eurocent2010, sustainable_eurocent2010, overuse_eurocent2010   euro cents at 2010 prices
#          Whole euro would be too coarse, since the overuse of a country can be worth less than one euro per cell.
# Method : Each cell receives the national value times its weight divided by the weight total of its country, so
#          the cells of a country add up to the national value. Script 11 checks this.
# Run    : source("scripts/10_write_maps_100m.R", encoding = "UTF-8"), from the project root. Resumable. Define
#          `years_override` in the session to run a subset of the years. It needs several GB of free disk space.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_weights.R", encoding = "UTF-8")

run_years <- if (exists("years_override")) years_override else years_report
out_dir <- "refs/maps_100m"
tmp_dir <- file.path("refs", paste0("maps_100m_tmp_", paste(run_years, collapse = "_")))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
terraOptions(tempdir = tmp_dir, memfrac = 0.15, progress = 0)
gdal_opts <- c("COMPRESS=DEFLATE", "PREDICTOR=2", "ZLEVEL=6", "TILED=YES", "BIGTIFF=YES")

overuse <- readRDS("data/outputs/results/wood_overuse_country_year.rds")
value <- readRDS("data/outputs/results/wood_value_country_year.rds")

national <- national_map_values(overuse, value, run_years)
quantities <- unique(national$quantity)

countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
countries <- countries[countries$eu27, ]
countries$id <- seq_len(nrow(countries))
ids <- rasterize(countries, template_100m(), field = "id", filename = file.path(tmp_dir, "ids.tif"), overwrite = TRUE)
id_table <- tibble(id = countries$id, geo = countries$geo)

for (yr in run_years) {
  targets <- file.path(out_dir, sprintf("wood_%s_100m_%s.tif", quantities, yr))
  if (all(file.exists(targets))) next

  weight <- rast(sprintf("refs/weights_100m/weight_%s.tif", yr))
  sums <- zonal(weight, ids, fun = "sum", na.rm = TRUE) |>
    setNames(c("id", "weight_sum")) |>
    inner_join(id_table, by = "id")

  for (i in seq_along(quantities)) {
    if (file.exists(targets[i])) next
    per_weight <- sums |>
      left_join(national |> filter(year == yr, quantity == quantities[i]) |> select(geo, total), by = "geo") |>
      mutate(per_weight = if_else(weight_sum > 0, total / weight_sum, 0))
    factor_raster <- classify(ids, rcl = as.matrix(per_weight[, c("id", "per_weight")]), others = NA)
    part <- paste0(targets[i], ".part.tif")
    lapp(c(weight, factor_raster), fun = function(w, f) round(w * f), filename = part, overwrite = TRUE,
         wopt = list(datatype = "INT4U", NAflag = 4294967295, names = quantities[i], gdal = gdal_opts))
    file.rename(part, targets[i])
    tmpFiles(remove = TRUE, current = TRUE, orphan = FALSE)
  }
}
unlink(tmp_dir, recursive = TRUE)
