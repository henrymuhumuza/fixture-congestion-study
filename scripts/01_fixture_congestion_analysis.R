#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
})

study_start_end_year <- 2018
study_end_end_year <- 2022
study_start_date <- as.Date("2017-07-01")
study_end_date <- as.Date("2022-06-30")
covid_sensitivity_start <- as.Date("2020-03-01")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
dir.create("data/final", recursive = TRUE, showWarnings = FALSE)
dir.create("data/raw/worldfootballR_cups", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)

league_lookup <- tibble::tribble(
  ~div, ~league,
  "E0", "English Premier League",
  "D1", "German Bundesliga",
  "F1", "French Ligue 1",
  "I1", "Italian Serie A",
  "SP1", "Spanish La Liga"
)

parse_season <- function(path) {
  code <- stringr::str_extract(basename(path), "^[0-9]{4}")
  paste0("20", substr(code, 1, 2), "/", substr(code, 3, 4))
}

parse_season_end_year <- function(path) {
  code <- stringr::str_extract(basename(path), "^[0-9]{4}")
  as.integer(paste0("20", substr(code, 3, 4)))
}

parse_match_date <- function(x) {
  x <- as.character(x)
  two_digit_year <- stringr::str_detect(x, "^\\d{1,2}/\\d{1,2}/\\d{2}$")
  parsed_short <- as.Date(x, format = "%d/%m/%y")
  parsed_long <- as.Date(x, format = "%d/%m/%Y")
  if_else(two_digit_year, parsed_short, parsed_long)
}

as_num <- function(x) suppressWarnings(as.numeric(x))

clean_names_local <- function(x) {
  cleaned <- x |>
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") |>
    stringr::str_replace_all("([a-z0-9])([A-Z])", "\\1_\\2") |>
    stringr::str_replace_all("_+", "_") |>
    stringr::str_replace_all("^_|_$", "") |>
    stringr::str_to_lower()
  make.unique(cleaned, sep = "_")
}

read_results_file <- function(path) {
  read.csv(path, check.names = FALSE) |>
    as_tibble() |>
    rename_with(clean_names_local) |>
    mutate(
      source_file = basename(path),
      season = parse_season(path),
      date = parse_match_date(date)
    )
}

safe_col <- function(.data, name, default = NA_real_) {
  if (name %in% names(.data)) .data[[name]] else rep(default, nrow(.data))
}

coalesce_cols <- function(.data, names) {
  cols <- purrr::map(names, \(name) safe_col(.data, name))
  purrr::reduce(cols, dplyr::coalesce)
}

clean_fbref_team <- function(x) {
  x |>
    stringr::str_replace("^[a-z]{2,3} ", "") |>
    stringr::str_replace(" [a-z]{2,3}$", "") |>
    stringr::str_squish()
}

standardise_team_name <- function(x) {
  aliases <- c(
    "Cardiff City" = "Cardiff",
    "Ipswich Town" = "Ipswich",
    "Leeds United" = "Leeds",
    "Leicester City" = "Leicester",
    "Luton Town" = "Luton",
    "Manchester City" = "Man City",
    "Manchester Utd" = "Man United",
    "Newcastle Utd" = "Newcastle",
    "Norwich City" = "Norwich",
    "Nottingham Forest" = "Nott'm Forest",
    "Sheffield Utd" = "Sheffield United",
    "Stoke City" = "Stoke",
    "Swansea City" = "Swansea",
    "Clermont Foot" = "Clermont",
    "Nîmes" = "Nimes",
    "Paris S-G" = "Paris SG",
    "Saint-Étienne" = "St Etienne",
    "Arminia" = "Bielefeld",
    "Darmstadt 98" = "Darmstadt",
    "Eint Frankfurt" = "Ein Frankfurt",
    "Köln" = "FC Koln",
    "Düsseldorf" = "Fortuna Dusseldorf",
    "Greuther Fürth" = "Greuther Furth",
    "Hamburger SV" = "Hamburg",
    "Hertha BSC" = "Hertha",
    "Gladbach" = "M'gladbach",
    "Mainz 05" = "Mainz",
    "Nürnberg" = "Nurnberg",
    "Paderborn 07" = "Paderborn",
    "St. Pauli" = "St Pauli",
    "SPAL" = "Spal",
    "Hellas Verona" = "Verona",
    "Alavés" = "Alaves",
    "Almería" = "Almeria",
    "Athletic Club" = "Ath Bilbao",
    "Atlético Madrid" = "Ath Madrid",
    "Cádiz" = "Cadiz",
    "Celta Vigo" = "Celta",
    "Espanyol" = "Espanol",
    "Deportivo La Coruña" = "La Coruna",
    "Leganés" = "Leganes",
    "Málaga" = "Malaga",
    "Real Sociedad" = "Sociedad",
    "Rayo Vallecano" = "Vallecano"
  )
  x <- clean_fbref_team(x)
  unname(ifelse(x %in% names(aliases), aliases[x], x))
}

