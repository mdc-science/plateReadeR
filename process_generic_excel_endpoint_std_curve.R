#### Load necessary libraries ####
library(conflicted)
library(tidyverse)
library(scales)
library(patchwork)
library(here)
library(ggrepel)
library(RColorBrewer)
library(ggpmisc)
library(ggforce)
library(ggthemes)
library(readxl)

# NB: prefer ggpp::annotate, NOT ggplot2::annotate — ggpp's version (loaded
# via ggpmisc) is the one that understands the "text_npc" geom used by the
# CLoD/CLoQ annotate() calls below. Forcing ggplot2::annotate here silently
# breaks annotate("text_npc", ...) — no error, the label just never draws —
# which is why the CLoD/CLoQ text was missing from every rendered std-curve
# PDF this repo has ever produced. Found and fixed 2026-08-25; see
# CHANGELOG.md.
conflicts_prefer(here::here, dplyr::filter, ggpp::annotate)

#### Define utility functions ####
# Plot linear regression with confidence interval (se = TRUE)
geom_lm <- function(formula = y ~ x,
                    colour = alpha("black", 0.75),
                    linewidth = 0.25,
                    linetype = "dashed",
                    ...) {
  geom_smooth(
    formula = formula,
    method = "lm",
    se = TRUE,
    colour = colour,
    linewidth = linewidth,
    linetype = linetype,
    ...
  )
}

# Generate position labels for a 96-well plate
generate_positions <- function() {
  positions <- expand.grid(row = LETTERS[1:8], col = 1:12)
  positions <- paste0(positions$row, positions$col)
  str_sort(positions, numeric = TRUE)
}

# Extract a leading number from a string (e.g. "562 nm" or "562nm" -> 562)
extract_wavelength <- function(x) {
  as.numeric(str_extract(trimws(as.character(x)), "[0-9.]+"))
}

#### Import raw plate reader data ####
# Accepts a user-prepared .xlsx file in one of two formats, auto-detected from
# the first sheet's cell A1:
#
#  - Long format (A1 == "well"): a single sheet with columns `well`,
#    `wavelength`, `signal` — one row per well per wavelength. Wells can be
#    omitted (they're treated as blank/empty, same as an unused well on the
#    plate); a single-wavelength assay just repeats the same wavelength for
#    every row.
#
#  - Plate format (A1 is anything else): one sheet per wavelength, sheet name
#    = the wavelength (e.g. "562", "562nm"). Each sheet is an 8x12 grid:
#    row letters A-H down column A, well numbers 1-12 across row 1, signal
#    values in the block between (B2:M9). Multi-wavelength assays get one
#    sheet per wavelength, matching how most instrument software already
#    displays one grid per wavelength.
sheet_names <- excel_sheets(here("experimental_data", "raw_data", datafile))

first_cell <- read_excel(
  here("experimental_data", "raw_data", datafile),
  sheet = sheet_names[1], col_names = FALSE, n_max = 1
)
is_long_format <- !is.na(first_cell[[1, 1]]) &&
  tolower(trimws(as.character(first_cell[[1, 1]]))) == "well"

original_file <- datafile
positions <- generate_positions()
dataframes <- list()

