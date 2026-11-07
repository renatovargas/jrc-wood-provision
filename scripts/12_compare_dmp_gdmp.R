# Test whether Dry Matter Productivity (DMP) and Gross Dry Matter Productivity (GDMP) would give the same spatial key.
#
# Why    : INCA Part II names DMP and the key uses GDMP. The key only shares a national value among the cells of a
#          country, so a constant ratio between the products would leave every share unchanged.
# Status : Run by hand, and outside run_all.R, because it needs Copernicus S3 keys and reads global files over the
#          network, which took about four minutes. The report reads its small table, so it does not need to run again.
# Source : Copernicus Land Monitoring Service, 10-daily global DMP and GDMP, version 2, from the Copernicus Data Space
#          Ecosystem S3 store. The 1 km product serves 2000, 2006 and 2012 and the 300 m product serves 2018 and 2024,
#          as in the key.
# Needs  : The environment variables CDSE_S3_ACCESS_KEY and CDSE_S3_SECRET_KEY, as script 00 explains, and some
#          temporary disk space for the copies of the window, which it deletes.
# Output : data/outputs/report/dmp_gdmp_check.rds, with one row for each pair of files that was compared.
# Method : For the files ending on 10 January and 10 July of each reporting year, 10 of the 180 pairs behind the key,
#          it compares DMP with half of GDMP over the window of Europe. The tolerance was set before the comparison.
#          In every pair, the absolute difference must stay within 1% of the productivity total and the cells with data
#          in only one product within 0.1% of the cells. The script records the outcome and does not stop on a failure,
#          since the result is itself the finding.
# Run    : source("scripts/12_compare_dmp_gdmp.R", encoding = "UTF-8"), from the project root.

source("scripts/helpers_common.R", encoding = "UTF-8")
source("scripts/helpers_weights.R", encoding = "UTF-8")
library(parallel)

tolerance_difference <- 0.01
tolerance_unmatched <- 0.001

cache_dir <- "refs/dmp_test"
dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
catalogue_url <- "https://s3.waw3-1.cloudferro.com/swift/v1/CatalogueCSV/bio-geophysical/dry-gross_dry_matter_productivity/%s/%s_cog.csv"
s3_root <- "/vsis3/eodata/CLMS/bio-geophysical/dry-gross_dry_matter_productivity"
window <- ext(-32, 45, 27, 72)

#' Path of the file of a variable (DMP or GDMP) on a date.
product_file <- function(variable, product, date) {
  dataset <- sprintf("%s_global_%s_10daily_v2", tolower(variable), product)
  catalogue_file <- file.path(cache_dir, paste0("catalogue_", dataset, ".csv"))
  if (!file.exists(catalogue_file)) {
    download.file(sprintf(catalogue_url, dataset, dataset), catalogue_file, quiet = TRUE, mode = "wb")
  }
  catalogue <- read.csv2(catalogue_file, stringsAsFactors = FALSE)
  catalogue <- catalogue[substr(catalogue$nominal_date, 1, 10) == date, ]
  if (any(grepl("-RT6_", catalogue$name))) catalogue <- catalogue[grepl("-RT6_", catalogue$name), ]
  stopifnot("One file per date" = nrow(catalogue) == 1L)
  folder <- catalogue$name
  # The raster inside the folder repeats the product name and inserts the name of the variable.
  file <- sub("_cog$", ".tiff", sub(sprintf("^(c_gls_%s(300)?)", variable), sprintf("\\1-%s", variable), folder))
  file.path(s3_root, dataset, format(as.Date(date), "%Y/%m/%d"), folder, file)
}

#' Compare one pair of files, block by block, on copies of the window that are deleted afterwards.
compare_pair <- function(date, product) {
  copies <- file.path(cache_dir, sprintf("%s_%s.tif", c("dmp", "gdmp"), date))
  dmp <- crop(rast(product_file("DMP", product, date)), window, filename = copies[1], overwrite = TRUE, datatype = "FLT4S")
  gdmp <- crop(rast(product_file("GDMP", product, date)), window, filename = copies[2], overwrite = TRUE, datatype = "FLT4S")
  stopifnot(compareGeom(dmp, gdmp))

  totals <- c(both = 0, only_one = 0, half_gdmp = 0, difference = 0, largest = 0)
  bounds <- blocks(dmp, n = 8)
  readStart(dmp)
  readStart(gdmp)
  for (b in seq_len(bounds$n)) {
    d <- readValues(dmp, bounds$row[b], bounds$nrows[b])
    g <- readValues(gdmp, bounds$row[b], bounds$nrows[b])
    both <- is.finite(d) & is.finite(g)
    gap <- abs(d[both] - g[both] / 2)
    totals["both"] <- totals["both"] + sum(both)
    totals["only_one"] <- totals["only_one"] + sum(is.finite(d) != is.finite(g))
    totals["half_gdmp"] <- totals["half_gdmp"] + sum(g[both] / 2)
    totals["difference"] <- totals["difference"] + sum(gap)
    if (length(gap) > 0) totals["largest"] <- max(totals["largest"], max(gap))
  }
  readStop(dmp)
  readStop(gdmp)
  unlink(copies)

  tibble::tibble(
    date = date, product = product, cells_with_data = totals[["both"]],
    unmatched_share = totals[["only_one"]] / (totals[["both"]] + totals[["only_one"]]),
    difference_share = totals[["difference"]] / totals[["half_gdmp"]],
    largest_difference = totals[["largest"]]
  )
}

use_s3_keys()
pairs <- expand.grid(year = years_report, day = c("01-10", "07-10"), stringsAsFactors = FALSE)
pairs$date <- paste(pairs$year, pairs$day, sep = "-")
pairs$product <- gdmp_product[as.character(pairs$year)]
pairs <- pairs[order(pairs$date), ]

results <- mclapply(seq_len(nrow(pairs)), function(i) {
  terraOptions(progress = 0, memfrac = 0.15)
  compare_pair(pairs$date[i], pairs$product[i])
}, mc.cores = 4, mc.preschedule = FALSE)
failed <- vapply(results, \(x) !is.data.frame(x), logical(1))
if (any(failed)) stop("Could not compare ", paste(pairs$date[failed], collapse = ", "), ": ", paste(unique(unlist(results[failed])), collapse = " "))

check <- bind_rows(results) |>
  mutate(within_tolerance = difference_share <= tolerance_difference & unmatched_share <= tolerance_unmatched,
         tolerance_difference = tolerance_difference, tolerance_unmatched = tolerance_unmatched)
save_report_table(check, "dmp_gdmp_check")
print(as.data.frame(check))