season_from_end_year <- function(x) {
  end_year <- as.integer(x)
  paste0(end_year - 1, "/", stringr::str_sub(as.character(end_year), 3, 4))
}

raw_files <- list.files("data/raw/football_data_uk", pattern = "\\.csv$", full.names = TRUE)
raw_files <- raw_files[
  purrr::map_int(raw_files, parse_season_end_year) >= study_start_end_year &
    purrr::map_int(raw_files, parse_season_end_year) <= study_end_end_year
]
if (length(raw_files) == 0) stop("No Football-Data.co.uk CSV files found in data/raw/football_data_uk")

cat("Reading", length(raw_files), "Football-Data files for seasons ending", study_start_end_year, "to", study_end_end_year, "...\n")
matches <- purrr::map_dfr(raw_files, read_results_file) |>
  left_join(league_lookup, by = c("div" = "div")) |>
  filter(!is.na(date), !is.na(home_team), !is.na(away_team), date >= study_start_date, date <= study_end_date) |>
  mutate(
    match_id = paste(season, div, date, home_team, away_team, sep = "_"),
    across(any_of(c(
      "fthg", "ftag", "hs", "as", "hst", "ast", "hf", "af", "hc", "ac", "hy", "ay", "hr", "ar",
      "avg_h", "avg_d", "avg_a", "avg_ch", "avg_cd", "avg_ca",
      "b365_h", "b365_d", "b365_a", "b365_ch", "b365_cd", "b365_ca",
      "psh", "psd", "psa", "psch", "pscd", "psca"
    )), as_num)
  )

home_rows <- matches |>
  transmute(
    match_id, season, league, div, date,
    team = home_team,
    opponent = away_team,
    home_away = "Home",
    goals_for = fthg,
    goals_against = ftag,
    shots_for = hs,
    shots_against = `as`,
    sot_for = hst,
    sot_against = ast,
    corners_for = hc,
    corners_against = ac,
    fouls_for = hf,
    fouls_against = af,
    yellow_cards = hy,
    yellow_cards_against = ay,
    red_cards = hr,
    red_cards_against = ar,
    team_closing_odds = coalesce_cols(matches, c("avg_ch", "avg_h", "b365_ch", "b365_h", "psch", "psh")),
    draw_closing_odds = coalesce_cols(matches, c("avg_cd", "avg_d", "b365_cd", "b365_d", "pscd", "psd")),
    opponent_closing_odds = coalesce_cols(matches, c("avg_ca", "avg_a", "b365_ca", "b365_a", "psca", "psa"))
  )

away_rows <- matches |>
  transmute(
    match_id, season, league, div, date,
    team = away_team,
    opponent = home_team,
    home_away = "Away",
    goals_for = ftag,
    goals_against = fthg,
    shots_for = `as`,
    shots_against = hs,
    sot_for = ast,
    sot_against = hst,
    corners_for = ac,
    corners_against = hc,
    fouls_for = af,
    fouls_against = hf,
    yellow_cards = ay,
    yellow_cards_against = hy,
    red_cards = ar,
    red_cards_against = hr,
    team_closing_odds = coalesce_cols(matches, c("avg_ca", "avg_a", "b365_ca", "b365_a", "psca", "psa")),
    draw_closing_odds = coalesce_cols(matches, c("avg_cd", "avg_d", "b365_cd", "b365_d", "pscd", "psd")),
    opponent_closing_odds = coalesce_cols(matches, c("avg_ch", "avg_h", "b365_ch", "b365_h", "psch", "psh"))
  )

team_match_base <- bind_rows(home_rows, away_rows) |>
  mutate(
    team_id = paste(league, team, sep = "::"),
    opponent_id = paste(league, opponent, sep = "::"),
    goal_difference = goals_for - goals_against,
    shot_difference = shots_for - shots_against,
    sot_difference = sot_for - sot_against,
    corner_difference = corners_for - corners_against,
    foul_difference = fouls_for - fouls_against,
    card_difference = (yellow_cards + red_cards) - (yellow_cards_against + red_cards_against),
    points = case_when(
      goal_difference > 0 ~ 3,
      goal_difference == 0 ~ 1,
      goal_difference < 0 ~ 0,
      TRUE ~ NA_real_
    ),
    win = as.integer(goal_difference > 0),
    team_implied_raw = 1 / team_closing_odds,
    draw_implied_raw = 1 / draw_closing_odds,
    opponent_implied_raw = 1 / opponent_closing_odds,
    implied_total = team_implied_raw + draw_implied_raw + opponent_implied_raw,
    team_win_prob = team_implied_raw / implied_total,
    opponent_win_prob = opponent_implied_raw / implied_total,
    odds_strength_gap = team_win_prob - opponent_win_prob
  )

