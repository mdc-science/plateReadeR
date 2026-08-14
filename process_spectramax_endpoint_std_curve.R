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

conflicts_prefer(here::here, dplyr::filter, ggplot2::annotate)

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

# Extract a specific cell from df_raw_sda
extract_data <- function(row, col) {
  df_raw_sda[row, col]
}

# Generate position labels for a 96-well plate
generate_positions <- function() {
  positions <- expand.grid(row = LETTERS[1:8], col = 1:12)
  positions <- paste0(positions$row, positions$col)
  str_sort(positions, numeric = TRUE)
}

#### Import raw plate reader data ####
# Auto-detect file format: SpectraMax .xls and .txt exports are UTF-16LE tab-delimited;
# .csv exports are comma-delimited UTF-8.
file_ext   <- tolower(tools::file_ext(datafile))
is_xls_fmt <- file_ext %in% c("xls", "xlsx", "txt")

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

# Detect read mode from the plate header (col 6: "Absorbance" or "Fluorescence")
sda_read_mode <- as.character(df_raw_sda[2, 6]) |> trimws()
is_fluorescence_read <- grepl("^Fluorescence$", sda_read_mode, ignore.case = TRUE)

# Extract the measurement wavelength(s).
# Absorbance exports store the wavelength(s) at row 2, col 16 — as a single
# value for one wavelength (e.g. "562") or space-separated for several (e.g.
# "590 450"). Fluorescence exports store a small integer flag (e.g. "1") at
# col 16 and the emission wavelength at col 17. Parse col 16 as a
# whitespace-separated list first (rather than as.numeric()'ing the whole
# cell, which returns NA — and so silently mis-detects the fallback column —
# as soon as col 16 holds more than one wavelength); use it if every parsed
# value is a plausible wavelength (≥ 200 nm), otherwise fall back to col 17.
parse_wavelengths <- function(x) {
  x |>
    as.character() |>
    trimws() |>
    str_split("\\s+", simplify = TRUE) |>
    as.numeric() |>
    (\(v) v[!is.na(v) & v > 0])()
}

wl16_vals <- parse_wavelengths(df_raw_sda[2, 16])
wl_col <- if (length(wl16_vals) > 0 && all(wl16_vals >= 200)) 16L else 17L

wavelength_list <- if (wl_col == 16L) wl16_vals else parse_wavelengths(df_raw_sda[2, 17])

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
# std_vol: volume loaded per well for standards (from std rows); sample_vol: per-sample volume
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
var_name        <- assay_metadata$var_name              # Full variable name
var_short       <- assay_metadata$var_short             # Short label
var_abbr        <- assay_metadata$var_abbr              # Abbreviation
var_conc_unit   <- exp_metadata %>% 
  filter(!is.na(std_conc_unit)) %>%
  pull(std_conc_unit) %>%
  unique()                                               # Concentration unit

read_type       <- assay_metadata$read_type             # Measurement type (absorbance/fluorescence/chemiluminescence)
signal_name     <- assay_metadata$signal_name           # Signal name (used as plot label)
signal_exp      <- assay_metadata$signal_expression     # Signal expression (math)
signal_formula  <- assay_metadata$signal_formula        # Column formula evaluated against corrected data

assay           <- assay_metadata$assay                 # Assay name
std_mol_name    <- assay_metadata$std_mol_name          # Standard molecule name
color_high      <- assay_metadata$color_high            # Plotting color (high)
color_low       <- assay_metadata$color_low             # Plotting color (low)

# Experiment metadata
exp_date        <- exp_metadata$date[1]                 # Date of experiment
today           <- format(Sys.Date(), "%Y.%m.%d")       # Today's date
blank_wells     <- exp_metadata %>%
  filter(type == "blank") %>%
  pull(well)                                            # Blank well positions

# Extract original filename from raw SDA file
end_row         <- which(df_raw_sda[[1]] == "~End")
original_file <- strsplit(as.character(df_raw_sda[end_row + 1, 1]), ";")[[1]][1]

#### Extract absorbance data into a list of data frames (one per wavelength) ####

# Initialize empty list to store wavelength-specific data frames
dataframes <- list()

# Loop through each wavelength and extract absorbance values
n_wl <- length(wavelength_list)

for (wl in wavelength_list) {
  df_name <- paste0("df_", wl)
  if (is_xls_fmt) {
    # XLS: use second data block (dot-decimal); offset by first block (n_wl header+data pairs).
    # read.table(blank.lines.skip = TRUE) drops any empty rows between blocks, so the offset
    # is always 2 regardless of read type (absorbance or fluorescence).
    row <- n_wl * 2 + which(wavelength_list == wl) * 2 + 2
  } else {
    row <- which(wavelength_list == wl) * 2 + 2         # CSV: 2 rows per wavelength, starting at line 3
  }
  cols <- 3:98                                           # Softmax: data in cols 3 to 98
  positions <- generate_positions()
  
  absorbance <- sapply(cols, function(col) extract_data(row, col)) %>%
    as.numeric()
  
  df <- tibble(
    well       = positions,
    wavelength = wl,
    absorbance = absorbance
  )
  
  dataframes[[df_name]] <- df
}

# Optionally assign each wavelength df to global environment (if needed)
for (df_name in names(dataframes)) {
  assign(df_name, dataframes[[df_name]])
}

# Combine all wavelength-specific data frames into one
df_all_wl <- bind_rows(dataframes, .id = "column_label")

# Clean up workspace
rm(absorbance, df, df_name, row, cols, wl, positions, end_row)

#### Calculate mean signal of blank wells for each wavelength ####
mean_blank_abs <- setNames(numeric(length(wavelength_list)), wavelength_list)

