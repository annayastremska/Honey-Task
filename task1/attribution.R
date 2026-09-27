# Завдання 1: який % реєстрацій кожного джерела не атрибутується.
# Методологія: hypotheses/t1-attribution.md, розділ «Погоджена методологія».

library(dplyr)

data_path   <- Sys.getenv("T1_DATA", "task1(attribution).csv")
n_boot      <- 2000
max_diff_pp <- 1
set.seed(42)

raw <- read.csv(data_path)
sources <- setdiff(names(raw), c("day", "unattributed"))

# День, де всі колонки 0, — відсутність даних, а не нуль реєстрацій
no_data <- rowSums(raw[, -1]) == 0
d <- raw[!no_data, ]

# Джерела в порядку запуску; новий період починається з першого дня нового джерела
launch_day <- sort(sapply(sources, function(s) min(d$day[d[[s]] > 0])))
sources    <- names(launch_day)
d$period   <- findInterval(d$day, launch_day)

period_totals <- function(d) {
  d |>
    group_by(period) |>
    summarise(across(all_of(c(sources, "unattributed")), sum))
}

# Скільки неатрибутованих дає джерело, якщо відомі його атрибутовані й частка
expected_unattributed <- function(attributed, share) {
  attributed * share / (1 - share)
}


# ---- Метод A: ланцюжок по періодах
# У періоді нового джерела віднімаємо очікуване від старих; решта — від нового
chain_shares <- function(d) {
  totals <- period_totals(d)
  shares <- c()
  for (i in seq_along(sources)) {
    new_source <- sources[i]
    p <- totals[totals$period == i, ]

    expected <- 0
    for (s in names(shares)) {
      expected <- expected + expected_unattributed(p[[s]], shares[[s]])
    }

    rest <- p$unattributed - expected
    shares[new_source] <- rest / (p[[new_source]] + rest)
  }
  shares
}

# Інтервал: перевибірка днів усередині кожного періоду, 2,5% і 97,5% перцентилі
bootstrap_ci <- function(d, n) {
  draws <- replicate(n, {
    resampled <- d |>
      group_by(period) |>
      slice_sample(prop = 1, replace = TRUE) |>
      ungroup()
    chain_shares(resampled)
  })
  apply(draws, 1, quantile, c(0.025, 0.975))
}


# ---- Перевірка B: одна регресія на всіх днях
# Неатрибутовані за день = Σ k · атрибутовані джерела; k — неатрибутовані на 1 атрибутовану
model_shares <- function(d) {
  k <- coef(lm(unattributed ~ 0 + google + facebook + tiktok + snapchat, data = d))
  k / (1 + k)
}


# ---- Якщо A і B розійшлись: частка джерела окремо в кожному періоді
# Частки інших джерел беремо з A
share_by_period <- function(d, source, shares_a) {
  totals <- period_totals(d) |> filter(.data[[source]] > 0)

  expected <- 0
  for (s in setdiff(sources, source)) {
    expected <- expected + expected_unattributed(totals[[s]], shares_a[[s]])
  }

  rest <- totals$unattributed - expected
  data.frame(source    = source,
             period    = totals$period,
             share_pct = round(100 * rest / (totals[[source]] + rest), 2))
}


# ---- Прогін
shares_a <- chain_shares(d)
ci_a     <- bootstrap_ci(d, n_boot)
shares_b <- model_shares(d)

result <- data.frame(
  source     = sources,
  launch_day = unname(launch_day),
  attributed = colSums(d[, sources]),
  A_pct      = round(100 * shares_a, 2),
  A_lo       = round(100 * ci_a[1, ], 2),
  A_hi       = round(100 * ci_a[2, ], 2),
  B_pct      = round(100 * shares_b, 2),
  row.names  = NULL
)
# Різниця — з точних часток, щоб вердикт не залежав від округлення
diff_pp <- 100 * (shares_a - shares_b)
result$diff_pp  <- round(diff_pp, 2)
result$diverged <- abs(diff_pp) > max_diff_pp

cat("Виключені дні без даних:", raw$day[no_data], "\n\n")
print(result)

for (s in result$source[result$diverged]) {
  by_period <- share_by_period(d, s, shares_a)
  all_values <- c(result$A_pct[result$source == s],
                  result$B_pct[result$source == s],
                  by_period$share_pct)

  cat("\n", s, ": A і B розходяться більш ніж на ", max_diff_pp, " в.п.\n", sep = "")
  print(by_period)
  cat("Діапазон для відповіді: ", min(all_values), "–", max(all_values), "%\n", sep = "")
}