read_cup_schedule <- function(league_team_reference) {
  cup_files <- list.files("data/raw/worldfootballR_cups", pattern = "_match_results\\.rds$", full.names = TRUE)
  if (length(cup_files) == 0) {
    cli::cli_alert_warning("No cup/European RDS files found in data/raw/worldfootballR_cups; using league-only schedule.")
    return(tibble())
  }

  read_one_cup <- function(path) {
    readRDS(path) |>
      as_tibble() |>
      mutate(source_file = basename(path))
  }

  league_teams <- league_team_reference |>
    distinct(team, league, team_id)

  cup_raw <- purrr::map_dfr(cup_files, read_one_cup) |>
    filter(Gender == "M", !is.na(Date), Season_End_Year >= study_start_end_year, Season_End_Year <= study_end_end_year) |>
    mutate(
      date = as.Date(Date),
      season = season_from_end_year(Season_End_Year),
      competition_group = case_when(
        Competition_Name %in% c("UEFA Champions League", "UEFA Europa League", "UEFA Europa Conference League") ~ "European",
        TRUE ~ "Domestic cup"
      ),
      is_european = competition_group == "European",
      is_domestic_cup = competition_group == "Domestic cup",
      home_team_std = standardise_team_name(Home),
      away_team_std = standardise_team_name(Away),
      cup_match_id = paste(source_file, Season_End_Year, date, home_team_std, away_team_std, sep = "_")
    ) |>
    filter(date >= study_start_date, date <= study_end_date)

  home_cup <- cup_raw |>
    transmute(
      match_id = cup_match_id,
      season,
      date,
      team = home_team_std,
      opponent = away_team_std,
      home_away = "Home",
      competition_name = Competition_Name,
      competition_group,
      is_european,
      is_domestic_cup,
      schedule_source = source_file
    )

  away_cup <- cup_raw |>
    transmute(
      match_id = cup_match_id,
      season,
      date,
      team = away_team_std,
      opponent = home_team_std,
      home_away = "Away",
      competition_name = Competition_Name,
      competition_group,
      is_european,
      is_domestic_cup,
      schedule_source = source_file
    )

  bind_rows(home_cup, away_cup) |>
    inner_join(league_teams, by = "team") |>
    mutate(
      league = as.character(league),
      home_away = factor(home_away, levels = c("Home", "Away"))
    ) |>
    distinct(match_id, team_id, .keep_all = TRUE)
}

add_workload_history <- function(df) {
  df <- arrange(df, date, match_id)
  n <- nrow(df)
  idx <- seq_len(n)
  previous_match_date <- lag(df$date)
  tibble::as_tibble(df) |>
    mutate(
      previous_match_date = previous_match_date,
      rest_days = as.numeric(date - previous_match_date),
      matches_prev_7 = purrr::map_int(idx, \(i) sum(df$date < df$date[i] & df$date >= df$date[i] - 7)),
      matches_prev_14 = purrr::map_int(idx, \(i) sum(df$date < df$date[i] & df$date >= df$date[i] - 14)),
      matches_prev_28 = purrr::map_int(idx, \(i) sum(df$date < df$date[i] & df$date >= df$date[i] - 28)),
      european_matches_prev_7 = purrr::map_int(idx, \(i) sum(df$is_european[df$date < df$date[i] & df$date >= df$date[i] - 7], na.rm = TRUE)),
      european_matches_prev_14 = purrr::map_int(idx, \(i) sum(df$is_european[df$date < df$date[i] & df$date >= df$date[i] - 14], na.rm = TRUE)),
      domestic_cup_matches_prev_7 = purrr::map_int(idx, \(i) sum(df$is_domestic_cup[df$date < df$date[i] & df$date >= df$date[i] - 7], na.rm = TRUE)),
      away_matches_prev_7 = purrr::map_int(idx, \(i) sum(df$home_away == "Away" & df$date < df$date[i] & df$date >= df$date[i] - 7, na.rm = TRUE)),
      previous_competition_group = lag(competition_group),
      previous_match_was_european = lag(is_european, default = FALSE),
      previous_match_was_domestic_cup = lag(is_domestic_cup, default = FALSE)
    )
}

