# Changelog

All notable changes to this workflow are documented here. Versions correspond to DOI-citable releases.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- `examples/ABTS_assay_metadata.csv` renamed to `examples/ELISA_assay_metadata.csv`, and the fabricated two-wavelength dataset in `examples/example_run_generic_excel/` and the "Dataset B" leg of `examples/example_run_format_consistency/` relabeled from `A412 - A700` (attributed to ABTS) to `A450 - A570` (a generic ELISA wavelength-correction assay, `var_short = ELISA`, `var_abbr = AG`). Real ABTS radical-decolorization assays are read at a single wavelength (~734 nm), not via two-wavelength subtraction — the subtraction formula shape was legitimate, but the assay name attached to it wasn't. `A450 - A570` (analyte signal minus a reference read) is a genuine, common ELISA-kit convention, so the underlying fabricated well values needed no changes — the existing positive-slope, roughly-constant-reference-channel shape already fits ELISA correction — only wavelength labels and metadata were relabeled (see CLAUDE.md "What this workflow does" and "Known issues / gotchas" for detail). All affected `run_example.R` scripts were re-run to confirm identical back-calculated concentrations before and after the rename.

## [1.2.2] - 2026-08-18

DOI: [10.5281/zenodo.21996682](https://doi.org/10.5281/zenodo.21996682) (concept DOI, resolves to latest version: [10.5281/zenodo.21933797](https://doi.org/10.5281/zenodo.21933797)).

### Added
- README.md: a new "Dilution factors and concentration units" section explaining what `std_conc` and `sample_dil` are supposed to represent (tube/dilution-series concentrations, not in-well concentrations after reagent is added), why that's correct, and how `sample_dil_final = sample_dil * (std_vol / volume)` reconciles standard and sample wells loaded at different volumes. Prompted by a real question about back-calculation accuracy that wasn't previously answerable from the docs alone — only from reading the R code.

## [1.2.1] - 2026-08-17

DOI: [10.5281/zenodo.21980171](https://doi.org/10.5281/zenodo.21980171) (concept DOI, resolves to latest version: [10.5281/zenodo.21933797](https://doi.org/10.5281/zenodo.21933797)).

### Removed
- `ro-crate-metadata.json` (added in `[1.0.0]`). It existed to support WorkflowHub registration, which was deliberately never pursued (see `[1.0.0]`/`[1.1.0]` discussion) — no other consumer reads it (Zenodo's DOI minting uses the GitHub repo metadata and `CITATION.cff`, not RO-Crate), so it was pure ongoing maintenance overhead (every new script/example needed a matching entity added) with no active use. Citability is unaffected: `CITATION.cff` + the Zenodo DOI remain the source of truth.

## [1.2.0] - 2026-08-17

DOI: [10.5281/zenodo.21980063](https://doi.org/10.5281/zenodo.21980063) (concept DOI, resolves to latest version: [10.5281/zenodo.21933797](https://doi.org/10.5281/zenodo.21933797)).

### Added
- `quick_preview_plate_layout.R` — plots the plate layout (well type + label) from an `exp_metadata` CSV alone, without needing the raw instrument file, so a transcription mistake can be caught before running the full pipeline. Two fixes applied on import: the legend now shows human-readable well-type labels ("Blank", "Standard", "Sample", "Sample Blank", "Positive Control", etc.) instead of the raw codes (`blank`, `std`, `sample`, `smp_blk`, `pos_ctrl`, ...) — display-only, the underlying `type` values are untouched — and a hardcoded absolute path left over from local development was removed (it silently overrode the intended relative `here()`-based read).
- `GETTING_STARTED.md` — install-R/RStudio-through-first-successful-example walkthrough for users with no prior R experience, linked from the top of `README.md`. `README.md` itself still assumes familiarity with R (`here()`, sourcing scripts, etc.).

## [1.1.0] - 2026-08-14

DOI: [10.5281/zenodo.21937604](https://doi.org/10.5281/zenodo.21937604) (concept DOI, resolves to latest version: [10.5281/zenodo.21933797](https://doi.org/10.5281/zenodo.21933797)).

### Added
- `process_generic_excel_endpoint_std_curve.R` — reads a user-prepared `.xlsx` file instead of an instrument-specific export, for use with any plate reader. Auto-detects a long format (single sheet, columns `well`/`wavelength`/`signal`) or a plate format (one 8x12-grid sheet per wavelength) from the first sheet's cell A1; supports multi-wavelength signal formulas in both.
- `examples/example_run_generic_excel/` — runnable example encoding the same fabricated two-wavelength assay data in both formats and asserting they back-calculate to identical results.
- `examples/ABTS_assay_metadata.csv` — assay metadata example for a two-wavelength subtraction formula (`A412 - A700`).
- `examples/example_run_bradford_legacy/` — runnable example built from a real 2024 Bradford assay, reorganized from its original SpectraMax export into the generic-Excel plate format. Demonstrates a two-wavelength *ratio* formula (`A590/A450`, as opposed to `ABTS`'s subtraction) and how to adapt an older exp_metadata/assay_metadata layout to this repo's current schema without altering any real recorded values.
- `examples/example_run_tgsh_legacy/` — second real-data example, this time reorganized into the generic-Excel **long** format (`examples/example_run_generic_excel/`'s long-format demo is fabricated). A real 2024 total-glutathione (tGSH) enzymatic recycling assay whose original export omitted the blank wells entirely; encodes the confirmed real blank reading (0.000) rather than leaving them undefined, which would otherwise propagate `NaN` through every well's corrected signal.
- `examples/example_run_format_consistency/` — audit example proving the workflow produces identical back-calculated results regardless of raw-file format and wavelength count. Two canonical datasets, each re-encoded into every format that can be verified against a real or already-established reference: the real single-wavelength BCA data (`examples/example_run/`) across all four formats (Synergy2, SpectraMax, generic-Excel long, generic-Excel plate — all agree), and the fabricated two-wavelength ABTS data (`examples/example_run_generic_excel/`) across the three formats with a trustworthy reference structure (generic-Excel long, generic-Excel plate, SpectraMax — all agree). Deliberately excludes a two-wavelength Synergy2 leg — see "Known limitation" below.

### Changed
- `examples/example_run/` now runs against **real** data instead of fabricated: a genuine BCA protein assay exported from a BioTek Synergy 2 (2026.06.15), replacing the previous fabricated SpectraMax CSV. This is the first example that actually exercises `process_synergy2_endpoint_std_curve.R` end-to-end — until now it had no runnable coverage at all. It's also the first example where `sample_dil_final` is left to the pipeline's own `sample_dil * (std_vol / volume)` auto-calculation rather than being set explicitly, since this real export recorded both the standard and sample well volumes. SpectraMax coverage is unaffected — `examples/example_run_amplexred/` and `examples/example_run_bradford_legacy/` both still exercise `process_spectramax_endpoint_std_curve.R`.

### Fixed
- `process_spectramax_endpoint_std_curve.R`: the wavelength-detection heuristic mis-parsed genuine multi-wavelength absorbance exports. It checked whether the raw cell at row 2, column 16 parsed as a single number ≥ 200; SpectraMax stores multiple wavelengths there space-separated (e.g. `"590 450"`), which fails that check and silently falls through to the fluorescence-emission fallback column instead — parsing a single bogus wavelength rather than erroring. Found while reorganizing the real Bradford data above (a genuine two-wavelength absorbance export) into `examples/example_run_bradford_legacy/`. Fixed by parsing column 16 as a whitespace-separated list first, then checking every parsed value is a plausible wavelength, rather than parsing the whole cell as one number. Single-wavelength absorbance and fluorescence exports are unaffected (regression-tested against `examples/example_run_amplexred/`, at the time `examples/example_run/` too — see Changed, above, for why that second witness no longer applies).
- `process_synergy2_endpoint_std_curve.R` and `process_generic_excel_endpoint_std_curve.R` were missing `process_spectramax_endpoint_std_curve.R`'s auto-scaling of large plate-heatmap signal labels (dividing by 1e3/1e6 for readability, e.g. for fluorescence values in the millions) — a real cross-script inconsistency, found by mechanically diffing the three scripts' shared post-parsing logic as part of a consistency audit. Ported to all three so plot output is now identical, not just the underlying computation.
- All three scripts: blank wells (and any other well with no signal) showed the literal text `"NA"` in the plate-signal heatmap instead of being empty. This is a real display bug present since `v1.0.0` — visible in `examples/example_run_amplexred/`'s own committed PDF the whole time, just never looked at closely. `formatC()` coerces a numeric `NA` to the string `"NA"`; the code relied on `round()` returning a numeric `NA` that ggplot silently drops, which broke once the auto-scaling fix above switched every script to `formatC()`. Fixed by explicitly excluding `NA` signal from the label condition rather than relying on that implicit behavior.

**Known limitation surfaced by this audit:** `process_synergy2_endpoint_std_curve.R`'s handling of genuine multi-wavelength Synergy2 exports (as opposed to single-wavelength, which is real-data-verified via `examples/example_run/`) has not been checked against a real multi-wavelength Synergy2 export — none was available. The parsing logic (splitting consecutive 8-row grids into one block per wavelength, in `wavelength_list` order) is a plausible reading of how Synergy2/Gen5 would lay that out, consistent with the single-wavelength real file this repo does have, but it's unverified. Treat multi-wavelength Synergy2 support as implemented-but-unconfirmed until a real example turns up.

## [1.0.0] - 2026-08-14

First citable release. DOI: [10.5281/zenodo.21933798](https://doi.org/10.5281/zenodo.21933798) (concept DOI, resolves to latest version: [10.5281/zenodo.21933797](https://doi.org/10.5281/zenodo.21933797)).

### Added
- `process_spectramax_endpoint_std_curve.R` — endpoint colorimetric/fluorescence assay pipeline for SpectraMax iD3 exports (CSV/XLS/TXT), with instrument read-mode and wavelength auto-detection.
- `process_synergy2_endpoint_std_curve.R` — the same pipeline for BioTek Synergy 2 (`.xlsx`) exports.
- Standard-curve fitting with calculated Limit of Detection (CLoD) and Limit of Quantification (CLoQ).
- Out-of-range sample handling: back-calculated via the standard curve and flagged `extrapolated = TRUE` rather than dropped.
- `smp_blk` well type for matrix-matched sample blanks, subtracted per `sample_ID` before back-calculation.
- Two runnable, fabricated examples: `examples/example_run/` (BCA, absorbance) and `examples/example_run_amplexred/` (Amplex Red H2O2, fluorescence — also demonstrating `smp_blk` and extrapolation flagging).
- `CITATION.cff` and `ro-crate-metadata.json` for citation metadata (the latter conforms to the Workflow RO-Crate profile).
