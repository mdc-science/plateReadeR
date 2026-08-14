#### Runnable example: Amplex Red H2O2 assay (SpectraMax iD3, fluorescence) ####
#
# All values in this example are fabricated for demonstration only — they are
# NOT real experimental data. Open AmplexRed_example.Rproj in RStudio first (or
# run `Rscript run_example.R` from this folder) so here::here() resolves correctly.
#
# Plate design (see experimental_data/raw_data/2026.05.10_AmplexRed_exp_metadata.csv):
#   - Blanks:    A1:A3
#   - Standards: B1:G3, six H2O2 concentrations from 0 to 8 uM, triplicate
#   - S001:      A4:A6 sample, A7:A9 matched sample-blank (smp_blk)
#   - S002:      B4:B6 sample, B7:B9 matched sample-blank (smp_blk)
#   - S003:      C4:C6 sample, C7:C9 matched sample-blank (smp_blk)
#
# This example exercises two features not covered by the BCA example:
#   1. `smp_blk` wells — a matrix-matched blank per sample_ID, subtracted from
#      that sample's signal before back-calculation (see "smp_blk well type"
#      in the workflow's CLAUDE.md).
#   2. Extrapolation flagging — S003's raw signal is well above the top
#      standard (8 uM). It is still back-calculated via the standard curve
#      but flagged `extrapolated = TRUE`, and shown in p_calc_value with an
#      orange triangle + label instead of being dropped.

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

datafile     <- "2026.05.10_AmplexRed_assay_data.txt"
exp_datafile <- "2026.05.10_AmplexRed_exp_metadata.csv"

# In a real experiment this points two levels up to experimental/assay_metadata/;
# this standalone example keeps the assay metadata file one level up instead.
assay_datafile <- here("..", "AmplexRed_assay_metadata.csv")

source(here("..", "..", "process_spectramax_endpoint_std_curve.R"))

# Objects now available: df, df_std, df_samples_calc, df_samples_calc_final,
# std_curve, CLOD, CLOQ, p_plate_map, p_plate_signal, p_std_curve,
# p_sample_raw, p_calc_value, p_summary — see the workflow's CLAUDE.md for
# the full list. Outputs are written to
# experimental_data/processed_data/H2O2/, matching a real experiment run.

print(df_samples_calc_final)