if (is_long_format) {

  long_data <- read_excel(
    here("experimental_data", "raw_data", datafile),
    sheet = sheet_names[1]
  ) |>
    rename_with(~ tolower(trimws(.x)))

  required_cols <- c("well", "wavelength", "signal")
  missing_cols  <- setdiff(required_cols, names(long_data))
  if (length(missing_cols) > 0) {
    stop(
      "Long-format sheet is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      ". Expected columns: well, wavelength, signal."
    )
  }

  long_data <- long_data |>
    mutate(
      well       = trimws(well),
      wavelength = extract_wavelength(wavelength),
      signal     = as.numeric(signal)
    )

  wavelength_list <- sort(unique(long_data$wavelength))

  for (wl in wavelength_list) {
    df_name <- paste0("df_", wl)

    df <- tibble(well = positions) |>
      left_join(
        long_data |> filter(wavelength == wl) |> select(well, signal),
        by = "well"
      ) |>
      mutate(wavelength = wl) |>
      rename(absorbance = signal)

    dataframes[[df_name]] <- df
  }

} else {

  wavelength_list <- sort(extract_wavelength(sheet_names))
  if (anyNA(wavelength_list)) {
    stop(
      "Plate-format sheet name(s) could not be parsed as a wavelength: ",
      paste(sheet_names[is.na(extract_wavelength(sheet_names))], collapse = ", "),
      ". Rename each sheet to its wavelength (e.g. \"562\"), or set cell A1 ",
      "of the first sheet to \"well\" to use the long format instead."
    )
  }

  for (i in seq_along(sheet_names)) {
    wl      <- extract_wavelength(sheet_names[i])
    df_name <- paste0("df_", wl)

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

    row_labels <- trimws(toupper(as.character(grid[[1]][2:9])))
    col_labels <- suppressWarnings(as.numeric(trimws(as.character(unlist(grid[1, 2:13])))))
    if (!identical(row_labels, LETTERS[1:8]) || !identical(col_labels, as.numeric(1:12))) {
      stop(
        "Sheet \"", sheet_names[i], "\" doesn't match the expected plate layout: ",
        "column A (rows 2:9) must read A-H, and row 1 (columns B:M) must read 1-12."
      )
    }

    # Flatten row-major (A1..A12, B1..B12, ..., H1..H12) to match
    # generate_positions() — unlist() on a data.frame slice would flatten
    # column-major instead, so extract one plate row at a time.
    absorbance <- unlist(lapply(2:9, function(r) as.numeric(unlist(grid[r, 2:13], use.names = FALSE))))

    df <- tibble(
      well       = positions,
      wavelength = wl,
      absorbance = absorbance
    )

    dataframes[[df_name]] <- df
  }

}

# Optionally assign each wavelength df to global environment
for (df_name in names(dataframes)) {
  assign(df_name, dataframes[[df_name]])
}

# Combine all wavelength-specific data frames into one
df_all_wl <- bind_rows(dataframes, .id = "column_label")

# Clean up workspace
rm(df_name, first_cell, sheet_names)
if (exists("long_data")) rm(long_data)
if (exists("i")) rm(i, wl, grid, row_labels, col_labels, absorbance, df)

#### Import assay and experiment metadata ####

# Experiment metadata (sample IDs, dilutions, etc.)
exp_metadata_raw <- read_csv(here("experimental_data", "raw_data", exp_datafile),
                             locale = locale(encoding = "UTF-8"))

# Check for duplicate wells — each well must appear at most once
dup_wells <- exp_metadata_raw$well[duplicated(exp_metadata_raw$well)]
if (length(dup_wells) > 0) {
  stop(
    "Duplicate wells found in exp_metadata — please correct the file before proceeding.\n",
    "Duplicated wells: ", paste(unique(dup_wells), collapse = ", ")
  )
}

# Detect whether any sample wells are present
has_samples <- any(exp_metadata_raw$type == "sample", na.rm = TRUE)
has_smp_blk <- any(exp_metadata_raw$type == "smp_blk", na.rm = TRUE)

# Compute sample_dil_final = sample_dil * (std_vol / sample_vol)
if (has_samples) {
  std_vol <- exp_metadata_raw |>
    filter(type == "std", !is.na(volume)) |>
    pull(volume) |>
    unique() |>
    first()
} else {
  std_vol <- NA_real_
}

exp_metadata <- exp_metadata_raw |>
  mutate(
    suppress = if ("suppress" %in% names(exp_metadata_raw)) coalesce(as.logical(suppress), FALSE) else FALSE,
    sample_dil_final = case_when(
      type == "sample" & !is.na(sample_dil) & !is.na(volume) & is.na(sample_dil_final) ~
        sample_dil * (std_vol / volume),
      TRUE ~ sample_dil_final
    ),
    sample = ifelse(is.na(sample_dil), NA, paste(sample_ID, sample_dil, sep = "_"))
  ) |>
  group_by(sample, type) |>
  mutate(
    replica = ifelse(is.na(sample), "", paste0(sample, "_", volume, "_", row_number()))
  )

