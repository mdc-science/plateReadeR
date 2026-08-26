#### Quick check: preview raw signal intensity from a plate-reader export ####
#
# Reads a raw plate-reader export directly — no exp_metadata or assay_metadata
# needed — and plots per-well signal intensity in plate format, one facet per
# wavelength (or per excitation/emission pair, for a SpectraMax fluorescence
# multi-channel export). A fast way to sanity-check a raw file (did the reader
# actually read this plate, are the values in a sane range, which wells look
# empty) before writing exp_metadata/assay_metadata and running the full
# pipeline. Also exports the tidied values as long- and wide-format CSVs.
#
# Accepts the same two raw-file families the process_*.R scripts do:
#  - SpectraMax SDA export (.csv, .xls, .txt) — same parsing as
#    process_spectramax_endpoint_std_curve.R, reused verbatim (read-mode and
#    wavelength-list auto-detection, XLS/TXT vs. CSV row-offset handling).
#    Fluorescence exports additionally get their excitation wavelength(s)
#    (row 2, col 21) alongside the emission wavelength(s) (col 17) when that
#    column parses as a same-length wavelength list, for a proper "558ex/
#    608em"-style facet label; otherwise falls back to an emission-only label
#    ("608em") — this excitation-column convention is less validated than the
#    col16/17 absorbance/fluorescence logic already proven in the main
#    engines, so it degrades gracefully rather than erroring.
#  - Generic long/plate .xlsx — same auto-detection as
#    process_generic_excel_endpoint_std_curve.R (A1 == "well" → long; one
#    8x12-grid sheet per wavelength otherwise). A genuine BioTek Synergy 2
#    .xlsx export is NOT one of the two formats this script understands —
#    only SpectraMax and the generic long/plate .xlsx are supported here.
#
# Define before sourcing, e.g.:
#   datafile <- "YYYY.MM.DD_raw_export.csv"   # SpectraMax .csv/.xls/.txt ...
#   datafile <- "YYYY.MM.DD_raw_data.xlsx"    # ... or a generic long/plate .xlsx
#
# source(here("quick_preview_signal_intensity.R"))

library(conflicted)
library(here)
library(tidyverse)
library(scales)
library(ggforce)
library(ggthemes)
library(readxl)

conflicts_prefer(here::here, dplyr::filter)

#### Utility functions ####
extract_data <- function(row, col) df_raw_sda[row, col]

generate_positions <- function() {
  positions <- expand.grid(row = LETTERS[1:8], col = 1:12)
  positions <- paste0(positions$row, positions$col)
  str_sort(positions, numeric = TRUE)
}

extract_wavelength <- function(x) {
  as.numeric(str_extract(trimws(as.character(x)), "[0-9.]+"))
}

# Parse a whitespace-separated list of wavelengths from one raw cell (see
# process_spectramax_endpoint_std_curve.R's comment on this same function for
# why the whole cell isn't as.numeric()'d directly).
parse_wavelengths <- function(x) {
  x |>
    as.character() |>
    trimws() |>
    str_split("\\s+", simplify = TRUE) |>
    as.numeric() |>
    (\(v) v[!is.na(v) & v > 0])()
}

file_ext      <- tolower(tools::file_ext(datafile))
is_generic_xlsx <- file_ext == "xlsx"
positions     <- generate_positions()

