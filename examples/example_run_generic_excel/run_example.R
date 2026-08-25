#### Runnable example: user-prepared Excel input (any instrument) ####
#
# All values in this example are fabricated for demonstration only — they are
# NOT real experimental data. Open GenericExcel_example.Rproj in RStudio first
# (or run `Rscript run_example.R` from this folder) so here::here() resolves
# correctly.
#
# process_generic_excel_endpoint_std_curve.R accepts a plain .xlsx file
# instead of an instrument-specific export, so it works with data copy-pasted
# from any plate reader's own software. It auto-detects one of two formats
# from the first sheet's cell A1:
#
#   - Long format  (2026.06.18_ELISA_long_raw.xlsx):  A1 == "well". A single
#     sheet with columns well/wavelength/signal, one row per well per
#     wavelength.
#   - Plate format (2026.06.19_ELISA_plate_raw.xlsx): A1 is anything else. One
#     sheet per wavelength (sheet name = the wavelength), each an 8x12 grid
#     (row letters A-H down column A, wells 1-12 across row 1).
#
# Both files encode the *same* fabricated generic-ELISA two-wavelength assay
# (signal_formula = "A450 - A570": a real ELISA convention where 450nm is the
# analyte signal and 570nm is a reference read subtracted to correct for
# plate-optical imperfections — a genuine two-wavelength formula, so this
# actually exercises multi-wavelength handling in both formats, not just a
# trivial single-wavelength case) — run both below and compare
# df_samples_calc_final: they should back-calculate to the same values,
# since it's the same underlying data in two different shapes.

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

conflicts_prefer(here::here, dplyr::filter, ggplot2::annotate)

assay_datafile <- here("..", "ELISA_assay_metadata.csv")

#### Run 1: long format ####
datafile     <- "2026.06.18_ELISA_long_raw.xlsx"
exp_datafile <- "2026.06.18_ELISA_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results_long <- df_samples_calc_final
print(results_long)

#### Run 2: plate format ####
datafile     <- "2026.06.19_ELISA_plate_raw.xlsx"
exp_datafile <- "2026.06.19_ELISA_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results_plate <- df_samples_calc_final
print(results_plate)

#### Both formats should back-calculate to (approximately) the same values ####
stopifnot(all.equal(results_long$value, results_plate$value, tolerance = 1e-6))
message("Long format and plate format agree.")
