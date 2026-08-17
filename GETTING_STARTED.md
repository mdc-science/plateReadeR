# Getting Started

This page is for anyone who has never used R before and just wants to get this workflow running. If you already have R and RStudio set up, skip ahead to [README.md](README.md).

## 1. Install R

R is the programming language everything here runs on. Download it from [cran.r-project.org](https://cran.r-project.org/) and pick your operating system:

- **Windows:** "Download R for Windows" → "base" → the big download link at the top.
- **Mac:** "Download R for macOS" → pick the `.pkg` matching your Mac (Apple silicon vs Intel — if you're not sure, check  → About This Mac).
- **Linux:** follow the instructions for your distribution.

Run the installer with the default options. You won't need to open R directly — RStudio (next step) gives you a much nicer way to work with it.

## 2. Install RStudio

RStudio is the application you'll actually use — it's an editor built specifically for R. Download the free "RStudio Desktop" edition from [posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop/) and install it with the default options.

Open RStudio once after installing, just to confirm it starts up and detects the R installation from step 1 (it does this automatically — no configuration needed).

## 3. Get this repository

You don't need to know git to do this:

1. Go to [github.com/mdc-science/plateReadeR](https://github.com/mdc-science/plateReadeR).
2. Click the green **Code** button → **Download ZIP**.
3. Unzip it somewhere you'll find again (e.g. your Documents folder).

(If you *are* comfortable with git: `git clone https://github.com/mdc-science/plateReadeR.git`.)

## 4. Install the required packages

"Packages" are add-ons that give R extra abilities — this workflow uses several for data wrangling and plotting. In RStudio, go to the **Console** pane (bottom-left by default) and paste this in, then press Enter:

```r
install.packages(c(
  "conflicted", "tidyverse", "scales", "patchwork", "here",
  "ggrepel", "RColorBrewer", "ggpmisc", "ggforce", "ggthemes", "readxl"
))
```

This downloads and installs everything needed. It can take a few minutes the first time (`tidyverse` in particular is large) — let it finish before moving on. If you're asked "Do you want to install from sources the package which needs compilation?", answering **No** is fine and faster.

## 5. Run an example

This is the best way to confirm everything works before touching your own data.

1. In RStudio, go to **File → Open Project...**
2. Navigate into the folder you unzipped, then into `examples/example_run/`, and open **`BCA_example.Rproj`**.

   This step matters: always open the `.Rproj` file for whichever example (or later, your own experiment) you're working with, rather than just opening a loose `.R` script. RStudio uses the open project to figure out *where* it is on your computer, which is how the scripts find their input/output files without you having to type out full file paths.

3. In the **Files** pane (bottom-right), click `run_example.R` to open it.
4. Click **Source** (top-right of the script editor) — or run `source("run_example.R")` in the Console.

You should see some processing messages appear in the Console, and after a few seconds a summary table of results is printed. Open the `experimental_data/processed_data/Protein/` folder (in the Files pane, or in Finder/Explorer) to see the plots (`.pdf`) and result tables (`.csv`) it just created.

Every folder under `examples/` works the same way — each has its own `.Rproj` and `run_example.R`. See the "Try it" section of [README.md](README.md) for what each one demonstrates.

## 6. Next: running it on your own data

Once an example has worked, [README.md](README.md) covers everything else: what your raw instrument file and metadata CSVs need to look like, the field-by-field reference for each, and how to point the workflow at your own experiment instead of the bundled examples.

## Troubleshooting

- **"could not find function..." error** — a package from step 4 isn't installed or didn't load. Re-run the `install.packages(...)` line above; if a specific package failed silently, install just that one, e.g. `install.packages("ggforce")`.
- **"object 'here' not found" or file-not-found errors** — you likely opened a loose script instead of the `.Rproj` file (see step 5.2). Check the top-right corner of RStudio: it should show the project name (e.g. "BCA_example"), not "(None)".
- **A package fails to install with a compiler error (Mac)** — you may need Apple's command line developer tools. Open Terminal and run `xcode-select --install`, then retry step 4.
- **A package fails to install with a compiler error (Windows)** — you may need Rtools. RStudio will usually offer to install this for you automatically; accept if prompted, then retry step 4.
- **Nothing happens when you click "Source"** — check the Console pane for a red error message; it will name the problem. If you're stuck, the message itself is worth searching for online — R error messages are usually specific enough to find an answer.