add_league_form <- function(df) {
  df <- arrange(df, date, match_id)
  n <- nrow(df)
  idx <- seq_len(n)
  tibble::as_tibble(df) |>
    mutate(
      team_strength_roll = purrr::map_dbl(idx, \(i) if (i == 1) NA_real_ else mean(tail(df$points[seq_len(i - 1)], 10), na.rm = TRUE)),
      team_attack_roll = purrr::map_dbl(idx, \(i) if (i == 1) NA_real_ else mean(tail(df$goals_for[seq_len(i - 1)], 10), na.rm = TRUE)),
      team_defense_roll = purrr::map_dbl(idx, \(i) if (i == 1) NA_real_ else mean(tail(df$goals_against[seq_len(i - 1)], 10), na.rm = TRUE))
    )
}

cat("Building team-match panel, cup schedule, and workload variables...\n")
league_schedule <- team_match_base |>
  transmute(
    match_id,
    season,
    league = as.character(league),
    date,
    team,
    opponent,
    team_id,
    home_away,
    competition_name = as.character(league),
    competition_group = "League",
    is_european = FALSE,
    is_domestic_cup = FALSE,
    schedule_source = "Football-Data.co.uk"
  )

cup_schedule <- read_cup_schedule(team_match_base |> distinct(team, league, team_id))

combined_schedule <- bind_rows(league_schedule, cup_schedule) |>
  arrange(team_id, season, date, match_id)

workload_history <- combined_schedule |>
  group_by(team_id, season) |>
  group_modify(~ add_workload_history(.x)) |>
  ungroup()

workload_for_league_matches <- workload_history |>
  filter(competition_group == "League") |>
  select(
    match_id, team_id, team,
    previous_match_date, rest_days, matches_prev_7, matches_prev_14, matches_prev_28,
    european_matches_prev_7, european_matches_prev_14, domestic_cup_matches_prev_7,
    away_matches_prev_7, previous_competition_group, previous_match_was_european,
    previous_match_was_domestic_cup
  )

team_match <- team_match_base |>
  group_by(team_id, season) |>
  group_modify(~ add_league_form(.x)) |>
  ungroup() |>
  left_join(workload_for_league_matches, by = c("match_id", "team_id", "team")) |>
  group_by(season, league, team) |>
  mutate(team_match_number = row_number(date), season_progress = percent_rank(date)) |>
  ungroup() |>
  mutate(
    rest_category = case_when(
      is.na(rest_days) ~ NA_character_,
      rest_days <= 3 ~ "<=3 days",
      rest_days <= 5 ~ "4-5 days",
      rest_days <= 7 ~ "6-7 days",
      rest_days >= 8 ~ ">=8 days"
    ),
    rest_category = factor(rest_category, levels = c(">=8 days", "6-7 days", "4-5 days", "<=3 days")),
    home_away = factor(home_away, levels = c("Home", "Away")),
    league = factor(league),
    season = factor(season),
    short_rest = rest_days <= 3,
    away_after_short_rest = short_rest & home_away == "Away",
    previous_match_was_european = replace_na(previous_match_was_european, FALSE),
    previous_match_was_domestic_cup = replace_na(previous_match_was_domestic_cup, FALSE),
    domestic_after_europe = previous_match_was_european,
    away_after_europe = previous_match_was_european & home_away == "Away"
  )

opponent_strength <- team_match |>
  select(match_id, team, team_strength_roll) |>
  rename(opponent = team, opponent_strength_roll = team_strength_roll)

team_match <- team_match |>
  left_join(opponent_strength, by = c("match_id", "opponent")) |>
  mutate(
    team_strength_roll = if_else(is.nan(team_strength_roll), NA_real_, team_strength_roll),
    opponent_strength_roll = if_else(is.nan(opponent_strength_roll), NA_real_, opponent_strength_roll)
  )

analysis_data <- team_match |>
  filter(
    !is.na(rest_category),
    !is.na(team_strength_roll),
    !is.na(opponent_strength_roll),
    !is.na(odds_strength_gap),
    !is.na(season_progress),
    !is.na(shot_difference),
    !is.na(sot_difference),
    !is.na(goal_difference),
    !is.na(foul_difference),
    !is.na(card_difference),
    !is.na(win),
    !is.na(matches_prev_7),
    !is.na(european_matches_prev_7),
    !is.na(domestic_cup_matches_prev_7),
    !is.na(away_matches_prev_7)
  ) |>
  mutate(across(
    c(team_strength_roll, opponent_strength_roll, odds_strength_gap, season_progress),
    \(x) as.numeric(scale(x)),
    .names = "{.col}_z"
  ))

write_rds(team_match, "data/processed/team_match_all.rds")
write_rds(analysis_data, "data/processed/team_match_analysis.rds")
write_rds(combined_schedule, "data/processed/combined_schedule_all_competitions.rds")
readr::write_csv(team_match, "data/final/team_match_all.csv")
readr::write_csv(analysis_data, "data/final/team_match_analysis.csv")
readr::write_csv(combined_schedule, "data/final/combined_schedule_all_competitions.csv")

