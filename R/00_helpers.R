# Helper utilities for the compact directional HSIC paper.

two_pi <- function() 2 * pi

check_numeric_vector <- function(x, name) {
  if (!is.numeric(x) || !is.vector(x) || length(x) == 0L || anyNA(x) ||
      any(!is.finite(x))) {
    stop(sprintf("`%s` must be a non-empty finite numeric vector without missing values.",
                 name), call. = FALSE)
  }
  invisible(x)
}

check_numeric_matrix <- function(x, name) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (is.vector(x) && is.numeric(x)) x <- matrix(x, ncol = 1L)
  if (!is.matrix(x) || !is.numeric(x) || nrow(x) == 0L ||
      ncol(x) == 0L || anyNA(x) || any(!is.finite(x))) {
    stop(sprintf("`%s` must be a finite numeric matrix or data frame without missing values.",
                 name), call. = FALSE)
  }
  x
}

check_positive_scalar <- function(x, name) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    stop(sprintf("`%s` must be a finite positive scalar.", name), call. = FALSE)
  }
  invisible(x)
}

check_positive_integer <- function(x, name, allow_zero = FALSE) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x != floor(x) ||
      x < ifelse(allow_zero, 0L, 1L)) {
    stop(sprintf("`%s` must be %s integer.",
                 name, ifelse(allow_zero, "a non-negative", "a positive")),
         call. = FALSE)
  }
  as.integer(x)
}

check_square_matrix <- function(K, name) {
  if (!is.matrix(K) || !is.numeric(K) || nrow(K) == 0L || nrow(K) != ncol(K) ||
      anyNA(K) || any(!is.finite(K))) {
    stop(sprintf("`%s` must be a finite numeric square matrix.", name),
         call. = FALSE)
  }
  K
}

assert_same_n <- function(...) {
  values <- list(...)
  ns <- vapply(values, length, integer(1))
  if (length(unique(ns)) != 1L) {
    stop("Inputs must have matching lengths.", call. = FALSE)
  }
  invisible(ns[1])
}

read_env_int <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (identical(value, "")) return(as.integer(default))
  out <- suppressWarnings(as.integer(value))
  if (is.na(out) || out < 1L) {
    stop(sprintf("Environment variable `%s` must be a positive integer.", name),
         call. = FALSE)
  }
  out
}

read_env_numvec <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (identical(value, "")) return(default)
  out <- suppressWarnings(as.numeric(strsplit(value, ",", fixed = TRUE)[[1]]))
  if (anyNA(out) || any(!is.finite(out))) {
    stop(sprintf("Environment variable `%s` must be comma-separated finite numeric values.",
                 name), call. = FALSE)
  }
  out
}

seed_guard <- function(seed) {
  if (is.null(seed)) return(function() invisible(TRUE))
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
    stop("`seed` must be NULL or a finite numeric scalar.", call. = FALSE)
  }
  old_seed <- if (exists(".Random.seed", envir = .GlobalEnv)) .Random.seed else NULL
  set.seed(as.integer(seed))
  function() {
    if (is.null(old_seed)) {
      if (exists(".Random.seed", envir = .GlobalEnv)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    } else {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    }
    invisible(TRUE)
  }
}

parallel_cores <- function(default = 1L) {
  requested <- read_env_int("MC_CORES", default)
  available <- parallel::detectCores(logical = TRUE)
  if (is.na(available) || available < 1L) available <- 1L
  max(1L, min(requested, available))
}

parallel_lapply <- function(X, FUN, cores = parallel_cores()) {
  if (cores <= 1L || length(X) <= 1L || .Platform$OS.type == "windows") {
    return(lapply(X, FUN))
  }
  parallel::mclapply(X, FUN, mc.cores = cores, mc.preschedule = FALSE)
}

mc_error <- function(p, R) sqrt(p * (1 - p) / R)

write_csv <- function(x, file) {
  dir.create(dirname(file), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, file, row.names = FALSE)
  invisible(file)
}

summarise_rejections <- function(raw, group_cols, alpha = 0.05) {
  raw$reject <- raw$p.value <= alpha
  f <- stats::as.formula(paste("reject ~", paste(group_cols, collapse = " + ")))
  rate <- stats::aggregate(f, raw, mean)
  reps <- stats::aggregate(f, raw, length)
  names(rate)[names(rate) == "reject"] <- "rejection_rate"
  names(reps)[names(reps) == "reject"] <- "R"
  out <- merge(rate, reps, by = group_cols, sort = FALSE)
  out$mc_error <- mc_error(out$rejection_rate, out$R)
  out
}

script_project_dir <- function() {
  args <- commandArgs(FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0L) {
    return(normalizePath(file.path(dirname(sub("^--file=", "", file_arg[1L])), ".."),
                         mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

load_compact_sources <- function(project_dir) {
  for (file in c("00_helpers.R", "01_kernels_hsic.R",
                 "02_simulate_circular_circular.R",
                 "03_simulate_circular_linear.R")) {
    source(file.path(project_dir, "R", file))
  }
  invisible(TRUE)
}
