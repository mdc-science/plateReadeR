#### Runnable example: BCA protein assay (SpectraMax iD3) ####
#
# All values in this example are fabricated for demonstration only — they are
# NOT real experimental data. Open BCA_example.Rproj in RStudio first (or run
# `Rscript run_example.R` from this folder) so here::here() resolves correctly.
#
# Plate design (see experimental_data/raw_data/2026.03.02_BCA_exp_metadata.csv):
#   - Blanks:    A1:A3
#   - Standards: B1:G3, six BSA concentrations from 0 to 1.0 mg/mL, triplicate
#   - S001:      A4:A6, ~3.5 mg/mL
#   - S002:      B4:B6, ~5.5 mg/mL
#   - S003:      C4:C6, ~7.5 mg/mL
# All three samples fall within the standard curve range. Samples outside the
# range are back-calculated and flagged extrapolated = TRUE instead of being
# dropped — see the "Out-of-range handling" note in the workflow's CLAUDE.md.

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

datafile     <- "2026.03.02_BCA_assay_data.csv"
exp_datafile <- "2026.03.02_BCA_exp_metadata.csv"

# In a real experiment this points two levels up to experimental/assay_metadata/;
# this standalone example keeps the assay metadata file one level up instead.
assay_datafile <- here("..", "BCA_assay_metadata.csv")

source(here("..", "..", "process_spectramax_endpoint_std_curve.R"))

# Objects now available: df, df_std, df_samples_calc, df_samples_calc_final,
# std_curve, CLOD, CLOQ, p_plate_map, p_plate_signal, p_std_curve,
# p_sample_raw, p_calc_value, p_summary — see the workflow's CLAUDE.md for
# the full list. Outputs are written to
# experimental_data/processed_data/Protein/, matching a real experiment run.

print(df_samples_calc_final)
