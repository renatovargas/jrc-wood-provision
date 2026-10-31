# Build the spatial key of the wood provision maps, one weight raster per reporting year.
#
# Inputs : refs/clc_accounting/CLC<year>ACC_V2024_21.tif (CLC accounting layers, 100 m, version 21)
#          refs/gdmp_annual/gdmp_<product>_<year>_4326.tif (annual Gross Dry Matter Productivity)
#          data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg
# Output : data/inputs/weights/clc_gdmp_weight_1km_<year>.tif
#          Sum of the 100 m weights (forest times productivity) inside each 1 km cell.
#          refs/weights_100m/weight_<year>.tif (100 m weights, not versioned, reused by script 07)
# Run    : source("scripts/05_prepare_weights.R", encoding = "UTF-8"), once, from the project root.
#          Resumable. Takes several minutes per year.

library(terra)
source("scripts/helpers_weights.R", encoding = "UTF-8")

years_report <- c(2000, 2006, 2012, 2018, 2024)
dir.create("data/inputs/weights", showWarnings = FALSE, recursive = TRUE)
dir.create("refs/weights_100m", showWarnings = FALSE, recursive = TRUE)

countries <- vect("data/inputs/gis/NUTS_RG_01M_2024_3035_LEVL0.gpkg")
countries <- countries[countries$eu27, ]
countries$id <- seq_len(nrow(countries))
ids <- rasterize(countries, template_100m(), field = "id")

for (yr in years_report) {
  file_100m <- sprintf("refs/weights_100m/weight_%s.tif", yr)
  file_1km <- sprintf("data/inputs/weights/clc_gdmp_weight_1km_%s.tif", yr)
  if (file.exists(file_1km)) next
  weight <- if (file.exists(file_100m)) rast(file_100m) else build_weight_100m(yr, ids, file_100m)
  w1km <- aggregate(weight, fact = 10, fun = "sum", na.rm = TRUE)
  names(w1km) <- paste0("clc_gdmp_weight_", yr)
  writeRaster(w1km, file_1km, datatype = "FLT4S", overwrite = TRUE,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))
}
