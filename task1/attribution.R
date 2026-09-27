# Завдання 1: частка неатрибутованих реєстрацій по джерелах.
# Метод A — ланцюжок по періодах запуску джерел; перевірка B — одна модель на всіх днях.
# Методологія: hypotheses/t1-attribution.md, розділ «Погоджена методологія».

data_path   <- Sys.getenv("T1_DATA", "task1(attribution).csv")
n_boot      <- as.integer(Sys.getenv("T1_N_BOOT", "2000"))
max_diff_pp <- 1
set.seed(42)

raw <- read.csv(data_path)
sources <- setdiff(names(raw), c("day", "unattributed"))

# День, де всі колонки 0, — відсутність даних, а не нуль реєстрацій
empty_days <- raw$day[rowSums(raw[, -1]) == 0]
d <- raw[rowSums(raw[, -1]) > 0, ]

# Період = набір активних джерел; новий період починається з першого дня нового джерела
launch  <- sort(sapply(sources, function(s) min(d$day[d[[s]] > 0])))
sources <- names(launch)
d$period <- findInterval(d$day, launch)

to_unattr <- function(attributed, share) attributed * share / (1 - share)

# ---- Метод A
chain_shares <- function(d) {
  share <- setNames(rep(NA_real_, length(sources)), sources)
  for (i in seq_along(sources)) {
    p <- d[d$period == i, ]
    expected <- sum(vapply(sources[seq_len(i - 1)],
                           function(s) to_unattr(sum(p[[s]]), share[[s]]), numeric(1)))
    rest <- sum(p$unattributed) - expected
    share[i] <- rest / (sum(p[[sources[i]]]) + rest)
  }
  share
}

# Бутстреп по днях усередині періодів, щоб кожен повтор мав усі періоди
boot_ci <- function(d, fun, n) {
  idx_by_period <- split(seq_len(nrow(d)), d$period)
  draws <- replicate(n, {
    idx <- unlist(lapply(idx_by_period, function(i) i[sample.int(length(i), replace = TRUE)]))
    fun(d[idx, ])
  })
  apply(draws, 1, quantile, c(0.025, 0.975))
}

# ---- Перевірка B
# Неатрибутовані за день — пуассонівський лічильник із середнім Σ k_s · attributed_s;
# k ≥ 0 тримає частку k / (1 + k) у межах 0–100%
model_shares <- function(d) {
  X <- as.matrix(d[, sources]); y <- d$unattributed
  nll <- function(k) { mu <- pmax(X %*% k, 1e-9); sum(mu - y * log(mu)) }
  k <- optim(rep(0.1, length(sources)), nll, method = "L-BFGS-B", lower = 0)$par
  setNames(k / (1 + k), sources)
}

# ---- Розбіжність: частка джерела окремо в кожному періоді, інші джерела — з A
share_by_period <- function(d, src, share_a) {
  periods <- sort(unique(d$period[d[[src]] > 0]))
  others  <- setdiff(sources, src)
  do.call(rbind, lapply(periods, function(i) {
    p <- d[d$period == i, ]
    active <- others[vapply(others, function(s) sum(p[[s]]) > 0, logical(1))]
    expected <- sum(vapply(active, function(s) to_unattr(sum(p[[s]]), share_a[[s]]), numeric(1)))
    rest <- sum(p$unattributed) - expected
    data.frame(source = src, period = i, days = nrow(p),
               from_day = min(p$day), to_day = max(p$day),
               share_pct = round(100 * rest / (sum(p[[src]]) + rest), 2))
  }))
}

# ---- Прогін
share_a <- chain_shares(d)
ci_a    <- boot_ci(d, chain_shares, n_boot)
share_b <- model_shares(d)

result <- data.frame(
  source     = sources,
  launch_day = unname(launch),
  days       = vapply(sources, function(s) sum(d[[s]] > 0), integer(1)),
  attributed = vapply(sources, function(s) sum(d[[s]]), numeric(1)),
  A_pct      = round(100 * share_a, 2),
  A_lo       = round(100 * ci_a[1, ], 2),
  A_hi       = round(100 * ci_a[2, ], 2),
  B_pct      = round(100 * share_b, 2),
  row.names  = NULL
)
result$diff_pp  <- result$A_pct - result$B_pct
result$diverged <- abs(result$diff_pp) > max_diff_pp

cat("Виключені дні без даних:", empty_days, "\n\n")
print(result, row.names = FALSE)

flagged <- result$source[result$diverged]
if (length(flagged) > 0) {
  cat("\nРозбіжність > ", max_diff_pp, " в.п.: частка по періодах\n", sep = "")
  by_period <- do.call(rbind, lapply(flagged, share_by_period, d = d, share_a = share_a))
  print(by_period, row.names = FALSE)

  # Діапазон для відповіді: від меншого до більшого з A, B і часток по періодах
  cat("\nДіапазон для відповіді\n")
  print(do.call(rbind, lapply(flagged, function(s) {
    v <- c(result$A_pct[result$source == s], result$B_pct[result$source == s],
           by_period$share_pct[by_period$source == s])
    data.frame(source = s, min_pct = min(v), max_pct = max(v))
  })), row.names = FALSE)
}
