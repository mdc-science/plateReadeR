#### Quick check: preview a plate layout before running the full pipeline ####
#
# Reads an exp_metadata CSV and plots the plate layout (well type + label),
# so you can catch a transcription mistake before running the full analysis.
#
# Define before sourcing, e.g.:
#   exp_datafile <- "YYYY.MM.DD_assay_exp_metadata.csv"

library(conflicted)
library(here)
library(tidyverse)
library(ggthemes)
library(ggforce)

conflicts_prefer(here::here, dplyr::filter)

#### Read metadata ####
meta <- read_csv(
  here("experimental_data", "raw_data", exp_datafile),
  show_col_types = FALSE
)

#### Build full 96-well grid and join metadata ####
row_lookup <- setNames(1:8, LETTERS[1:8])

all_wells <- expand_grid(row_letter = LETTERS[1:8], col = 1:12) |>
  mutate(
    well = paste0(row_letter, col),
    row  = row_lookup[row_letter]
  ) |>
  select(-row_letter)

df_plate <- all_wells |>
  left_join(
    meta |> mutate(col = parse_number(well), row = row_lookup[str_extract(well, "[A-H]")]),
    by = join_by(well, col, row)
  )

#### Plot ####
# `type` values in exp_metadata stay exactly as recorded (blank/std/sample/...)
# - only the legend text is relabeled for readability. scale_fill_manual()
# matches `values` and `labels` by name, not by position, so these two named
# vectors don't need to be kept in the same order.
type_colors <- c(
  blank    = "gray90",
  std      = "#4292C6",
  sample   = "#EF6548",
  smp_blk  = "#FEC44F",
  ref      = "#41AE76",
  pos_ctrl = "#984EA3",
  neg_ctrl = "#E7298A",
  ctrl     = "#A65628"
)

type_labels <- c(
  blank    = "Blank",
  std      = "Standard",
  sample   = "Sample",
  smp_blk  = "Sample Blank",
  ref      = "Reference",
  pos_ctrl = "Positive Control",
  neg_ctrl = "Negative Control",
  ctrl     = "Control"
)

ggplot(df_plate) +
  geom_circle(
    aes(x0 = col, y0 = row, r = 0.44, fill = type),
    alpha = 0.85, color = "gray35", linewidth = 0.3
  ) +
  scale_fill_manual(values = type_colors, labels = type_labels, na.value = "white") +
  geom_text(
    aes(x = col, y = row, label = ifelse(is.na(label), "", label)),
    size = 2.2
  ) +
  coord_equal() +
  scale_x_continuous(breaks = 1:12, expand = expansion(mult = 0.02)) +
  scale_y_continuous(
    breaks = 1:8,
    labels = LETTERS[1:8],
    expand = expansion(mult = 0.02),
    trans  = scales::reverse_trans()
  ) +
  labs(
    title = paste("Plate layout -", exp_datafile),
    x = "Column", y = "Row", fill = "Type"
  ) +
  theme_few(base_size = 10) +
  theme(legend.position = "right")