if (is_generic_xlsx) {

  #### Generic long/plate .xlsx — same format as process_generic_excel_endpoint_std_curve.R ####

  original_file <- datafile
  sheet_names   <- excel_sheets(here("experimental_data", "raw_data", datafile))

  first_cell <- read_excel(
    here("experimental_data", "raw_data", datafile),
    sheet = sheet_names[1], col_names = FALSE, n_max = 1
  )
  is_long_format <- !is.na(first_cell[[1, 1]]) &&
    tolower(trimws(as.character(first_cell[[1, 1]]))) == "well"

  if (is_long_format) {

    long_data <- read_excel(
      here("experimental_data", "raw_data", datafile),
      sheet = sheet_names[1]
    ) |>
      rename_with(~ tolower(trimws(.x))) |>
      mutate(
        well    = trimws(well),
        channel = as.character(extract_wavelength(wavelength)),
        signal  = as.numeric(signal)
      ) |>
      select(well, channel, signal)

    # Join per real channel (not a single blanket join across all wells) —
    # otherwise a well entirely absent from the sheet for every channel would
    # still fan out into one NA-channel row per omitted well, inflating the
    # apparent channel count with a channel that was never actually recorded.
    df_all_wl <- map(sort(unique(long_data$channel)), function(ch) {
      tibble(well = positions) |>
        left_join(long_data |> filter(channel == ch) |> select(well, signal), by = "well") |>
        mutate(channel = ch)
    }) |> bind_rows()

  } else {

    wavelength_list <- extract_wavelength(sheet_names)
    if (anyNA(wavelength_list)) {
      stop(
        "Plate-format sheet name(s) could not be parsed as a wavelength: ",
        paste(sheet_names[is.na(wavelength_list)], collapse = ", "),
        ". Rename each sheet to its wavelength (e.g. \"562\"), or set cell A1 ",
        "of the first sheet to \"well\" to use the long format instead."
      )
    }

    dataframes <- list()
    for (i in seq_along(sheet_names)) {
      wl   <- wavelength_list[i]
      grid <- read_excel(
        here("experimental_data", "raw_data", datafile),
        sheet = sheet_names[i], col_names = FALSE
      )

      if (nrow(grid) < 9 || ncol(grid) < 13) {
        stop(
          "Sheet \"", sheet_names[i], "\" is smaller than the expected 8x12 ",
          "plate grid (row letters A-H down column A, wells 1-12 across row 1, ",
          "data in B2:M9)."
        )
      }

      # Row-major flatten (A1..A12, B1..B12, ..., H1..H12) — see
      # CLAUDE.md's documented unlist()-column-major gotcha before touching this.
      signal <- unlist(lapply(2:9, function(r) as.numeric(unlist(grid[r, 2:13], use.names = FALSE))))

      dataframes[[i]] <- tibble(well = positions, channel = as.character(wl), signal = signal)
    }
    df_all_wl <- bind_rows(dataframes)

  }

} else {

  #### SpectraMax SDA export — same parsing as process_spectramax_endpoint_std_curve.R ####

  is_xls_fmt <- file_ext %in% c("xls", "txt")

  if (is_xls_fmt) {
    xls_con    <- file(here("experimental_data", "raw_data", datafile), encoding = "UTF-16LE")
    xls_lines  <- readLines(xls_con, skipNul = TRUE)
    close(xls_con)
    tmp_tsv    <- tempfile(fileext = ".tsv")
    writeLines(xls_lines, tmp_tsv)
    df_raw_sda <- read.table(
      tmp_tsv, sep = "\t", header = FALSE,
      fill = TRUE, stringsAsFactors = FALSE, quote = "", comment.char = ""
    )
    unlink(tmp_tsv)
  } else {
    df_raw_sda <- read_csv(
      here("experimental_data", "raw_data", datafile), col_names = FALSE
    )
  }

  end_row       <- which(df_raw_sda[[1]] == "~End")
  original_file <- strsplit(as.character(df_raw_sda[end_row + 1, 1]), ";")[[1]][1]

  sda_read_mode        <- as.character(df_raw_sda[2, 6]) |> trimws()
  is_fluorescence_read <- grepl("^Fluorescence$", sda_read_mode, ignore.case = TRUE)

  if (is_fluorescence_read) {
    em_list <- parse_wavelengths(df_raw_sda[2, 17])
    ex_list <- tryCatch(parse_wavelengths(df_raw_sda[2, 21]), error = function(e) numeric(0))

    wavelength_list <- em_list
    channel_labels  <- if (length(ex_list) == length(em_list) && length(ex_list) > 0) {
      setNames(paste0(ex_list, "ex/", em_list, "em"), em_list)
    } else {
      setNames(paste0(em_list, "em"), em_list)
    }
  } else {
    wl16_vals <- parse_wavelengths(df_raw_sda[2, 16])
    wl_col    <- if (length(wl16_vals) > 0 && all(wl16_vals >= 200)) 16L else 17L
    wavelength_list <- if (wl_col == 16L) wl16_vals else parse_wavelengths(df_raw_sda[2, 17])
    channel_labels  <- setNames(paste0(wavelength_list, " nm"), wavelength_list)
  }

  n_wl <- length(wavelength_list)
  dataframes <- list()
  for (wl in wavelength_list) {
    row <- if (is_xls_fmt) {
      n_wl * 2 + which(wavelength_list == wl) * 2 + 2
    } else {
      which(wavelength_list == wl) * 2 + 2
    }
    cols   <- 3:98
    signal <- sapply(cols, function(col) extract_data(row, col)) |> as.numeric()

    dataframes[[paste0("df_", wl)]] <- tibble(
      well    = positions,
      channel = channel_labels[[as.character(wl)]],
      signal  = signal
    )
  }
  df_all_wl <- bind_rows(dataframes)

}