# Assay metadata (general protocol info)
assay_metadata <- read_csv(here(assay_datafile))

#### Extract metadata fields ####

# Assay metadata
var_name        <- assay_metadata$var_name
var_short       <- assay_metadata$var_short
var_abbr        <- assay_metadata$var_abbr
var_conc_unit   <- exp_metadata %>%
  filter(!is.na(std_conc_unit)) %>%
  pull(std_conc_unit) %>%
  unique()

read_type       <- assay_metadata$read_type             # Measurement type (absorbance/fluorescence/chemiluminescence)
signal_name     <- assay_metadata$signal_name           # Signal name (used as plot label)
signal_exp      <- assay_metadata$signal_expression     # Signal expression (math)
signal_formula  <- assay_metadata$signal_formula        # Column formula evaluated against corrected data

assay           <- assay_metadata$assay
std_mol_name    <- assay_metadata$std_mol_name
color_high      <- assay_metadata$color_high
color_low       <- assay_metadata$color_low

# Experiment metadata
exp_date        <- exp_metadata$date[1]
today           <- format(Sys.Date(), "%Y.%m.%d")
blank_wells     <- exp_metadata %>%
  filter(type == "blank") %>%
  pull(well)

#### Calculate mean signal of blank wells for each wavelength ####
mean_blank_abs <- setNames(numeric(length(wavelength_list)), wavelength_list)

if (length(blank_wells) == 0) {
  message("No blank wells found — skipping blank subtraction (mean_blank = 0).")
} else {
  for (wl in wavelength_list) {
    df_name    <- paste0("df_", wl)
    current_df <- dataframes[[df_name]]

    mean_abs <- current_df %>%
      filter(well %in% blank_wells) %>%
      summarize(mean = mean(absorbance, na.rm = TRUE)) %>%
      pull(mean)

    mean_blank_abs[as.character(wl)] <- mean_abs
  }
  rm(df_name, current_df, mean_abs)
}

#### Correct absorbance by blank values for each wavelength ####

for (df_name in names(dataframes)) {
  wl <- sub("df_", "", df_name)
  corrected_col <- paste0("A", wl)

  dataframes[[df_name]] <- dataframes[[df_name]] %>%
    select(well, absorbance) %>%
    rename(!!corrected_col := absorbance) %>%
    mutate(!!corrected_col := !!sym(corrected_col) - mean_blank_abs[wl])
}

for (df_name in names(dataframes)) {
  assign(df_name, dataframes[[df_name]])
}

rm(df_name)

# Merge all corrected data frames into one by well
df_signal <- reduce(dataframes, full_join, by = "well")

#### Calculate final signal based on formula from metadata ####
df_signal <- df_signal %>%
  mutate(signal = eval(parse(text = signal_formula)))

#### Merge signal with metadata and subset sample data ####

df <- df_signal %>%
  left_join(exp_metadata, by = "well")

# Report wells flagged for suppression — excluded from analysis, retained in plate view
suppressed_wells <- df |> filter(suppress == TRUE) |> pull(well)
if (length(suppressed_wells) > 0) {
  message(sprintf(
    "Suppressing %d well(s) from analysis: %s",
    length(suppressed_wells), paste(suppressed_wells, collapse = ", ")
  ))
}

# Subset sample wells; subtract paired sample-blank signal when smp_blk wells are present
if (has_smp_blk) {
  smp_blk_means <- df %>%
    filter(type == "smp_blk", !suppress) %>%
    group_by(sample_ID) %>%
    summarize(smp_blk_signal = mean(signal, na.rm = TRUE), .groups = "drop")

  df_samples <- df %>%
    filter(type == "sample", !suppress) %>%
    left_join(smp_blk_means, by = "sample_ID") %>%
    mutate(signal = signal - smp_blk_signal) %>%
    select(-smp_blk_signal)
} else {
  df_samples <- df %>%
    filter(type == "sample", !suppress)
}

n_samples <- n_distinct(df_samples$sample)