cat("Fitting mixed-effects models...\n")
model_formula <- shot_difference ~ rest_category + home_away + team_strength_roll_z +
  opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
  matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
  away_matches_prev_7 + previous_match_was_european +
  (1 | team_id) + (1 | opponent_id)

model_shot <- lmer(model_formula, data = analysis_data, REML = TRUE)

model_goal <- lmer(
  goal_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = analysis_data,
  REML = TRUE
)

model_sot <- lmer(
  sot_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = analysis_data,
  REML = TRUE
)

model_foul <- lmer(
  foul_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = analysis_data,
  REML = TRUE
)

model_card <- lmer(
  card_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = analysis_data,
  REML = TRUE
)

model_win <- glmer(
  win ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = analysis_data,
  family = binomial(link = "logit"),
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

covid_sensitivity_data <- analysis_data |>
  filter(!(season == "2019/20" & date >= covid_sensitivity_start))

model_shot_covid_sens <- lmer(model_formula, data = covid_sensitivity_data, REML = TRUE)

model_goal_covid_sens <- lmer(
  goal_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = covid_sensitivity_data,
  REML = TRUE
)

model_sot_covid_sens <- lmer(
  sot_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = covid_sensitivity_data,
  REML = TRUE
)

model_foul_covid_sens <- lmer(
  foul_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = covid_sensitivity_data,
  REML = TRUE
)

model_card_covid_sens <- lmer(
  card_difference ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = covid_sensitivity_data,
  REML = TRUE
)

model_win_covid_sens <- glmer(
  win ~ rest_category + home_away + team_strength_roll_z +
    opponent_strength_roll_z + odds_strength_gap_z + league + season + season_progress_z +
    matches_prev_7 + european_matches_prev_7 + domestic_cup_matches_prev_7 +
    away_matches_prev_7 + previous_match_was_european +
    (1 | team_id) + (1 | opponent_id),
  data = covid_sensitivity_data,
  family = binomial(link = "logit"),
  control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
)

coef_table <- function(model, outcome) {
  coefs <- coef(summary(model))
  tibble::as_tibble(coefs, rownames = "term") |>
    rename(estimate = Estimate, std_error = `Std. Error`, t_value = `t value`) |>
    mutate(outcome = outcome, conf_low = estimate - 1.96 * std_error, conf_high = estimate + 1.96 * std_error) |>
    select(outcome, term, estimate, std_error, conf_low, conf_high, t_value)
}

rest_terms <- bind_rows(
  coef_table(model_shot, "Shot difference"),
  coef_table(model_sot, "Shots-on-target difference"),
  coef_table(model_goal, "Goal difference"),
  coef_table(model_foul, "Foul difference"),
  coef_table(model_card, "Card difference")
) |>
  filter(str_detect(term, "^rest_category")) |>
  mutate(
    contrast = str_remove(term, "^rest_category"),
    reference = ">=8 days"
  )

win_odds_terms <- coef(summary(model_win)) |>
  tibble::as_tibble(rownames = "term") |>
  rename(estimate_log_odds = Estimate, std_error = `Std. Error`, z_value = `z value`, p_value = `Pr(>|z|)`) |>
  filter(str_detect(term, "^rest_category")) |>
  mutate(
    outcome = "Win",
    contrast = str_remove(term, "^rest_category"),
    reference = ">=8 days",
    odds_ratio = exp(estimate_log_odds),
    conf_low = exp(estimate_log_odds - 1.96 * std_error),
    conf_high = exp(estimate_log_odds + 1.96 * std_error)
  ) |>
  select(outcome, contrast, reference, odds_ratio, conf_low, conf_high, estimate_log_odds, std_error, z_value, p_value)

win_odds_terms_covid_sens <- coef(summary(model_win_covid_sens)) |>
  tibble::as_tibble(rownames = "term") |>
  rename(estimate_log_odds = Estimate, std_error = `Std. Error`, z_value = `z value`, p_value = `Pr(>|z|)`) |>
  filter(str_detect(term, "^rest_category")) |>
  mutate(
    analysis = "Exclude COVID restart: 2019/20 matches from 2020-03-01 onward",
    outcome = "Win",
    contrast = str_remove(term, "^rest_category"),
    reference = ">=8 days",
    odds_ratio = exp(estimate_log_odds),
    conf_low = exp(estimate_log_odds - 1.96 * std_error),
    conf_high = exp(estimate_log_odds + 1.96 * std_error)
  ) |>
  select(analysis, outcome, contrast, reference, odds_ratio, conf_low, conf_high, estimate_log_odds, std_error, z_value, p_value)

descriptive <- analysis_data |>
  group_by(rest_category) |>
  summarise(
    team_matches = n(),
    teams = n_distinct(team_id),
    mean_rest_days = mean(rest_days),
    mean_goal_difference = mean(goal_difference, na.rm = TRUE),
    mean_shot_difference = mean(shot_difference, na.rm = TRUE),
    mean_sot_difference = mean(sot_difference, na.rm = TRUE),
    mean_foul_difference = mean(foul_difference, na.rm = TRUE),
    mean_card_difference = mean(card_difference, na.rm = TRUE),
    mean_points = mean(points, na.rm = TRUE),
    away_share = mean(home_away == "Away"),
    .groups = "drop"
  )

sample_summary <- analysis_data |>
  summarise(
    team_matches = n(),
    matches = n_distinct(match_id),
    teams = n_distinct(team_id),
    seasons = n_distinct(season),
    leagues = n_distinct(league),
    earliest_match = min(date),
    latest_match = max(date),
    short_rest_team_matches = sum(rest_category == "<=3 days"),
    short_rest_share = mean(rest_category == "<=3 days"),
    study_start_end_year = study_start_end_year,
    study_end_end_year = study_end_end_year,
    study_start_date = study_start_date,
    study_end_date = study_end_date
  )

sensitivity_summary <- tibble::tibble(
  analysis = c("Main analysis", "Exclude COVID restart: 2019/20 matches from 2020-03-01 onward"),
  team_matches = c(nrow(analysis_data), nrow(covid_sensitivity_data)),
  matches = c(n_distinct(analysis_data$match_id), n_distinct(covid_sensitivity_data$match_id)),
  teams = c(n_distinct(analysis_data$team_id), n_distinct(covid_sensitivity_data$team_id)),
  short_rest_team_matches = c(
    sum(analysis_data$rest_category == "<=3 days"),
    sum(covid_sensitivity_data$rest_category == "<=3 days")
  ),
  short_rest_share = c(
    mean(analysis_data$rest_category == "<=3 days"),
    mean(covid_sensitivity_data$rest_category == "<=3 days")
  )
)

schedule_summary <- combined_schedule |>
  group_by(competition_group, competition_name, schedule_source) |>
  summarise(
    team_match_rows = n(),
    teams_matched_to_big_five = n_distinct(team_id),
    earliest_match = min(date, na.rm = TRUE),
    latest_match = max(date, na.rm = TRUE),
    .groups = "drop"
  ) |>
  arrange(competition_group, competition_name, schedule_source)

workload_summary <- analysis_data |>
  summarise(
    team_matches = n(),
    any_previous_european_7 = sum(european_matches_prev_7 > 0, na.rm = TRUE),
    share_previous_european_7 = mean(european_matches_prev_7 > 0, na.rm = TRUE),
    any_previous_domestic_cup_7 = sum(domestic_cup_matches_prev_7 > 0, na.rm = TRUE),
    share_previous_domestic_cup_7 = mean(domestic_cup_matches_prev_7 > 0, na.rm = TRUE),
    any_previous_away_7 = sum(away_matches_prev_7 > 0, na.rm = TRUE),
    share_previous_away_7 = mean(away_matches_prev_7 > 0, na.rm = TRUE),
    previous_match_european = sum(previous_match_was_european, na.rm = TRUE),
    share_previous_match_european = mean(previous_match_was_european, na.rm = TRUE)
  )

model_fit <- tibble::tibble(
  outcome = c("Shot difference", "Shots-on-target difference", "Goal difference", "Foul difference", "Card difference", "Win"),
  n = c(nobs(model_shot), nobs(model_sot), nobs(model_goal), nobs(model_foul), nobs(model_card), nobs(model_win)),
  aic = c(AIC(model_shot), AIC(model_sot), AIC(model_goal), AIC(model_foul), AIC(model_card), AIC(model_win)),
  sigma = c(sigma(model_shot), sigma(model_sot), sigma(model_goal), sigma(model_foul), sigma(model_card), NA_real_)
)

covid_sensitivity_effects <- bind_rows(
  coef_table(model_shot_covid_sens, "Shot difference"),
  coef_table(model_sot_covid_sens, "Shots-on-target difference"),
  coef_table(model_goal_covid_sens, "Goal difference"),
  coef_table(model_foul_covid_sens, "Foul difference"),
  coef_table(model_card_covid_sens, "Card difference")
) |>
  filter(str_detect(term, "^rest_category")) |>
  mutate(
    analysis = "Exclude COVID restart: 2019/20 matches from 2020-03-01 onward",
    contrast = str_remove(term, "^rest_category"),
    reference = ">=8 days"
  ) |>
  select(analysis, outcome, term, contrast, reference, estimate, std_error, conf_low, conf_high, t_value)

main_effects_labeled <- rest_terms |>
  mutate(analysis = "Main analysis") |>
  select(analysis, outcome, term, contrast, reference, estimate, std_error, conf_low, conf_high, t_value)

covid_sensitivity_table <- bind_rows(main_effects_labeled, covid_sensitivity_effects)

readr::write_csv(descriptive, "outputs/tables/table_1_descriptive_by_rest.csv")
readr::write_csv(rest_terms, "outputs/tables/table_2_adjusted_rest_effects.csv")
readr::write_csv(win_odds_terms, "outputs/tables/table_3_adjusted_win_odds.csv")
readr::write_csv(sample_summary, "outputs/tables/table_s1_sample_summary.csv")
readr::write_csv(model_fit, "outputs/tables/table_s2_model_fit.csv")
readr::write_csv(schedule_summary, "outputs/tables/table_s3_all_competition_schedule_summary.csv")
readr::write_csv(workload_summary, "outputs/tables/table_s4_workload_summary.csv")
readr::write_csv(sensitivity_summary, "outputs/tables/table_s5_covid_sensitivity_sample.csv")
readr::write_csv(covid_sensitivity_table, "outputs/tables/table_4_covid_sensitivity_effects.csv")
readr::write_csv(win_odds_terms_covid_sens, "outputs/tables/table_5_covid_sensitivity_win_odds.csv")

saveRDS(model_shot, "outputs/tables/model_primary_shot_difference.rds")
saveRDS(model_goal, "outputs/tables/model_sensitivity_goal_difference.rds")
saveRDS(model_sot, "outputs/tables/model_sensitivity_sot_difference.rds")
saveRDS(model_foul, "outputs/tables/model_sensitivity_foul_difference.rds")
saveRDS(model_card, "outputs/tables/model_sensitivity_card_difference.rds")
saveRDS(model_win, "outputs/tables/model_sensitivity_win_odds.rds")
saveRDS(model_shot_covid_sens, "outputs/tables/model_covid_sensitivity_shot_difference.rds")
saveRDS(model_goal_covid_sens, "outputs/tables/model_covid_sensitivity_goal_difference.rds")
saveRDS(model_sot_covid_sens, "outputs/tables/model_covid_sensitivity_sot_difference.rds")
saveRDS(model_foul_covid_sens, "outputs/tables/model_covid_sensitivity_foul_difference.rds")
saveRDS(model_card_covid_sens, "outputs/tables/model_covid_sensitivity_card_difference.rds")
saveRDS(model_win_covid_sens, "outputs/tables/model_covid_sensitivity_win_odds.rds")

rest_palette <- c(">=8 days" = "#4c78a8", "6-7 days" = "#72b7b2", "4-5 days" = "#f58518", "<=3 days" = "#e45756")
rest_plot_labels <- c(">=8 days" = "\u22658 days", "6-7 days" = "6-7 days", "4-5 days" = "4-5 days", "<=3 days" = "\u22643 days")

p1 <- ggplot(analysis_data, aes(rest_category, fill = rest_category)) +
  geom_bar(width = 0.72, show.legend = FALSE) +
  geom_text(stat = "count", aes(label = scales::comma(after_stat(count))), vjust = -0.25, size = 3.2) +
  scale_fill_manual(values = rest_palette) +
  scale_x_discrete(labels = rest_plot_labels) +
  labs(x = "Rest before match", y = "Team-matches") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())

