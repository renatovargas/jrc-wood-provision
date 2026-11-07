# Build the annual Gross Dry Matter Productivity layers that script 05 reads.
#
# Why    : the spatial key places national values on forest in proportion to annual productivity, and Copernicus
#          publishes that productivity as 36 global files a year.
# Status : run_all.R leaves this script out, and the reason is written there. Run it by hand, and only when a file in
#          refs/gdmp_annual/ is missing or when a new version of the product should replace it.
# Source : Copernicus Land Monitoring Service, Gross Dry Matter Productivity, 10-daily, global, cloud optimised GeoTIFF,
#          read from the Copernicus Data Space Ecosystem S3 store.
#            v2 1 km  (doi:10.2909/b54be6e3-5962-4e9a-a443-9ff7ea943dfe)  years 2000, 2006 and 2012
#            v2 300 m (doi:10.2909/fd838f95-21e9-4f37-a9b8-b438d9dc4edf)  years 2018 and 2024
# Needs  : - A free Copernicus Data Space account with S3 keys (https://documentation.dataspace.copernicus.eu/APIs/S3.html),
#            in the environment variables CDSE_S3_ACCESS_KEY and CDSE_S3_SECRET_KEY. Never write the keys to a file.
#          - Internet access, and the R packages terra and parallel, with a GDAL build that can read /vsis3/.
#          - Time and disk. It reads 180 files over the network, which takes hours. The five results take about 1 GB,
#            and the temporary files of one 300 m year take roughly 10 GB, an estimate that was not measured.
# Method : Each 10-daily file holds a daily rate in kg of dry matter per hectare per day. The annual value is the sum of
#          the 36 files, each multiplied by its number of days (10, 10 and the rest of the month). Missing cells in a file
#          count as zero. Only the window that covers Europe is read, and the most consolidated release (RT6) is used
#          when a date has several.
# Output : refs/gdmp_annual/gdmp_<product>_<year>_4326.tif, in EPSG:4326 at the resolution of the product. An existing
#          file is left as it is, so the script resumes by year and does nothing when all five exist.
# Run    : source("scripts/00_prepare_gdmp_annual.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_weights.R", encoding = "UTF-8")

annual_dir <- "refs/gdmp_annual"
cache_dir <- "refs/gdmp_cache"
dir.create(annual_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

catalogue_url <- "https://s3.waw3-1.cloudferro.com/swift/v1/CatalogueCSV/bio-geophysical/dry-gross_dry_matter_productivity/%s/%s_cog.csv"
s3_root <- "/vsis3/eodata/CLMS/bio-geophysical/dry-gross_dry_matter_productivity"
n_cores <- max(1L, min(4L, parallel::detectCores() - 1L))

#' Set the access to the store for this process and the ones it starts.
use_s3_keys <- function() {
  access_key <- Sys.getenv("CDSE_S3_ACCESS_KEY")
  secret_key <- Sys.getenv("CDSE_S3_SECRET_KEY")
  stopifnot("Set CDSE_S3_ACCESS_KEY and CDSE_S3_SECRET_KEY" = nzchar(access_key) && nzchar(secret_key))
  Sys.setenv(
    AWS_ACCESS_KEY_ID = access_key, AWS_SECRET_ACCESS_KEY = secret_key,
    AWS_S3_ENDPOINT = "eodata.dataspace.copernicus.eu", AWS_VIRTUAL_HOSTING = "FALSE",
    AWS_HTTPS = "YES", AWS_DEFAULT_REGION = "default"
  )
}

#' Paths of the 36 files of a year and the days each one covers, from the public catalogue of the product.
dekad_paths <- function(year, product) {
  dataset <- if (product == "1km") "gdmp_global_1km_10daily_v2" else "gdmp_global_300m_10daily_v2"
  catalogue_file <- file.path(cache_dir, paste0("catalogue_", dataset, ".csv"))
  if (!file.exists(catalogue_file)) {
    download.file(sprintf(catalogue_url, dataset, dataset), catalogue_file, quiet = TRUE, mode = "wb")
  }
  catalogue <- read.csv2(catalogue_file, stringsAsFactors = FALSE)
  catalogue <- catalogue[substr(catalogue$nominal_date, 1, 4) == as.character(year), ]
  if (any(grepl("-RT6_", catalogue$name))) catalogue <- catalogue[grepl("-RT6_", catalogue$name), ]
  catalogue$date <- as.Date(substr(catalogue$nominal_date, 1, 10))
  catalogue <- catalogue[order(catalogue$date), ]
  stopifnot("A year needs 36 files" = nrow(catalogue) == 36L, !anyDuplicated(catalogue$date))

  folder <- catalogue$name
  # The raster inside the folder repeats the product name and inserts the layer name GDMP.
  file <- sub("_cog$", ".tiff", sub("^(c_gls_GDMP300|c_gls_GDMP)", "\\1-GDMP", folder))
  tibble::tibble(
    date = catalogue$date,
    path = file.path(s3_root, dataset, format(catalogue$date, "%Y/%m/%d"), folder, file),
    days = as.integer(catalogue$date - c(as.Date(paste0(year - 1, "-12-31")), head(catalogue$date, -1)))
  )
}

#' Read one file, crop it to Europe and write it multiplied by its days.
read_dekad <- function(path, days, out_file) {
  if (file.exists(out_file)) return(out_file)
  r <- terra::crop(terra::rast(path), terra::ext(-32, 45, 27, 72))
  r <- terra::ifel(is.na(r), 0, r) * days
  terra::writeRaster(r, out_file, overwrite = TRUE, datatype = "FLT4S",
                     gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))
  out_file
}

for (year in years_report) {
  product <- gdmp_product[[as.character(year)]]
  annual_file <- file.path(annual_dir, sprintf("gdmp_%s_%s_4326.tif", product, year))
  if (file.exists(annual_file)) next

  use_s3_keys()
  dekads <- dekad_paths(year, product)
  tmp <- file.path(cache_dir, sprintf("%s_%s", product, year))
  dir.create(tmp, showWarnings = FALSE, recursive = TRUE)
  files <- file.path(tmp, format(dekads$date, "dekad_%Y%m%d.tif"))

  # Fresh R processes inherit the S3 settings from the environment variables set above.
  cluster <- parallel::makeCluster(n_cores)
  parallel::parLapplyLB(cluster, seq_len(nrow(dekads)), function(k, paths, days, files, read_dekad) {
    read_dekad(paths[k], days[k], files[k])
  }, paths = dekads$path, days = dekads$days, files = files, read_dekad = read_dekad)
  parallel::stopCluster(cluster)
  stopifnot("Some files were not written" = all(file.exists(files)))

  total <- sum(rast(files))
  names(total) <- sprintf("gdmp_%s_%s", product, year)
  writeRaster(total, annual_file, overwrite = TRUE, datatype = "FLT4S",
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))
  unlink(tmp, recursive = TRUE)
}
