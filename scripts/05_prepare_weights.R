# Build the spatial key of the maps, one weight raster per reporting year.
#
# Why    : the sources are too large for the repository, so the key is kept at 100 m in refs/ and at 1 km in data/.
# Inputs : refs/clc_accounting/CLC<year>ACC_V2024_21.tif (CLC accounting layers, 100 m, version 21)
#          refs/gdmp_annual/gdmp_<product>_<year>_4326.tif (annual Gross Dry Matter Productivity, script 00)
#          data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg (script 01)
# Outputs: refs/weights_100m/weight_<year>.tif, forest times productivity at 100 m, read by script 10
#          data/inputs/weights/clc_gdmp_weight_1km_<year>.tif, the sum of the 100 m weights in each 1 km cell
#          data/outputs/report/forest_mask.rds, hectares of forest and of the class left out, by year
# Run    : source("scripts/05_prepare_weights.R", encoding = "UTF-8"), from the project root. Resumable, and it
#          takes several minutes per year. Define `years_override` in the session to run a subset of the years,
#          in which case the summary table is left for a run with all the years.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_weights.R", encoding = "UTF-8")

run_years <- if (exists("years_override")) years_override else years_report
dir.create("data/inputs/weights", showWarnings = FALSE, recursive = TRUE)
dir.create("refs/weights_100m", showWarnings = FALSE, recursive = TRUE)
tmp_dir <- file.path("refs", paste0("weights_tmp_", paste(run_years, collapse = "_")))
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)
terraOptions(tempdir = tmp_dir, memfrac = 0.2, progress = 0)

countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
countries <- countries[countries$eu27, ]
countries$id <- seq_len(nrow(countries))
ids <- rasterize(countries, template_100m(), field = "id", filename = file.path(tmp_dir, "ids.tif"), overwrite = TRUE)

for (yr in run_years) {
  file_100m <- sprintf("refs/weights_100m/weight_%s.tif", yr)
  file_1km <- sprintf("data/inputs/weights/clc_gdmp_weight_1km_%s.tif", yr)
  if (file.exists(file_1km)) next
  weight <- if (file.exists(file_100m)) rast(file_100m) else build_weight_100m(yr, ids, file_100m)
  w1km <- aggregate(weight, fact = 10, fun = "sum", na.rm = TRUE)
  names(w1km) <- paste0("clc_gdmp_weight_", yr)
  writeRaster(w1km, file_1km, datatype = "FLT4S", overwrite = TRUE,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))
}

if (!exists("years_override")) {
  forest_mask <- lapply(years_report, function(yr) {
    clc <- crop(rast(file.path("refs/clc_accounting", sprintf("CLC%sACC_V2024_21.tif", yr))), ids)
    levels(clc) <- NULL
    coltab(clc) <- NULL
    cells <- freq(mask(clc, ids))
    tibble::tibble(
      year = yr,
      forest_ha = sum(cells$count[cells$value %in% forest_codes]),
      transitional_ha = sum(cells$count[cells$value == 324])
    )
  })
  save_report_table(bind_rows(forest_mask), "forest_mask")
}
unlink(tmp_dir, recursive = TRUE)
