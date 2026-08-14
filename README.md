# Plate Reader Endpoint Assay Workflow

**Author:** Daniel Moreira ([danielcarmor@gmail.com](mailto:danielcarmor@gmail.com))  
**Institution:** i3S – Instituto de Investigação e Inovação em Saúde, Porto, Portugal   
**Language:** R  
**Instrument:** Molecular Devices SpectraMax, BioTek Synergy

---

## Overview

A metadata-driven R workflow for processing endpoint colorimetric assays from 96-well microplate readers. Given raw instrument output and two metadata files (assay definition + plate layout), the workflow:

1. Parses the raw instrument export (auto-detecting SpectraMax CSV/XLS/TXT or Synergy2 Excel format)
2. Subtracts blank absorbance and computes the configured signal formula (e.g. A562, A412–A700)
3. Fits a linear standard curve and calculates the calculated Limit of Detection (CLoD) and Limit of Quantification (CLoQ)
4. Back-calculates analyte concentrations for all sample wells, accounting for dilution factors
5. Exports plate-map, signal heatmap, standard curve, and sample value plots as PDFs
6. Exports calculated concentrations and analytical performance metrics as CSVs

The workflow is sourced into experiment-specific RMarkdown reports. All paths use `here::here()`.

---

## File structure

```
plate_reader_assay/
├── process_spectramax_endpoint_std_curve.R   # SpectraMax iD3 (CSV/XLS/TXT exports)
├── process_synergy2_endpoint_std_curve.R     # BioTek Synergy 2 (Excel export)
└── examples/
    ├── BCA_assay_metadata.csv                # Assay metadata example (BCA protein assay, absorbance)
    ├── AmplexRed_assay_metadata.csv           # Assay metadata example (Amplex Red H2O2, fluorescence)
    ├── exp_metadata_template.csv             # Blank experiment metadata template
    ├── example_run/                          # Complete, runnable example (fabricated data)
    │   ├── BCA_example.Rproj
    │   ├── run_example.R                     # Self-contained script — run and inspect
    │   └── experimental_data/
    │       ├── raw_data/                     # Fabricated SpectraMax export + plate layout
    │       └── processed_data/Protein/       # Expected outputs (PDFs + levels.csv)
    └── example_run_amplexred/                # Second example: fluorescence, smp_blk, extrapolation
        ├── AmplexRed_example.Rproj
        ├── run_example.R
        └── experimental_data/
            ├── raw_data/                     # Fabricated fluorescence export + plate layout
            └── processed_data/H2O2/          # Expected outputs (PDFs + levels.csv)
```

---

## Inputs

### 1. Raw instrument data (`datafile`)

- **SpectraMax iD3:** SDA software export as `.csv`, `.xls`, or `.txt` (UTF-16LE tab-delimited)
- **Synergy 2:** Gen5 software export as `.xlsx`

Placed in `experimental_data/raw_data/` of the experiment folder.

### 2. Assay metadata (`assay_datafile`)

A single-row CSV defining the assay protocol. Shared across experiments and stored centrally.

| Field | Description | Example |
|-------|-------------|---------|
| `var_abbr` | Short abbreviation | `PTN` |
| `var_name` | Full variable name | `Protein` |
| `var_short` | Display label | `Protein` |
| `std_mol_name` | Standard molecule | `BSA` |
| `signal_formula` | R expression for signal | `A562` |
| `signal_name` | Signal label | `A562` |
| `signal_expression` | Math expression for plot axis | `bold(A562)` |
| `assay` | Assay name | `BCA` |
| `color_high` | High-signal plot color | `darkorchid3` |
| `color_low` | Low-signal plot color | `aquamarine2` |
| `read_type` | Measurement type | `Absorbance` |

See `examples/BCA_assay_metadata.csv` for a complete example.

### 3. Experiment metadata (`exp_datafile`)