#### Subset standard curve data ####

df_std <- df %>%
  filter(type == "std", !suppress)

std_min_y <- df_std %>%
  filter(std_conc != 0) %>%
  filter(std_conc == min(std_conc, na.rm = TRUE)) %>%
  summarize(min = mean(signal, na.rm = TRUE)) %>%
  pull(min)

std_max_y <- df_std %>%
  filter(std_conc == max(std_conc, na.rm = TRUE)) %>%
  summarize(max = mean(signal, na.rm = TRUE)) %>%
  pull(max)

#### Build standard curve (concentration ~ signal) ####

std_curve <- lm(std_conc ~ signal, data = df_std)
summary(std_curve)

#### Compute Limit of Detection (LOD) and Calculated LOD (CLOD) ####

lm_lod <- lm(signal ~ std_conc, data = df_std)
lm_lod_summary <- summary(lm_lod)

intercept <- unname(coef(lm_lod)[1])
slope     <- unname(coef(lm_lod)[2])

sy_x <- sqrt(sum(lm_lod_summary$residuals^2) / lm_lod_summary$df[2])

yLOD <- (3 * sy_x) + intercept

CLOD     <- (yLOD - intercept) / slope
CLOD_alt <- (3 * sy_x) / slope

#### Compute Limit of Quantification (LOQ) ####

SN_ratio_LOQ <- 10

CLOQ <- (SN_ratio_LOQ * sy_x) / slope
yLOQ <- intercept + (SN_ratio_LOQ * sy_x)

#### Calculate analyte levels in sample wells (all back-calculated; out-of-range flagged) ####

if (has_samples) {

  min_threshold <- std_min_y * 1.1
  max_threshold <- std_max_y

  df_samples_calc <- df_samples %>%
    group_by(date, sample, sample_dil_final) %>%
    mutate(avg_signal = mean(signal, na.rm = TRUE)) %>%
    select(sample_ID, sample, sample_dil_final, sample_dil, avg_signal, source) %>%
    rename(signal = avg_signal) %>%
    distinct() %>%
    mutate(extrapolated = signal < min_threshold | signal > max_threshold) %>%
    arrange(sample) %>%
    ungroup() %>%
    mutate(value = predict(std_curve, newdata = .) * sample_dil_final)

  n_extrap <- sum(df_samples_calc$extrapolated, na.rm = TRUE)
  if (n_extrap > 0)
    message(sprintf(
      "%d sample(s) outside std curve range — back-calculated and flagged as extrapolated.",
      n_extrap
    ))

}

#### Plotting - Microplate View - Tidy well positions and set theme ####

df <- df %>%
  mutate(
    col = parse_number(well),
    row = str_replace_all(well, "[:digit:]", "")
  )

row_lookup <- setNames(1:26, LETTERS)
df$row <- row_lookup[df$row]

rm(row_lookup)

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
    axis.ticks.length.y = unit(0.2, "mm")
  )

#### Plotting - Microplate View - Plate map ####

color_count <- length(unique(na.omit(df$sample_ID)))

get_palette <- colorRampPalette(brewer.pal(9, "Spectral"))
colors <- get_palette(color_count)

p_plate_map <- ggplot(df) +
  geom_circle(
    aes(x0 = col, y0 = row, r = 0.45, fill = sample_ID),
    alpha = 0.85, color = "gray35"
  ) +
  coord_equal() +
  scale_fill_manual(values = colors, na.value = "gray85") +
  geom_text(
    aes(x = col, y = row, label = ifelse(is.na(label), "", label)),
    size = 2
  ) +
  scale_x_continuous(
    breaks = 1:12,
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    breaks = 1:8,
    labels = LETTERS[1:8],
    expand = expansion(mult = c(0.01, 0.01)),
    trans = reverse_trans()
  ) +
  labs(
    title    = paste(assay, "assay"),
    subtitle = paste(exp_date, "- Plate map"),
    x        = "Column",
    y        = "Row"
  ) +
  theme_plate_plot

#### Save microplate plot to file ####

output_folder <- here("experimental_data", "processed_data", var_short)

