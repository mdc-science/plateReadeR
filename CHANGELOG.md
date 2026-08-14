# Changelog

All notable changes to this workflow are documented here. Versions correspond to DOI-citable releases.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-08-14

First citable release.

### Added
- `process_spectramax_endpoint_std_curve.R` — endpoint colorimetric/fluorescence assay pipeline for SpectraMax iD3 exports (CSV/XLS/TXT), with instrument read-mode and wavelength auto-detection.
- `process_synergy2_endpoint_std_curve.R` — the same pipeline for BioTek Synergy 2 (`.xlsx`) exports.
- Standard-curve fitting with calculated Limit of Detection (CLoD) and Limit of Quantification (CLoQ).
- Out-of-range sample handling: back-calculated via the standard curve and flagged `extrapolated = TRUE` rather than dropped.
- `smp_blk` well type for matrix-matched sample blanks, subtracted per `sample_ID` before back-calculation.
- Two runnable, fabricated examples: `examples/example_run/` (BCA, absorbance) and `examples/example_run_amplexred/` (Amplex Red H2O2, fluorescence — also demonstrating `smp_blk` and extrapolation flagging).
- `CITATION.cff` and `ro-crate-metadata.json` for citation and WorkflowHub indexing.