One row per well describing the plate layout. Placed in `experimental_data/raw_data/` alongside the raw data.

| Field | Description |
|-------|-------------|
| `date` | Experiment date (YYYY.MM.DD) |
| `well` | Well position (e.g. A1, B12) |
| `label` | Display label on plate map |
| `sample_ID` | Sample identifier |
| `type` | `blank`, `std`, `sample`, or `smp_blk` |
| `std_conc` | Standard concentration (numeric) |
| `std_conc_unit` | Concentration unit (e.g. mg/mL, µM) |
| `volume` | Volume loaded per well (µL) |
| `sample_dil` | Sample dilution factor |
| `sample_dil_final` | Override for computed final dilution |
| `source` | Tissue/fraction label |
| `suppress` | `TRUE` to exclude well from analysis (still plotted) |

See `examples/exp_metadata_template.csv` for a complete template.

---

## Outputs

All outputs are prefixed `YYYY.MM.DD` and written to `experimental_data/processed_data/{var_short}/`.

| File | Description |
|------|-------------|
| `YYYY.MM.DD_{abbr}_summary_results.pdf` | Multi-panel figure: plate map, signal heatmap, standard curve, sample values |
| `YYYY.MM.DD_{abbr}_plate_map.pdf` | Plate layout annotated by sample ID |
| `YYYY.MM.DD_{abbr}_levels.csv` | Calculated analyte concentrations per sample |
| `YYYY.MM.DD_{abbr}_analytical_performance.csv` | Slope, intercept, R², CLoD, CLoQ |

---

## Usage

Define three variables in the calling RMarkdown chunk, then source the script:

```r
datafile       <- "YYYY.MM.DD_BCA_raw.csv"
exp_datafile   <- "YYYY.MM.DD_BCA_exp_metadata.csv"
assay_datafile <- here("assay_metadata", "BCA_assay_metadata.csv")

source(here("R_scripts", "process_spectramax_endpoint_std_curve.R"))
```

`here()` resolves from your experiment's `.Rproj` root — adjust the relative paths above to wherever you've placed the script and your assay metadata CSV. For the Synergy 2 instrument, replace `process_spectramax_endpoint_std_curve.R` with `process_synergy2_endpoint_std_curve.R`.

---

## Try it

Two complete, self-contained examples are included — fabricated runs with realistic but entirely made-up values (not real experimental data). Each mirrors the file layout of a real experiment folder (`experimental_data/raw_data/` + `experimental_data/processed_data/`), so together they double as a template for organizing your own experiment folders.

```r
# Open examples/example_run/BCA_example.Rproj, then:
source("run_example.R")
```

Or from the command line: `Rscript run_example.R` (from inside `examples/example_run/`). This reads the fabricated plate data, fits the standard curve, back-calculates three sample concentrations, and writes plate-map/summary PDFs, a `_levels.csv`, and a `_analytical_performance.csv` to `experimental_data/processed_data/Protein/` — compare against the versions already committed there to confirm the pipeline reproduces the expected output on your machine.

`examples/example_run_amplexred/` runs the same pipeline against a fabricated Amplex Red H2O2 (fluorescence) assay, and exercises two features the BCA example doesn't:

- **`smp_blk` wells** — a matrix-matched blank per `sample_ID`, subtracted from that sample's signal before back-calculation.
- **Extrapolation flagging** — one sample (`S003`) has a raw signal well above the top standard. It's still back-calculated via the standard curve but flagged `extrapolated = TRUE`, and drawn in the calculated-value plot with an orange triangle instead of being dropped.

```r
# Open examples/example_run_amplexred/AmplexRed_example.Rproj, then:
source("run_example.R")
```

Or `Rscript run_example.R` from inside `examples/example_run_amplexred/`; outputs land in `experimental_data/processed_data/H2O2/`.

---

## Dependencies

```r
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
library(readxl)   # Synergy2 script only
```

---

## License

MIT
