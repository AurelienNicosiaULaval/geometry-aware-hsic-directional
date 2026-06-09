# Small torus-torus demonstration for the CSDA pre-submission manuscript.

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
    } else {
      out[[key_value]] <- "true"
    }
  }
  out
}

parse_num_vec <- function(value, default) {
  if (is.null(value) || identical(value, "")) return(default)
  out <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (anyNA(out) || any(!is.finite(out))) {
    stop("Numeric vector arguments must be comma-separated finite values.",
         call. = FALSE)
  }
  out
}

cli <- parse_cli(args)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
project_dir <- if (length(file_arg) > 0L) {
  normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."),
                mustWork = TRUE)
} else if (file.exists(file.path(getwd(), "R", "00_helpers.R"))) {
  normalizePath(getwd(), mustWork = TRUE)
} else {
  normalizePath(file.path(getwd(), ".."), mustWork = TRUE)
}
source(file.path(project_dir, "R", "00_helpers.R"))
load_compact_sources(project_dir)

get_arg <- function(name, default = NULL) {
  if (name %in% names(cli)) cli[[name]] else default
}

R_total <- check_positive_integer(as.integer(get_arg("R", "250")), "R")
B <- check_positive_integer(as.integer(get_arg("B", "299")), "B")
alpha <- as.numeric(get_arg("alpha", "0.05"))
seed0 <- as.integer(get_arg("seed", "20260606"))
n_values <- as.integer(parse_num_vec(get_arg("n", NULL), c(100, 200)))
output_dir <- get_arg("output-dir", file.path(project_dir, "output", "final"))
cores <- parallel_cores(default = 1L)

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

sim_torus_pair <- function(n, scenario, seed, kappa_noise = 4) {
  restore <- seed_guard(seed)
  on.exit(restore(), add = TRUE)
  X <- matrix(stats::runif(2 * n, 0, two_pi()), ncol = 2)
  if (scenario == "T0_independent") {
    Y <- matrix(stats::runif(2 * n, 0, two_pi()), ncol = 2)
  } else if (scenario == "T1_coordinate_coupled") {
    eps <- rvonmises_base(n, 0, kappa_noise)
    Y <- cbind(
      wrap_angle(X[, 1] + eps),
      stats::runif(n, 0, two_pi())
    )
  } else {
    stop("Unknown torus scenario.", call. = FALSE)
  }
  list(X = X, Y = Y)
}

run_torus_rep <- function(scenario, n, rep) {
  scenario_index <- match(scenario, c("T0_independent", "T1_coordinate_coupled"))
  seed <- seed0 + 8000000L + 100000L * scenario_index + 1000L * n + rep
  dat <- sim_torus_pair(n, scenario, seed)
  test <- perm_hsic_single(
    torus_vm_kernel(dat$X, c(2, 2)),
    torus_vm_kernel(dat$Y, c(2, 2)),
    B = B,
    seed = seed + 1L
  )
  data.frame(
    kind = "torus_demo",
    scenario = scenario,
    n = n,
    effect = ifelse(scenario == "T0_independent", 0, 4),
    method = "HSIC torus product",
    statistic = test$statistic,
    p.value = test$p.value,
    repetition = rep,
    B = B,
    seed = seed,
    stringsAsFactors = FALSE
  )
}

jobs <- expand.grid(
  scenario = c("T0_independent", "T1_coordinate_coupled"),
  n = n_values,
  repetition = seq_len(R_total),
  stringsAsFactors = FALSE
)

message(sprintf("Torus demonstration: jobs=%s R=%s B=%s", nrow(jobs), R_total, B))
rows <- parallel_lapply(
  seq_len(nrow(jobs)),
  function(i) run_torus_rep(jobs$scenario[i], jobs$n[i], jobs$repetition[i]),
  cores = cores
)
raw <- do.call(rbind, rows)
raw$reject <- raw$p.value <= alpha
summary <- summarise_rejections(raw, c("kind", "scenario", "n", "effect", "method"),
                                alpha = alpha)
summary$B <- B
summary$alpha <- alpha
summary$target_R <- R_total
summary$completed <- summary$R >= R_total

write_csv(raw, file.path(output_dir, "torus_demo_raw.csv"))
write_csv(summary, file.path(output_dir, "torus_demo_summary.csv"))

message("Torus demonstration complete.")