ggsave("outputs/figures/figure_1_rest_category_counts.png", p1, width = 7, height = 4.5, dpi = 300)

p2 <- analysis_data |>
  mutate(rest_days_capped = pmin(rest_days, 21)) |>
  ggplot(aes(rest_days_capped)) +
  geom_histogram(binwidth = 1, boundary = 0, fill = "#72b7b2", colour = "white") +
  labs(x = "Rest days before match, capped at 21", y = "Team-matches") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank())

ggsave("outputs/figures/figure_2_rest_days_histogram.png", p2, width = 7, height = 4.5, dpi = 300)

p3 <- ggplot(analysis_data, aes(rest_category, shot_difference, fill = rest_category)) +
  geom_hline(yintercept = 0, colour = "grey65", linewidth = 0.3) +
  geom_boxplot(outlier.alpha = 0.08, width = 0.65, colour = "grey25", show.legend = FALSE) +
  scale_fill_manual(values = rest_palette) +
  scale_x_discrete(labels = rest_plot_labels) +
  labs(x = "Rest before match", y = "Shot difference") +
  theme_minimal(base_size = 11)

ggsave("outputs/figures/figure_3_shot_difference_by_rest.png", p3, width = 7, height = 4.5, dpi = 300)

p4 <- ggplot(analysis_data, aes(rest_category, sot_difference, fill = rest_category)) +
  geom_hline(yintercept = 0, colour = "grey65", linewidth = 0.3) +
  geom_boxplot(outlier.alpha = 0.08, width = 0.65, colour = "grey25", show.legend = FALSE) +
  scale_fill_manual(values = rest_palette) +
  scale_x_discrete(labels = rest_plot_labels) +
  labs(x = "Rest before match", y = "Shots-on-target difference") +
  theme_minimal(base_size = 11)

