# Aggregate completed medium simulation outputs without launching simulations.

args <- commandArgs(trailingOnly = TRUE)

parse_cli <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    key_value <- sub("^--", "", arg)
    if (grepl("=", key_value, fixed = TRUE)) {
      key <- sub("=.*$", "", key_value)
      value <- sub("^[^=]*=", "", key_value)
      out[[key]] <- value
    }
  }
  out
}

cli <- parse_cli(args)
get_arg <- function(name, default = NULL) {
  if (name %in% names(cli)) cli[[name]] else default
}

project_dir <- normalizePath(getwd(), mustWork = TRUE)
source(file.path(project_dir, "R", "00_helpers.R"))

output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))
raw_dir <- file.path(output_dir, "raw")
alpha <- as.numeric(get_arg("alpha", "0.05"))
target_R <- as.integer(get_arg("R", "500"))
B <- as.integer(get_arg("B", "499"))

safe_read_csv <- function(file) {
  if (!file.exists(file)) return(data.frame())
  info <- file.info(file)
  if (is.na(info$size) || info$size == 0L) return(data.frame())
  tryCatch(
    utils::read.csv(file, stringsAsFactors = FALSE),
    error = function(e) data.frame()
  )
}

atomic_write_csv <- function(x, file) {
  tmp <- paste0(file, ".tmp.", Sys.getpid())
  utils::write.csv(x, tmp, row.names = FALSE)
  file.rename(tmp, file)
  invisible(file)
}

files <- list.files(raw_dir, pattern = "__raw[.]csv$", full.names = TRUE)
files <- files[file.info(files)$size > 0L]
if (length(files) == 0L) stop("No raw files found.", call. = FALSE)

raw_list <- lapply(files, safe_read_csv)
raw_list <- Filter(function(x) nrow(x) > 0L, raw_list)
if (length(raw_list) == 0L) stop("No readable raw files found.", call. = FALSE)

all_cols <- unique(unlist(lapply(raw_list, names)))
raw_list <- lapply(raw_list, function(x) {
  missing <- setdiff(all_cols, names(x))
  for (col in missing) x[[col]] <- NA
  x[, all_cols, drop = FALSE]
})
raw <- do.call(rbind, raw_list)

write_kind <- function(kind_value, raw_name, summary_name) {
  part <- raw[raw$kind == kind_value, , drop = FALSE]
  if (nrow(part) == 0L) return(invisible(NULL))
  atomic_write_csv(part, file.path(output_dir, raw_name))
  summary <- summarise_rejections(
    part,
    c("kind", "scenario", "n", "effect", "method"),
    alpha = alpha
  )
  summary$B <- B
  summary$alpha <- alpha
  summary$target_R <- target_R
  summary$completed <- summary$R >= target_R
  atomic_write_csv(summary, file.path(output_dir, summary_name))
  invisible(summary)
}

write_kind("null", "null_raw.csv", "null_summary.csv")
write_kind("alternative", "power_raw.csv", "power_summary.csv")
write_kind("circular_linear", "circular_linear_raw.csv", "circular_linear_summary.csv")

cost <- data.frame(
  aggregated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  raw_files = length(files),
  R = target_R,
  B = B,
  alpha = alpha,
  kernel_sensitivity_status = if (file.exists(file.path(output_dir, "kernel_sensitivity_raw.csv"))) {
    "partial_or_separate"
  } else {
    "not_run"
  },
  stringsAsFactors = FALSE
)
atomic_write_csv(cost, file.path(output_dir, "computational_cost.csv"))

message("Aggregated existing outputs.")
