# Helper functions for the results workbook of the wood provision service.
#
# The workbook has a Readme sheet, then one sheet per output table and NUTS level, each with a banner,
# a nested header and a total row.
# Used by scripts/08_build_monetary_accounts.R.

library(dplyr)
library(tidyr)
library(openxlsx2)

results_number_format <- "#,##0.0"

#' Regional values from national values.
#'
#' National values are shared among the NUTS2 and NUTS3 regions of a country in proportion to
#' the weight of the region in the year (the spatial key of the maps), so regions add up to the country.
#'
#' @param national Data frame with `geo` and `year` and the columns in `cols`.
#' @param cols Names of the numeric columns to share.
#' @param nuts_weights Table of `year`, `level`, `nuts_id`, `name`, `geo` and `share`.
#' @return Data frame with `level`, `nuts_id`, `name`, `geo`, `year` and the columns in `cols`.
to_nuts_levels <- function(national, cols, nuts_weights) {
  regions <- nuts_weights |>
    inner_join(national, by = c("geo", "year")) |>
    mutate(across(all_of(cols), \(v) v * share)) |>
    select(level, nuts_id, name, geo, year, all_of(cols))

  regions
}

#' Write one results sheet.
#'
#' @param wb A workbook.
#' @param sheet Sheet name.
#' @param title Table title (second banner line).
#' @param note Explanatory text (third banner line).
#' @param data Long table with `nuts_id`, `name`, `year` and the metric columns.
#' @param metrics Named character vector, column name = header label.
#' @return The workbook.
write_results_sheet <- function(wb, sheet, title, note, data, metrics) {
  years <- sort(unique(data$year))
  wide <- data |>
    select(nuts_id, name, year, all_of(names(metrics))) |>
    pivot_wider(
      names_from = year, values_from = all_of(names(metrics)),
      names_glue = "{year}__{.value}", names_vary = "slowest"
    ) |>
    arrange(nuts_id)
  total <- wide |>
    summarise(across(-c(nuts_id, name), \(v) sum(v, na.rm = TRUE))) |>
    mutate(nuts_id = "EU27", name = "Total", .before = 1)
  wide <- bind_rows(wide, total)

  n_cols <- ncol(wide)
  n_met <- length(metrics)
  header_row <- 5L
  data_start <- 7L
  data_end <- data_start + nrow(wide) - 1L

  wb <- wb_add_worksheet(wb, sheet)

  banner <- c("Wood provision ecosystem service accounts, EU27", title, note)
  for (i in 1:3) {
    wb <- wb_add_data(wb, sheet, x = banner[i], start_row = i, start_col = 1, col_names = FALSE)
    wb <- wb_merge_cells(wb, sheet, dims = wb_dims(rows = i, cols = 1:min(n_cols, 10)))
    wb <- wb_add_cell_style(
      wb, sheet, dims = wb_dims(rows = i, cols = 1),
      wrap_text = TRUE, vertical = "center"
    )
  }
  wb <- wb_set_row_heights(wb, sheet, rows = 1:3, heights = c(18, 18, 32))

  year_row <- c("Code", "Region", rep(as.character(years), each = n_met))
  metric_row <- c("Code", "Region", rep(unname(metrics), times = length(years)))
  wb <- wb_add_data(wb, sheet, x = matrix(year_row, nrow = 1),
                    start_row = header_row, start_col = 1, col_names = FALSE)
  wb <- wb_add_data(wb, sheet, x = matrix(metric_row, nrow = 1),
                    start_row = header_row + 1L, start_col = 1, col_names = FALSE)
  wb <- wb_merge_cells(wb, sheet, dims = wb_dims(rows = header_row:(header_row + 1L), cols = 1))
  wb <- wb_merge_cells(wb, sheet, dims = wb_dims(rows = header_row:(header_row + 1L), cols = 2))
  if (n_met > 1) {
    for (k in seq_along(years)) {
      first <- 3L + (k - 1L) * n_met
      wb <- wb_merge_cells(wb, sheet, dims = wb_dims(rows = header_row, cols = first:(first + n_met - 1L)))
    }
  }
  header_dims <- wb_dims(rows = header_row:(header_row + 1L), cols = 1:n_cols)
  wb <- wb_add_font(wb, sheet, dims = header_dims, bold = TRUE)
  wb <- wb_add_cell_style(wb, sheet, dims = header_dims,
                          wrap_text = TRUE, horizontal = "center", vertical = "center")
  wb <- wb_add_border(wb, sheet, dims = wb_dims(rows = header_row + 1L, cols = 1:n_cols),
                      bottom_border = "thin", top_border = "none",
                      left_border = "none", right_border = "none")
  wb <- wb_set_row_heights(wb, sheet, rows = header_row:(header_row + 1L), heights = c(20, 34))

  wb <- wb_add_data(wb, sheet, x = wide, start_row = data_start, start_col = 1,
                    col_names = FALSE, na = "", apply_cell_style = FALSE)
  wb <- wb_add_numfmt(wb, sheet, dims = wb_dims(rows = data_start:data_end, cols = 3:n_cols),
                      numfmt = results_number_format)
  total_dims <- wb_dims(rows = data_end, cols = 1:n_cols)
  wb <- wb_add_font(wb, sheet, dims = total_dims, bold = TRUE)
  wb <- wb_add_border(wb, sheet, dims = total_dims,
                      top_border = "thin", bottom_border = "thin",
                      left_border = "none", right_border = "none")
  wb <- wb_set_col_widths(wb, sheet, cols = 1:n_cols, widths = c(10, 30, rep(15, n_cols - 2L)))
  wb_freeze_pane(wb, sheet, first_active_row = data_start, first_active_col = 3L)
}