if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}

ggsave(
  filename = file.path(output_folder, paste(exp_date, var_abbr, "plate_map.pdf", sep = "_")),
  plot     = p_plate_map,
  width    = 11,
  height   = 8,
  units    = "cm",
  dpi      = 300
)

#### Plotting - Microplate View - Signal intensity per well ####

df_plate_signal <- df %>%
  mutate(signal = ifelse(is.na(label) | type == "blank", NA, signal))

# Auto-scale signal labels for readability (avoids 7+ digit numbers for fluorescence)
signal_mag    <- max(abs(df_plate_signal$signal), na.rm = TRUE)
label_divisor <- dplyr::case_when(
  signal_mag >= 1e6 ~ 1e6,
  signal_mag >= 1e3 ~ 1e3,
  TRUE              ~ 1
)
label_suffix <- if (label_divisor > 1)
  paste0(" / ", prettyNum(label_divisor, big.mark = ",")) else ""

p_plate_signal <- ggplot(df_plate_signal) +
  geom_circle(
    aes(x0 = col, y0 = row, r = 0.45, fill = signal),
    alpha = 0.9, color = "gray35"
  ) +
  coord_equal() +
  scale_fill_gradient(
    low = color_low,
    high = color_high,
    na.value = "white"
  ) +
  geom_text(
    aes(
      x = col,
      y = row,
      label = ifelse(!is.na(label) & !is.na(signal),
                     formatC(signal / label_divisor, digits = 3, format = "g"),
                     "")
    ),
    size = 2
  ) +
  scale_x_continuous(
    breaks = 1:12,
    expand = expansion(mult = c(0.01, 0.01))
  ) +
  scale_y_continuous(
    breaks = 1:8,
    labels = LETTERS[1:8],
    expand = expansion(mult = c(0.01, 0.01)),
    trans = reverse_trans()
  ) +
  labs(
    title    = paste(assay, "assay"),
    subtitle = paste0(exp_date, " - ", signal_name, label_suffix),
    x        = "Column",
    y        = "Row"
  ) +
  theme_plate_plot

#### Plotting - Standard curve ####

theme_std_curve <- theme_few(base_size = 8) +
  theme(
    legend.position     = "none",
    axis.text.x         = element_text(color = "gray15"),
    axis.text.y         = element_text(color = "gray15"),
    axis.title.x        = element_text(face = "bold"),
    axis.title.y        = element_text(face = "bold"),
    axis.line           = element_line(linewidth = 0),
    panel.border        = element_rect(linewidth = 0.4, color = "gray15"),
    axis.ticks.length.x = unit(0.5, "mm"),
    axis.ticks.length.y = unit(0.5, "mm")
  )

df_std_avg <- df_std %>%
  group_by(std_conc) %>%
  summarise(
    signal = mean(signal, na.rm = TRUE),
    .groups = "drop"
  )

lm_std_avg <- lm(signal ~ std_conc, data = df_std_avg)

p_std_curve <- ggplot(df_std, aes(x = std_conc, y = signal)) +
  geom_smooth(
    data = df_std_avg,
    aes(x = std_conc, y = signal),
    formula = y ~ x,
    method = "lm",
    se = TRUE,
    colour = alpha("black", 0.75),
    linewidth = 0.25,
    linetype = "dashed",
    fill = "gray85",
    inherit.aes = FALSE
  ) +
  geom_point(
    aes(fill = signal),
    shape = 21,
    size = 4,
    stroke = 0.25,
    alpha = 0.75,
    color = "black"
  ) +
  scale_fill_gradient(low = color_low, high = color_high) +
  stat_poly_eq(
    data      = df_std_avg,
    formula   = y ~ x,
    geom      = "text_npc",
    aes(x = std_conc, y = signal, label = after_stat(rr.label)),
    label.y   = 0.95,
    size      = 5,
    vjust     = 0.5,
    rr.digits = 4,
    inherit.aes = FALSE
  ) +
  stat_poly_eq(
    data      = df_std_avg,
    formula   = y ~ x,
    geom      = "text_npc",
    aes(x = std_conc, y = signal, label = after_stat(eq.label)),
    label.y   = 0.05,
    label.x   = 0.95,
    size      = 5,
    vjust     = 0.5,
    inherit.aes = FALSE
  ) +
  annotate(
    "text_npc", npcx = 0.05, npcy = 0.88,
    label = paste("CLoD =", round(CLOD, 4), var_conc_unit),
    check_overlap = TRUE, size = 5, vjust = 0.5
  ) +
  annotate(
    "text_npc", npcx = 0.05, npcy = 0.81,
    label = paste("CLoQ =", round(CLOQ, 4), var_conc_unit),
    check_overlap = TRUE, size = 5, vjust = 0.5
  ) +
  labs(
    title    = paste(assay, "assay"),
    subtitle = paste0(exp_date, " - Standard curve"),
    x        = paste0(std_mol_name, " (", var_conc_unit, ")"),
    y        = parse(text = signal_exp)
  ) +
  theme_std_curve

