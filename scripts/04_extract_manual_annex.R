# Extract the timber tables by member state printed in INCA Part III.
#
# Why    : those tables are the published reference for 2000, 2006 and 2012, against which the method choices and
#          results are compared.
# Input  : refs/inca_part_iii_online_version.pdf, Annexes AA37, AA39, AA41, AA43, AA45 and AA47 (needs pdftotext).
# Output : data/inputs/params/inca_part3_timber_annex.csv, by member state and year, with the supply of timber
#          provision in million m3 and in million euro. Short and easy to check by eye against the PDF.
# Run    : source("scripts/04_extract_manual_annex.R", encoding = "UTF-8"), from the project root.

library(dplyr)
library(stringr)

lines <- system2("pdftotext", c("-layout", "refs/inca_part_iii_online_version.pdf", "-"), stdout = TRUE)
codes <- c("AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL", "ES", "FI", "FR", "HR", "HU", "IE", "IT", "LT",
           "LU", "LV", "MT", "NL", "PL", "PT", "RO", "SE", "SI", "SK", "UK")

read_annex <- function(annex) {
  starts <- grep(paste0("^\\s*", annex, "\\. "), lines)
  from <- starts[length(starts)]
  to <- grep("^\\s*AA[0-9]+\\. ", lines)
  to <- to[to > from][1] - 1
  rows <- str_match(lines[from:to], "^\\s*([A-Z]{2})\\s+(.*)$")
  rows <- rows[!is.na(rows[, 2]) & rows[, 2] %in% codes, , drop = FALSE]
  values <- vapply(rows[, 3], function(text) {
    cells <- str_split(str_trim(text), "\\s{2,}")[[1]]
    numbers <- suppressWarnings(as.numeric(gsub(" ", "", cells)))
    if (all(is.na(numbers))) NA_real_ else max(numbers, na.rm = TRUE)
  }, numeric(1))
  tibble(geo = rows[, 2], value = unname(values))
}

physical <- bind_rows(
  read_annex("AA37") |> mutate(year = 2000L),
  read_annex("AA41") |> mutate(year = 2006L),
  read_annex("AA45") |> mutate(year = 2012L)
) |>
  rename(million_m3 = value)
monetary <- bind_rows(
  read_annex("AA39") |> mutate(year = 2000L),
  read_annex("AA43") |> mutate(year = 2006L),
  read_annex("AA47") |> mutate(year = 2012L)
) |>
  rename(million_eur = value)

annex <- full_join(physical, monetary, by = c("geo", "year")) |>
  select(geo, year, million_m3, million_eur) |>
  arrange(geo, year)
stopifnot(nrow(annex) == 28 * 3)

write.csv(annex, "data/inputs/params/inca_part3_timber_annex.csv", row.names = FALSE, na = "")
