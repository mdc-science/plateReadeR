#### Runnable example: real legacy Bradford data, reorganized into generic Excel input ####
#
# Unlike the other examples in this repo, the values here are REAL — a
# genuine Bradford protein assay (whole_body Tenebrio molitor samples) run
# on a SpectraMax iD3 on 2024.11.27. The original raw export was a SpectraMax
# CSV and the metadata used an older column layout; this example shows how to
# take data like that — from an old experiment, or from any instrument this
# workflow doesn't have a dedicated parser for — and reorganize it into the
# plate format that process_generic_excel_endpoint_std_curve.R accepts:
#
#   - experimental_data/raw_data/2024.11.27b_Bradford_plate_raw.xlsx:
#     the same 96-well absorbance values from the original SpectraMax export,
#     reorganized as one 8x12 grid sheet per wavelength ("590", "450") -
#     extracted programmatically from the original export, not retyped, to
#     avoid transcription error.
#   - experimental_data/raw_data/2024.11.27b_Bradford_exp_metadata.csv:
#     the original plate layout (blank/std/sample wells, real std_conc and
#     sample_dil values), with columns renamed/added to match this repo's
#     current exp_metadata schema (std_diluent -> diluent; added volume,
#     sample_dil_final, species, suppress). Nothing about the real values was
#     changed: volume and species were never recorded for this old experiment
#     so they're left blank rather than guessed, and sample_dil_final is set
#     equal to the recorded sample_dil (200x) since no volume is available to
#     rescale it further.
#   - examples/Bradford_assay_metadata.csv: the original assay protocol
#     metadata, with the two columns this schema now requires (final_vol,
#     read_type) added - final_vol left blank (never recorded), read_type
#     set to "Absorbance" (this is a fact taken directly from the original
#     raw export's own header, not a guess).
#
# The assay's signal_formula (A590/A450) is a genuine two-wavelength RATIO,
# rather than the subtraction formula used elsewhere in this repo's examples
# (e.g. ABTS's A412 - A700) - another real-world formula shape this workflow
# supports unmodified.

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

datafile       <- "2024.11.27b_Bradford_plate_raw.xlsx"
exp_datafile   <- "2024.11.27b_Bradford_exp_metadata.csv"
assay_datafile <- here("..", "Bradford_assay_metadata.csv")

source(here("..", "..", "process_generic_excel_endpoint_std_curve.R"))

print(df_samples_calc_final)