#### Plotting - Sample raw data and calculated values (only when samples present) ####

if (has_samples) {

  # Suppressed sample wells — plotted as annotation only, excluded from analysis
  df_samples_suppressed <- df |>
    filter(type == "sample", suppress == TRUE)

  # Flag triplicate outliers: replicate deviating > threshold from group mean
  triplicate_flag_thr <- 0.05

  df_samples_flagged <- df_samples |>
    group_by(sample) |>
    mutate(
      n_rep                 = n(),
      mean_sig              = mean(signal, na.rm = TRUE),
      is_triplicate_outlier = n_rep == 3 &
                              !is.na(signal) &
                              abs(signal - mean_sig) / abs(mean_sig) > triplicate_flag_thr
    ) |>
    ungroup()

  p_sample_raw <- ggplot(df_samples_flagged, aes(x = sample, y = signal)) +
    geom_point(
      aes(fill = signal),
      shape = 21, size = 2.5, stroke = 0.25, alpha = 1, color = "black"
    ) +
    scale_fill_gradient(low = color_low, high = color_high) +
    geom_point(
      data = subset(df_samples_flagged, signal < yLOD | signal > std_max_y),
      shape = 21, size = 2.5, stroke = 0.25,
      fill = "gray85", color = "gray85", alpha = 1
    ) +
    geom_point(
      data = filter(df_samples_flagged, is_triplicate_outlier),
      shape = 21, size = 4.5, stroke = 0.6,
      fill = NA, color = "darkorange2", alpha = 1
    ) +
    geom_point(
      data  = df_samples_suppressed,
      shape = 4, size = 3, stroke = 0.8,
      color = "firebrick"
    ) +
    geom_text_repel(
      data  = df_samples_suppressed,
      aes(label = well),
      size  = 2, color = "firebrick",
      min.segment.length = 0
    ) +
    geom_hline(yintercept = c(std_max_y, std_min_y),
               linetype = "dashed", linewidth = 0.25, alpha = 0.5) +
    geom_hline(yintercept = yLOD,
               linetype = "dashed", linewidth = 0.25, color = "firebrick") +
    geom_hline(yintercept = yLOQ,
               linetype = "dashed", linewidth = 0.25, color = "royalblue4") +
    annotate("text", x = 0.5, y = yLOD, label = "Linear LoD",
             hjust = 0, vjust = -0.5, color = "firebrick", size = 2,
             check_overlap = TRUE) +
    annotate("text", x = 0.5, y = yLOQ, label = "Linear LoQ",
             hjust = 0, vjust = -0.5, color = "royalblue4", size = 2,
             check_overlap = TRUE) +
    labs(
      title    = paste(assay, "assay"),
      subtitle = paste(exp_date, "- Samples raw data"),
      x = "Sample", y = signal_name
    ) +
    theme_std_curve +
    theme(axis.text.x = element_text(angle = 90, hjust = 0.5, vjust = 0.5))

  y_min    <- floor(min(df_samples_calc$value, na.rm = TRUE) / 0.5) * 0.5
  y_max    <- ceiling(max(df_samples_calc$value, na.rm = TRUE) / 0.5) * 0.5
  y_breaks <- seq(y_min, y_max, length.out = 5)

  p_calc_value <-
    ggplot(df_samples_calc, aes(x = fct_reorder(sample_ID, value, .fun = mean), y = value, fill = value)) +
    geom_point(color = "black", size = 2.5, shape = 21, alpha = 0.85, stroke = 0.25) +
    scale_fill_gradient(low = "royalblue", high = "tomato") +
    scale_y_continuous(limits = c(y_min, y_max), breaks = y_breaks) +
    stat_summary(fun = mean, geom = "point", shape = 23, size = 2,
                 alpha = 0.5, color = "gray15", fill = "gold",
                 position = position_nudge(x = 0.15, y = 0)) +
    geom_point(
      data  = filter(df_samples_calc, extrapolated),
      shape = 24, size = 3, stroke = 0.7, fill = "orange", color = "darkorange"
    ) +
    geom_text_repel(
      data  = filter(df_samples_calc, extrapolated),
      aes(label = sample_ID),
      size  = 2, color = "darkorange", min.segment.length = 0
    ) +
    labs(
      title    = paste(assay, "assay"),
      subtitle = paste(exp_date, "-", var_short, "values across samples"),
      x = "Sample", y = paste0(var_short, " (", var_conc_unit, ")")
    ) +
    theme_std_curve +
    theme(
      legend.position = "none",
      axis.text.x     = element_text(angle = 90, hjust = 1, vjust = 0.5)
    )

  #### Saving calculated data ####
  df_samples_calc_final <-
    df_samples_calc %>%
    group_by(date, sample_ID, extrapolated, source) %>%
    summarize(value = mean(value, na.rm = TRUE), .groups = "drop") %>%
    mutate(var = var_abbr, value_unit = var_conc_unit) %>%
    select(sample_ID, var, value, value_unit, extrapolated, source)

  write_csv(
    df_samples_calc_final,
    here(output_folder, paste(exp_date, var_abbr, "levels.csv", sep = "_"))
  )

}

