# Helper to build the 100 m spatial key of the wood provision maps.
# Load with: source("scripts/helpers_weights.R", encoding = "UTF-8")

library(terra)

# CLC accounting classes of forest: broad-leaved, coniferous, mixed and transitional woodland-shrub
forest_codes <- c(311, 312, 313, 324)

# Annual productivity product used for each reporting year
gdmp_product <- c(`2000` = "1km", `2006` = "1km", `2012` = "1km", `2018` = "300m", `2024` = "300m")

# Grid of the maps: 100 m, aligned with the CLC grid, EPSG:3035
template_100m <- function() {
  rast(
    xmin = 2636000, xmax = 7317000, ymin = 1385900, ymax = 5415900,
    resolution = 100, crs = "EPSG:3035"
  )
}

#' Weight of every 100 m cell in a year.
#'
#' The weight is 1 for forest (CLC accounting codes in `forest_codes`) times the annual
#' productivity of the year resampled to 100 m (bilinear). Cells outside the EU27
#' countries get 0.
#'
#' @param yr Reporting year.
#' @param ids Raster of country ids on the 100 m grid (NA outside the EU27).
#' @param file Path of the GeoTIFF to write.
#' @return The weight as a SpatRaster read from `file`.
build_weight_100m <- function(yr, ids, file,
                              clc_dir = "refs/clc_accounting", gdmp_dir = "refs/gdmp_annual") {
  clc <- crop(rast(file.path(clc_dir, sprintf("CLC%sACC_V2024_21.tif", yr))), ids)
  levels(clc) <- NULL
  coltab(clc) <- NULL
  forest <- ifel(clc %in% forest_codes & !is.na(ids), 1, 0)

  gdmp <- rast(file.path(gdmp_dir, sprintf("gdmp_%s_%s_4326.tif", gdmp_product[[as.character(yr)]], yr)))
  gdmp100 <- project(gdmp, ids, method = "bilinear")
  weight <- forest * ifel(is.na(gdmp100), 0, gdmp100)
  writeRaster(weight, file, datatype = "FLT4S", overwrite = TRUE,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))
}