if (length(blank_wells) == 0) {
  message("No blank wells found — skipping blank subtraction (mean_blank = 0).")
} else {
  for (wl in wavelength_list) {
    df_name    <- paste0("df_", wl)
    current_df <- dataframes[[df_name]]

    mean_abs   <- current_df %>%
      filter(well %in% blank_wells) %>%
      summarize(mean = mean(absorbance, na.rm = TRUE)) %>%
      pull(mean)

    mean_blank_abs[as.character(wl)] <- mean_abs
  }
  rm(df_name, current_df, mean_abs)
}

#### Correct absorbance by blank values for each wavelength ####

# Loop through each data frame and subtract mean blank absorbance
for (df_name in names(dataframes)) {
  wl <- sub("df_", "", df_name)  # Extract wavelength
  corrected_col <- paste0("A", wl)
  
  dataframes[[df_name]] <- dataframes[[df_name]] %>%
    select(well, absorbance) %>%
    rename(!!corrected_col := absorbance) %>%  # Rename absorbance column to A{wl}
    mutate(!!corrected_col := !!sym(corrected_col) - mean_blank_abs[wl])  # Subtract blank
}

# Optionally assign corrected data frames to global environment
for (df_name in names(dataframes)) {
  assign(df_name, dataframes[[df_name]])
}

# Clean up temporary variable
rm(df_name)

# Merge all corrected data frames into one by well
df_signal <- reduce(dataframes, full_join, by = "well")

#### Calculate final signal based on formula from metadata ####
df_signal <- df_signal %>%
  mutate(signal = eval(parse(text = signal_formula)))

#### Merge signal with metadata and subset sample data ####

# Combine signal values with experimental metadata by well
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

# Count number of unique samples (useful for dynamic plotting)
n_samples <- n_distinct(df_samples$sample)

#### Subset standard curve data ####

df_std <- df %>%
  filter(type == "std", !suppress)  # Standard curve wells

# Mean signal for lowest non-zero standard concentration
std_min_y <- df_std %>%
  filter(std_conc != 0) %>%
  filter(std_conc == min(std_conc, na.rm = TRUE)) %>%
  summarize(min = mean(signal, na.rm = TRUE)) %>%
  pull(min)

# Mean signal for highest standard concentration
std_max_y <- df_std %>%
  filter(std_conc == max(std_conc, na.rm = TRUE)) %>%
  summarize(max = mean(signal, na.rm = TRUE)) %>%
  pull(max)

#### Build standard curve (concentration ~ signal) ####

std_curve <- lm(std_conc ~ signal, data = df_std)
summary(std_curve)

#### Compute Limit of Detection (LOD) and Calculated LOD (CLOD) ####

# Inverse regression for LOD (signal ~ concentration)
lm_lod <- lm(signal ~ std_conc, data = df_std)
lm_lod_summary <- summary(lm_lod)

# Extract coefficients
intercept <- unname(coef(lm_lod)[1])  # a
slope     <- unname(coef(lm_lod)[2])  # b

# Standard error of estimate (sy/x)
sy_x <- sqrt(sum(lm_lod_summary$residuals^2) / lm_lod_summary$df[2])

# LOD on the y-axis: 3 × residual error + intercept
yLOD <- (3 * sy_x) + intercept

# Calculated LOD (CLOD) on the concentration axis:
# Option 1 — Using regression formula:
CLOD <- (yLOD - intercept) / slope

# Option 2 — Equivalent direct shortcut (rearranged formula):
CLOD_alt <- (3 * sy_x) / slope

#### Compute Limit of Quantification (LOQ) for the linear model ####

# Set signal-to-noise threshold (usually S/N ≥ 10 for LOQ)
SN_ratio_LOQ <- 10

# Compute LOQ on the x-axis (concentration axis)
CLOQ <- (SN_ratio_LOQ * sy_x) / slope

# Compute LOQ on the y-axis (signal axis)
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

# Convert 'well' to row (letter) and column (number)
df <- df %>%
  mutate(
    col = parse_number(well),
    row = str_replace_all(well, "[:digit:]", "")
  )

# Create lookup to convert row letters to numeric positions (A=1, B=2, ...)
row_lookup <- setNames(1:26, LETTERS)
df$row <- row_lookup[df$row]

# Clean up
rm(row_lookup)

# Define ggplot2 theme for microplate visualization
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

# Count unique sample IDs to determine color palette size
color_count <- length(unique(na.omit(df$sample_ID)))

# Generate color palette from "Spectral"
get_palette <- colorRampPalette(brewer.pal(9, "Spectral"))
colors <- get_palette(color_count)

# Create plate map
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

# Define output folder path
output_folder <- here("experimental_data",  "processed_data", var_short)

# Create the folder if it doesn't exist
if (!dir.exists(output_folder)) {
  dir.create(output_folder, recursive = TRUE)
}

# Save the plot
ggsave(
  filename = file.path(output_folder, paste(exp_date, var_abbr, "plate_map.pdf", sep = "_")),
  plot     = p_plate_map,
  width    = 11,
  height   = 8,
  units    = "cm",
  dpi      = 300
)

#### Plotting - Microplate View - Signal intensity per well ####

# Prepare data for microplate signal intensity plot 
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

# Create plate plot showing signal intensity per well
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

# Define theme for standard curve
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

#### Average standard replicates for regression statistics ####
df_std_avg <- df_std %>%
  group_by(std_conc) %>%
  summarise(
    signal = mean(signal, na.rm = TRUE),
    .groups = "drop"
  )

#### Linear models ####
# for displaying equation and R2
lm_std_avg <- lm(signal ~ std_conc, data = df_std_avg)


# Plot standard curve
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
  # Full layout: plate map | plate signal / sample raw (full width) / std curve | calc values
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
  # Standards-only layout: plate map | plate signal / std curve (full width)
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

# Create a summary dataframe
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