#### Making summary display ####

remove_titles <- function(p) p + labs(title = NULL, subtitle = NULL)

if (has_samples) {
  summary_layout <- "
AB
CC
DE
"
  p_summary <-
    remove_titles(p_plate_map) +
    remove_titles(p_plate_signal) +
    remove_titles(p_sample_raw) +
    remove_titles(p_std_curve) +
    remove_titles(p_calc_value) +
    plot_layout(design = summary_layout) +
    plot_annotation(
      title    = paste0(var_name, " - ", assay, " assay"),
      subtitle = paste(exp_date, "Summary results", sep = " - "),
      caption  = original_file
    )
  pdf_height <- 30
} else {
  summary_layout <- "
AB
CC
"
  p_summary <-
    remove_titles(p_plate_map) +
    remove_titles(p_plate_signal) +
    remove_titles(p_std_curve) +
    plot_layout(design = summary_layout) +
    plot_annotation(
      title    = paste0(var_name, " - ", assay, " assay"),
      subtitle = paste(exp_date, "Standard curve only", sep = " - "),
      caption  = original_file
    )
  pdf_height <- 20
}

ggsave(
  here(output_folder, paste(exp_date, var_abbr, "summary_results.pdf", sep = "_")),
  p_summary,
  width = 22, height = pdf_height, units = "cm", dpi = 600
)

#### Storing Analytical Performance Data ####

df_anal_per <- data.frame(
  date = exp_date,
  var = var_abbr,
  LOD_conc = CLOD,
  LOQ_conc = CLOQ,
  regression_slope = slope,
  regression_intercept = intercept,
  r_squared_adj = lm_lod_summary$adj.r.squared
)

# Saved alongside the other per-run outputs (plate map, summary PDF, levels CSV)
# in experimental_data/processed_data/{var_short}/, keeping all outputs inside
# the experiment folder rather than a machine-specific external registry.
write_csv(
  df_anal_per,
  file = file.path(output_folder, paste(exp_date, var_abbr, "analytical_performance.csv", sep = "_"))
)
