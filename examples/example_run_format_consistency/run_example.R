#### Consistency check: same data, four raw-file formats, one result ####
#
# This is the audit example: it proves that this workflow produces the same
# back-calculated concentrations regardless of which raw-file format the data
# arrives in, and regardless of whether the assay uses one wavelength or two.
#
# Two canonical datasets, each re-encoded into all four supported formats:
#
#   Dataset A - BCA, single wavelength (A562). REAL data (the same values
#   committed in examples/example_run/'s Synergy 2 export):
#     - 2026.06.15_BCA_synergy2.xlsx        (process_synergy2_endpoint_std_curve.R)
#     - 2026.06.16_BCA_spectramax.csv       (process_spectramax_endpoint_std_curve.R)
#     - 2026.06.17_BCA_generic_long.xlsx    (process_generic_excel_endpoint_std_curve.R, long)
#     - 2026.06.18_BCA_generic_plate.xlsx   (process_generic_excel_endpoint_std_curve.R, plate)
#
#   Dataset B - ABTS, two wavelengths (A412 - A700, subtraction formula).
#   Fabricated data (the same values committed in
#   examples/example_run_generic_excel/):
#     - 2026.06.20_ABTS_generic_long.xlsx   (process_generic_excel_endpoint_std_curve.R, long)
#     - 2026.06.21_ABTS_generic_plate.xlsx  (process_generic_excel_endpoint_std_curve.R, plate)
#     - 2026.06.22_ABTS_spectramax.csv      (process_spectramax_endpoint_std_curve.R)
#
# Dataset B deliberately has no Synergy2 leg. A multi-wavelength Synergy2 raw
# file would have to be constructed purely by reading
# process_synergy2_endpoint_std_curve.R's own parsing logic backwards - there
# is no real multi-wavelength Synergy2 export to check that structure
# against (unlike SpectraMax's CSV format below, which was cross-checked
# against the real Bradford file used in example_run_bradford_legacy/, and
# the generic-excel formats, which this repo defines itself so there's no
# real-world fidelity question). Testing against a guessed layout would only
# prove the parser agrees with itself, not that it handles real Synergy2
# multi-wavelength data correctly - see the "Known issues / gotchas" section
# of this workflow's CLAUDE.md.
#
# The SpectraMax CSV encodings of both datasets, and Dataset A's Synergy2
# encoding, were built by extracting the exact underlying values from the
# already-committed real/fabricated files referenced above (not retyped), so
# this is a genuine like-for-like comparison, not independently-fabricated
# approximations of the same idea.

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

results <- list()

#### Dataset A: BCA, single wavelength ####

assay_datafile <- here("..", "BCA_assay_metadata.csv")

datafile     <- "2026.06.15_BCA_synergy2.xlsx"
exp_datafile <- "2026.06.15_BCA_exp_metadata.csv"
source(here("..", "..", "process_synergy2_endpoint_std_curve.R"))
results$A_synergy2 <- df_samples_calc_final |> arrange(sample_ID)

datafile     <- "2026.06.16_BCA_spectramax.csv"
exp_datafile <- "2026.06.16_BCA_exp_metadata.csv"
source(here("..", "..", "process_spectramax_endpoint_std_curve.R"))
results$A_spectramax <- df_samples_calc_final |> arrange(sample_ID)

datafile     <- "2026.06.17_BCA_generic_long.xlsx"
exp_datafile <- "2026.06.17_BCA_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results$A_generic_long <- df_samples_calc_final |> arrange(sample_ID)

datafile     <- "2026.06.18_BCA_generic_plate.xlsx"
exp_datafile <- "2026.06.18_BCA_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results$A_generic_plate <- df_samples_calc_final |> arrange(sample_ID)

#### Dataset B: ABTS, two wavelengths ####

assay_datafile <- here("..", "ABTS_assay_metadata.csv")

datafile     <- "2026.06.20_ABTS_generic_long.xlsx"
exp_datafile <- "2026.06.20_ABTS_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results$B_generic_long <- df_samples_calc_final |> arrange(sample_ID)

datafile     <- "2026.06.21_ABTS_generic_plate.xlsx"
exp_datafile <- "2026.06.21_ABTS_exp_metadata.csv"
source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))
results$B_generic_plate <- df_samples_calc_final |> arrange(sample_ID)

datafile     <- "2026.06.22_ABTS_spectramax.csv"
exp_datafile <- "2026.06.22_ABTS_exp_metadata.csv"
source(here("..", "..", "process_spectramax_endpoint_std_curve.R"))
results$B_spectramax <- df_samples_calc_final |> arrange(sample_ID)

#### Assert every format agrees within each dataset ####

check_group <- function(label, group_names) {
  ref <- results[[group_names[1]]]$value
  for (nm in group_names[-1]) {
    stopifnot(all.equal(ref, results[[nm]]$value, tolerance = 1e-6))
  }
  message(sprintf("%s: all %d formats agree.", label, length(group_names)))
}

check_group("Dataset A (BCA, 1 wavelength)", c("A_synergy2", "A_spectramax", "A_generic_long", "A_generic_plate"))
check_group("Dataset B (ABTS, 2 wavelengths)", c("B_generic_long", "B_generic_plate", "B_spectramax"))

print(results$A_synergy2)
print(results$B_generic_long)