#' Build the results workbook of the wood provision service.
#'
#' Actual flow is the net annual increment of forest available for wood supply. Sustainable flow is the part of the removals
#' that does not exceed the increment, and overuse is the part that does.
#'
#' @param overuse National table from `check_overuse()` (thousand m3).
#' @param monetary National table with `nai_1000m3`, `unit_value_eur_m3`, `deflator`.
#' @param nuts_weights Table from `scripts/06_prepare_nuts_weights.R`.
#' @param years Reporting years.
#' @param base_year Base year of the constant prices.
#' @param path Output file.
#' @return The path, invisibly.
write_results_workbook <- function(overuse, nuts_weights, years, base_year, path, monetary) {
  national <- overuse |>
    filter(year %in% years) |>
    transmute(geo, year, nai, removals,
              sustainable = pmin(removals, nai), overuse = overuse_volume)

  national <- national |>
    left_join(monetary |> select(geo, year, unit_value_eur_m3, deflator), by = c("geo", "year")) |>
    mutate(
      flow_nominal = nai * unit_value_eur_m3 / 1000,
      flow_constant = flow_nominal * deflator,
      sustainable_nominal = sustainable * unit_value_eur_m3 / 1000,
      sustainable_constant = sustainable_nominal * deflator,
      overuse_nominal = overuse * unit_value_eur_m3 / 1000,
      overuse_constant = overuse_nominal * deflator
    )

  value_cols <- setdiff(names(national), c("geo", "year", "unit_value_eur_m3", "deflator"))
  regional <- to_nuts_levels(national, value_cols, nuts_weights)

  tables <- list(
    Flow_phys = list(
      title = "Actual flow of wood provision in physical terms (thousand m3)",
      metrics = c(nai = "Net annual increment")
    ),
    Overuse_phys = list(
      title = "Overuse and sustainable flow of wood provision in physical terms (thousand m3)",
      metrics = c(sustainable = "Sustainable flow", overuse = "Overuse")
    )
  )
  tables$Flow_mon <- list(
    title = "Actual flow of wood provision in monetary terms (million euro)",
    metrics = c(flow_nominal = "Current prices", flow_constant = "Constant prices")
  )
  tables$Overuse_mon <- list(
    title = "Overuse and sustainable flow of wood provision in monetary terms (million euro)",
    metrics = c(sustainable_nominal = "Sustainable flow, current prices",
                  sustainable_constant = "Sustainable flow, constant prices",
                  overuse_nominal = "Overuse, current prices",
                  overuse_constant = "Overuse, constant prices")
  )

  readme <- c(
    "Wood provision ecosystem service accounts, EU27",
    paste0("Reporting years ", paste(years, collapse = ", "), ". Constant prices use ", base_year,
           " as the base year (Eurostat HICP, EU-27)."),
    "One sheet per output table and NUTS level (NUTS0, NUTS2, NUTS3). Sheet names start with Flow or Overuse, then phys or mon.",
    "Actual flow is the net annual increment (NAI) of forest available for wood supply. Sustainable flow is the removals up to the NAI. Overuse is the removals above the NAI.",
    "National values come from Eurostat and the JRC carbon budget model estimates. NUTS2 and NUTS3 values share the national value in proportion to the weight of each region in the spatial key, so regions add up to the country.",
    "Monetary values are the physical values times the national unit value of NAI, in million euro.",
    "Eurostat holds few values for 2024, so most values of that year repeat earlier years. The report explains which values are reported, which are estimates and which repeat another year."
  )

  wb <- wb_workbook() |>
    wb_add_worksheet("Readme") |>
    wb_add_data("Readme", x = readme, col_names = FALSE)
  wb <- wb_add_cell_style(wb, "Readme", dims = wb_dims(rows = seq_along(readme), cols = 1),
                          wrap_text = TRUE, vertical = "top")
  wb <- wb_set_col_widths(wb, "Readme", cols = 1, widths = 110)

  for (nm in names(tables)) {
    for (lv in c("NUTS0", "NUTS2", "NUTS3")) {
      wb <- write_results_sheet(
        wb,
        sheet = paste(nm, lv, sep = "_"),
        title = tables[[nm]]$title,
        note = paste0("Level ", lv, ". Reporting years ", paste(years, collapse = ", "),
                      ". Constant prices use ", base_year, " as the base year."),
        data = regional |> filter(level == lv),
        metrics = tables[[nm]]$metrics
      )
    }
  }

  checks <- results_checks(regional, tables)
  stopifnot("NUTS2 and NUTS3 totals must equal NUTS0 totals" = all(checks$match))

  wb_save(wb, path)
  invisible(path)
}

#' Compare the regional totals with the national totals.
#'
#' @param regional Table from `to_nuts_levels()`.
#' @param tables List of tables, each with a `metrics` vector (column = label).
#' @param tolerance Largest accepted absolute difference.
#' @return One row per table, metric, year and level (NUTS2, NUTS3).
results_checks <- function(regional, tables, tolerance = 1e-6) {
  totals <- regional |>
    pivot_longer(-c(level, nuts_id, name, geo, year), names_to = "column") |>
    summarise(total = sum(value, na.rm = TRUE), .by = c(level, year, column)) |>
    pivot_wider(names_from = level, values_from = total)

  purrr::imap(tables, \(tab, nm) {
    tibble(table = nm, column = names(tab$metrics), metric = unname(tab$metrics))
  }) |>
    bind_rows() |>
    inner_join(totals, by = "column", relationship = "many-to-many") |>
    pivot_longer(c(NUTS2, NUTS3), names_to = "level", values_to = "regional_total") |>
    transmute(
      table, metric, year, level,
      national_total = NUTS0,
      regional_total,
      difference = regional_total - national_total,
      match = abs(difference) <= tolerance * pmax(1, abs(national_total))
    ) |>
    arrange(table, metric, level, year)
}