#### Export tidied values ####

today       <- format(Sys.Date(), "%Y.%m.%d")
output_folder <- here("experimental_data", "processed_data", "signal_preview")
if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

write_csv(df_all_wl, here(output_folder, paste0(today, "_signal_long.csv")))

df_all_wl |>
  pivot_wider(names_from = channel, values_from = signal) |>
  write_csv(here(output_folder, paste0(today, "_signal_wide.csv")))

#### Plotting - Microplate view, one facet per channel ####

df_plot <- df_all_wl |>
  mutate(
    col = parse_number(well),
    row = str_replace_all(well, "[:digit:]", "")
  )
row_lookup   <- setNames(1:26, LETTERS)
df_plot$row  <- row_lookup[df_plot$row]

theme_plate_plot <- theme_few(base_size = 8) +
  theme(
    legend.position = "none",
    axis.text.x     = element_text(color = "black"),
    axis.text.y     = element_text(color = "black"),
    axis.title.x    = element_text(face = "bold"),
    axis.title.y    = element_text(face = "bold"),
    axis.line       = element_line(linewidth = 0.1),
    panel.border    = element_rect(color = "black", linewidth = 0.5),
    axis.ticks.length.x = unit(0.2, "mm"),
    axis.ticks.length.y = unit(0.2, "mm"),
    strip.text.x    = element_text(size = 9, face = "bold"),
    strip.background = element_rect(color = "black", fill = "gray85", linewidth = 0.5, linetype = "solid")
  )

# Auto-scale signal labels for readability (avoids 7+ digit numbers for fluorescence)
signal_mag    <- max(abs(df_plot$signal), na.rm = TRUE)
label_divisor <- dplyr::case_when(
  signal_mag >= 1e6 ~ 1e6,
  signal_mag >= 1e3 ~ 1e3,
  TRUE              ~ 1
)
label_suffix <- if (label_divisor > 1) paste0(" (values / ", prettyNum(label_divisor, big.mark = ","), ")") else ""

n_channels <- n_distinct(df_plot$channel)

p_plate_signal <- ggplot(df_plot) +
  geom_circle(
    aes(x0 = col, y0 = row, r = 0.45, fill = signal),
    alpha = 0.9, color = "gray35"
  ) +
  coord_equal() +
  scale_fill_gradient(low = "beige", high = "royalblue2", na.value = "white") +
  geom_text(
    aes(x = col, y = row,
        label = ifelse(!is.na(signal), formatC(signal / label_divisor, digits = 3, format = "g"), "")),
    size = 2
  ) +
  scale_x_continuous(breaks = 1:12, expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(
    breaks = 1:8, labels = LETTERS[1:8],
    expand = expansion(mult = c(0.01, 0.01)), trans = reverse_trans()
  ) +
  labs(
    title    = paste("Signal intensity preview", label_suffix),
    subtitle = NULL,
    x = "Column", y = "Row",
    caption  = original_file
  ) +
  theme_plate_plot +
  facet_wrap(~ channel, ncol = 2)

ggsave(
  here(output_folder, paste0(today, "_signal_intensity.pdf")),
  p_plate_signal,
  width  = if (n_channels == 1) 11 else 22,
  height = dplyr::case_when(
    n_channels %in% c(1, 2) ~ 8,
    n_channels %in% c(3, 4) ~ 16,
    TRUE                    ~ 24
  ),
  units = "cm", dpi = 600
)

message(sprintf(
  "%d channel(s) previewed: %s. Output in %s.",
  n_channels, paste(sort(unique(df_plot$channel)), collapse = ", "),
  output_folder
))