ggsave("outputs/figures/figure_4_sot_difference_by_rest.png", p4, width = 7, height = 4.5, dpi = 300)

p5_data <- analysis_data |>
  group_by(rest_category) |>
  summarise(win_rate = mean(win), n = n(), .groups = "drop")

p5 <- ggplot(p5_data, aes(rest_category, win_rate, fill = rest_category)) +
  geom_col(width = 0.72, show.legend = FALSE) +
  geom_text(aes(label = scales::percent(win_rate, accuracy = 0.1)), vjust = -0.25, size = 3.2) +
  scale_y_continuous(labels = scales::percent, limits = c(0, max(p5_data$win_rate) + 0.08)) +
  scale_fill_manual(values = rest_palette) +
  scale_x_discrete(labels = rest_plot_labels) +
  labs(x = "Rest before match", y = "Observed win rate") +
  theme_minimal(base_size = 11)

ggsave("outputs/figures/figure_5_win_rate_by_rest.png", p5, width = 7, height = 4.5, dpi = 300)

p6 <- ggplot(analysis_data, aes(factor(matches_prev_7), fill = rest_category)) +
  geom_bar(position = "dodge", width = 0.72) +
  scale_fill_manual(values = rest_palette, labels = rest_plot_labels, name = "Rest") +
  labs(x = "Matches in previous 7 days", y = "Team-matches") +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")

