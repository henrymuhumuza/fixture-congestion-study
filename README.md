# Fixture Congestion and Short-Term Performance Decline

This repository contains a repeated-measures team-match analysis of fixture congestion in elite European football.

## Study

**Working title:** Fixture congestion and short-term performance decline in elite European football: a repeated-measures study

**Population:** Big Five men's league matches, 2017/18 through 2021/22, using locally archived Football-Data.co.uk match-result files for outcomes.

**Unit of analysis:** One row per team-match. Each fixture contributes one row for the home team and one row for the away team.

**Exposure:** Days since the team's previous included match in the same season. The workload clock combines domestic league fixtures with locally archived worldfootballR cup-result files for UEFA and domestic cup competitions where available.

- `<=3 days`
- `4-5 days`
- `6-7 days`
- `>=8 days`

**Primary executable outcome:** Shot difference. The originally preferred outcome, xG difference, is not available in the archived Football-Data.co.uk files currently stored in this project.

**Secondary outcomes:** Shots-on-target difference, goal difference, and adjusted odds of winning.

## Reproduce

Run the analysis:

```powershell
& 'C:\Program Files\R\R-4.4.2\bin\Rscript.exe' scripts\01_fixture_congestion_analysis.R
```

Render the manuscript:

```powershell
quarto render manuscript\manuscript.qmd
```

## Key Outputs

- `data/final/team_match_analysis.csv`
- `outputs/tables/table_1_descriptive_by_rest.csv`
- `outputs/tables/table_2_adjusted_rest_effects.csv`
- `outputs/tables/table_3_adjusted_win_odds.csv`
- `outputs/tables/table_4_covid_sensitivity_effects.csv`
- `outputs/tables/table_5_covid_sensitivity_win_odds.csv`
- `outputs/tables/table_s3_all_competition_schedule_summary.csv`
- `outputs/tables/table_s5_covid_sensitivity_sample.csv`
- `outputs/figures/figure_1_rest_category_counts.png`
- `outputs/figures/figure_2_rest_days_histogram.png`
- `outputs/figures/figure_3_shot_difference_by_rest.png`
- `outputs/figures/figure_4_sot_difference_by_rest.png`
- `outputs/figures/figure_5_win_rate_by_rest.png`
- `outputs/figures/figure_6_recent_match_load.png`
- `outputs/figures/figure_7_rest_days_shot_scatter.png`
- `outputs/figures/figure_8_adjusted_rest_effects.png`
- `outputs/figures/figure_9_adjusted_win_odds.png`
- `outputs/manuscript.html`

## Important Scope Note

League outcome rows are domestic league matches only, but workload exposure now includes UEFA Champions League, UEFA Europa League, UEFA Europa Conference League, FA Cup, English Football League Cup, DFB-Pokal, Coppa Italia, Copa del Rey, and Coupe de France fixtures from `data/raw/worldfootballR_cups`. The archived cup files currently extend only to 2022, so workload coverage is incomplete for later seasons. The analysis still does not include international breaks, squad rotation, player minutes, travel distance, or league match-level xG.
The primary analysis is therefore restricted to seasons ending 2018-2022, corresponding to 2017/18 through 2021/22.

The manuscript also reports a COVID sensitivity analysis excluding 2019/20 matches from March 1, 2020 onward.
