#### Runnable example: real legacy tGSH data, reorganized into generic Excel LONG format ####
#
# Like examples/example_run_bradford_legacy/, the values here are REAL — a
# genuine total-glutathione (tGSH) enzymatic recycling assay (whole_body
# Tenebrio molitor samples, anoxia/reoxygenation time course) run on
# 2024.11.22. Unlike that example, this one demonstrates the generic-Excel
# LONG format instead of the plate format:
#
#   - experimental_data/raw_data/2024.11.22_tGSH_long_raw.xlsx: a single
#     sheet, columns well/wavelength/signal. The original raw export
#     (well, A412_rate) was already close to this shape - only well A1:A3
#     (the blank wells) needed adding, since the original kinetic-software
#     export omitted them entirely (see below). All 412 nm values are the
#     real recorded kinetic rate (A412/min); "412" is used as the nominal
#     wavelength so the blank-corrected column lands on the name
#     (A412) the assay's signal_formula expects, matching this repo's
#     A{wavelength} convention - the original file called the column
#     "A412_rate", which is the same real 412 nm measurement, just named
#     differently. Nothing about the real rate values themselves was changed.
#   - experimental_data/raw_data/2024.11.22_tGSH_exp_metadata.csv: the
#     original plate layout, with columns renamed/added to match this repo's
#     current schema (std_diluent -> diluent, sample_vol -> volume; added
#     sample_dil_final, species, suppress). The original "treatment" column
#     (anoxia/reoxygenation timepoint) doesn't exist in the standard schema
#     but isn't discarded either - extra columns pass through unused by the
#     pipeline, so it's kept as-is for anyone inspecting the real metadata.
#   - examples/tGSH_assay_metadata.csv: the original assay protocol
#     metadata, with signal_formula renamed from "A412_rate" to "A412" (same
#     reasoning as above) and the two columns this schema now requires added
#     (final_vol left blank - never recorded; read_type set to "Absorbance",
#     a fact taken from the assay chemistry, not a guess).
#
# Data-completeness note: the original raw export had no rows at all for
# A1:A3 (the blank wells) - the kinetic-analysis software's summary table
# only covered standard and sample wells. Daniel confirmed the real blank
# reading was 0.000 for all three, so that's what's encoded here rather than
# silently omitting the blank wells (which would trigger this repo's normal
# "no blank wells found" path) or leaving them with no data (which would
# propagate NaN through every well's corrected signal - mean() of an
# all-missing blank subset is NaN, not skipped).

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

conflicts_prefer(here::here, dplyr::filter)

datafile       <- "2024.11.22_tGSH_long_raw.xlsx"
exp_datafile   <- "2024.11.22_tGSH_exp_metadata.csv"
assay_datafile <- here("..", "tGSH_assay_metadata.csv")

source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))

print(df_samples_calc_final)