ggsave("outputs/figures/figure_6_recent_match_load.png", p6, width = 7, height = 4.5, dpi = 300)

p7 <- analysis_data |>
  filter(rest_days <= 21) |>
  ggplot(aes(rest_days, shot_difference)) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
  geom_jitter(alpha = 0.12, width = 0.15, height = 0, colour = "#4c78a8", size = 0.7) +
  geom_smooth(method = "loess", formula = y ~ x, se = TRUE, colour = "#e45756", fill = "#f4a6a6") +
  labs(x = "Rest days before match", y = "Shot difference") +
  theme_minimal(base_size = 11)

ggsave("outputs/figures/figure_7_rest_days_shot_scatter.png", p7, width = 7, height = 4.5, dpi = 300)

plot_terms <- rest_terms |>
  mutate(
    contrast = factor(contrast, levels = c("6-7 days", "4-5 days", "<=3 days")),
    outcome = factor(outcome, levels = c("Shot difference", "Shots-on-target difference", "Goal difference"))
  )

p8 <- ggplot(plot_terms, aes(estimate, contrast)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.3) +
  geom_errorbar(aes(xmin = conf_low, xmax = conf_high), width = 0.15, colour = "#2c7fb8") +
  geom_point(size = 2.2, colour = "#253494") +
  facet_wrap(~ outcome, scales = "free_x") +
  scale_y_discrete(labels = rest_plot_labels) +
  labs(x = "Adjusted difference versus \u22658 days rest", y = "Rest interval") +
  theme_minimal(base_size = 11)

p8 <- p8 + theme(strip.text = element_text(face = "bold"))

ggsave("outputs/figures/figure_8_adjusted_rest_effects.png", p8, width = 8, height = 4.5, dpi = 300)

p9 <- win_odds_terms |>
  mutate(contrast = factor(contrast, levels = c("6-7 days", "4-5 days", "<=3 days"))) |>
  ggplot(aes(odds_ratio, contrast)) +
  geom_vline(xintercept = 1, colour = "grey60", linewidth = 0.3) +
  geom_errorbar(aes(xmin = conf_low, xmax = conf_high), width = 0.15, colour = "#2c7fb8") +
  geom_point(size = 2.2, colour = "#253494") +
  scale_x_log10() +
  scale_y_discrete(labels = rest_plot_labels) +
  labs(x = "Adjusted odds ratio for winning versus \u22658 days", y = "Rest interval") +
  theme_minimal(base_size = 11)

ggsave("outputs/figures/figure_9_adjusted_win_odds.png", p9, width = 7, height = 4.5, dpi = 300)

cat("Fixture congestion analysis complete.\n")
cat("Team-match rows:", nrow(team_match), "\n")
cat("Analysis rows:", nrow(analysis_data), "\n")
