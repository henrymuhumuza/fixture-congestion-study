#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
})

dir.create("data/raw/football_data_uk", recursive = TRUE, showWarnings = FALSE)
dir.create("data/raw/worldfootballR_cups", recursive = TRUE, showWarnings = FALSE)

football_data_seasons <- c("1718", "1819", "1920", "2021", "2122")
football_data_leagues <- c("E0", "D1", "F1", "I1", "SP1")

download_if_missing <- function(url, dest) {
  if (file.exists(dest) && file.info(dest)$size > 0) {
    message("Exists: ", dest)
    return(invisible(dest))
  }

  message("Downloading: ", url)
  utils::download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
  invisible(dest)
}

for (season in football_data_seasons) {
  for (league in football_data_leagues) {
    url <- glue::glue("https://www.football-data.co.uk/mmz4281/{season}/{league}.csv")
    dest <- file.path("data/raw/football_data_uk", glue::glue("{season}_{league}.csv"))
    download_if_missing(url, dest)
  }
}

cup_file_names <- c(
  "uefa_champions_league_match_results.rds",
  "uefa_europa_league_match_results.rds",
  "uefa_europa_conference_league_match_results.rds",
  "fa_cup_match_results.rds",
  "english_football_league_cup_match_results.rds",
  "dfb_pokal_match_results.rds",
  "coppa_italia_match_results.rds",
  "copa_del_rey_match_results.rds",
  "coupe_de_france_match_results.rds"
)

tree_url <- "https://api.github.com/repos/JaseZiv/worldfootballR_data/git/trees/master?recursive=1"
message("Reading worldfootballR_data GitHub tree...")
github_tree <- jsonlite::fromJSON(tree_url)
tree <- tibble::as_tibble(github_tree$tree)

for (file_name in cup_file_names) {
  matches <- tree |>
    filter(type == "blob", basename(path) == file_name)

  if (nrow(matches) == 0) {
    stop("Could not find ", file_name, " in worldfootballR_data GitHub tree.")
  }

  source_path <- matches$path[[1]]
  url <- paste0("https://raw.githubusercontent.com/JaseZiv/worldfootballR_data/master/", source_path)
  dest <- file.path("data/raw/worldfootballR_cups", file_name)
  download_if_missing(url, dest)
}

message("Raw data download complete.")
