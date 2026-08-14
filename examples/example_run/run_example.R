#### Runnable example: BCA protein assay (BioTek Synergy 2) ####
#
# Unlike the other examples in this repo (except example_run_bradford_legacy/
# and example_run_tgsh_legacy/), the values here are REAL — a genuine BCA
# protein assay (whole_body Tenebrio molitor samples) run on a BioTek
# Synergy 2 on 2026.06.15. This is the only example that actually exercises
# process_synergy2_endpoint_std_curve.R end-to-end. Open BCA_example.Rproj in
# RStudio first (or run `Rscript run_example.R` from this folder) so
# here::here() resolves correctly.
#
# Plate design (see experimental_data/raw_data/2026.06.15_BCA_exp_metadata.csv):
#   - Blanks:    A1:A3
#   - Standards: B1:H3, seven BSA concentrations from 0 to 0.8 mg/mL, triplicate
#   - Samples:   G025-G030, six samples, triplicate (A4:F6), 10x dilution
# This is also the only example whose sample_dil_final is left to the
# pipeline's own auto-calculation (sample_dil * std_vol / volume) rather than
# being set explicitly - unlike example_run_bradford_legacy/ and
# example_run_tgsh_legacy/, this real export actually recorded both the
# standard well volume (10 uL) and the sample well volume (3 uL), so there's
# real data to compute a real dilution factor from.

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

datafile     <- "2026.06.15_BCA_assay_data.xlsx"
exp_datafile <- "2026.06.15_BCA_exp_metadata.csv"

# In a real experiment this points two levels up to experimental/assay_metadata/;
# this standalone example keeps the assay metadata file one level up instead.
assay_datafile <- here("..", "BCA_assay_metadata.csv")

source(here("..", "..", "process_synergy2_endpoint_std_curve.R"))

# Objects now available: df, df_std, df_samples_calc, df_samples_calc_final,
# std_curve, CLOD, CLOQ, p_plate_map, p_plate_signal, p_std_curve,
# p_sample_raw, p_calc_value, p_summary — see the workflow's CLAUDE.md for
# the full list. Outputs are written to
# experimental_data/processed_data/Protein/, matching a real experiment run.

print(df_samples_calc_final)
