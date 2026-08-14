# Changelog

All notable changes to this workflow are documented here. Versions correspond to DOI-citable releases.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-08-14

### Added
- `process_generic_excel_endpoint_std_curve.R` — reads a user-prepared `.xlsx` file instead of an instrument-specific export, for use with any plate reader. Auto-detects a long format (single sheet, columns `well`/`wavelength`/`signal`) or a plate format (one 8x12-grid sheet per wavelength) from the first sheet's cell A1; supports multi-wavelength signal formulas in both.
- `examples/example_run_generic_excel/` — runnable example encoding the same fabricated two-wavelength assay data in both formats and asserting they back-calculate to identical results.
- `examples/ABTS_assay_metadata.csv` — assay metadata example for a two-wavelength subtraction formula (`A412 - A700`).
- `examples/example_run_bradford_legacy/` — runnable example built from a real 2024 Bradford assay, reorganized from its original SpectraMax export into the generic-Excel plate format. Demonstrates a two-wavelength *ratio* formula (`A590/A450`, as opposed to `ABTS`'s subtraction) and how to adapt an older exp_metadata/assay_metadata layout to this repo's current schema without altering any real recorded values.
- `examples/example_run_tgsh_legacy/` — second real-data example, this time reorganized into the generic-Excel **long** format (`examples/example_run_generic_excel/`'s long-format demo is fabricated). A real 2024 total-glutathione (tGSH) enzymatic recycling assay whose original export omitted the blank wells entirely; encodes the confirmed real blank reading (0.000) rather than leaving them undefined, which would otherwise propagate `NaN` through every well's corrected signal.

### Changed
- `examples/example_run/` now runs against **real** data instead of fabricated: a genuine BCA protein assay exported from a BioTek Synergy 2 (2026.06.15), replacing the previous fabricated SpectraMax CSV. This is the first example that actually exercises `process_synergy2_endpoint_std_curve.R` end-to-end — until now it had no runnable coverage at all. It's also the first example where `sample_dil_final` is left to the pipeline's own `sample_dil * (std_vol / volume)` auto-calculation rather than being set explicitly, since this real export recorded both the standard and sample well volumes. SpectraMax coverage is unaffected — `examples/example_run_amplexred/` and `examples/example_run_bradford_legacy/` both still exercise `process_spectramax_endpoint_std_curve.R`.

### Fixed
- `process_spectramax_endpoint_std_curve.R`: the wavelength-detection heuristic mis-parsed genuine multi-wavelength absorbance exports. It checked whether the raw cell at row 2, column 16 parsed as a single number ≥ 200; SpectraMax stores multiple wavelengths there space-separated (e.g. `"590 450"`), which fails that check and silently falls through to the fluorescence-emission fallback column instead — parsing a single bogus wavelength rather than erroring. Found while reorganizing the real Bradford data above (a genuine two-wavelength absorbance export) into `examples/example_run_bradford_legacy/`. Fixed by parsing column 16 as a whitespace-separated list first, then checking every parsed value is a plausible wavelength, rather than parsing the whole cell as one number. Single-wavelength absorbance and fluorescence exports are unaffected (regression-tested against `examples/example_run_amplexred/`, at the time `examples/example_run/` too — see Changed, above, for why that second witness no longer applies).

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
