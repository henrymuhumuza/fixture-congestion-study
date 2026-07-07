# Reproducibility Notes

## Software

- R 4.4.2
- Quarto CLI
- Required R packages: `tidyverse`, `lme4`, `mgcv`, `knitr`, `rmarkdown`

The local R executable used in this project is:

```powershell
C:\Program Files\R\R-4.4.2\bin\Rscript.exe
```

## Data Inputs

Raw match-result CSV files are stored in:

```text
data/raw/football_data_uk
```

The analysis uses Big Five league seasons from 2017/18 to 2021/22 and provides the league outcome data.

Supplemental worldfootballR cup-result RDS files are stored in:

```text
data/raw/worldfootballR_cups
```

These files add UEFA and domestic cup fixtures to the workload schedule where available.

## Analysis Pipeline

1. Read Football-Data.co.uk CSV files for seasons ending 2018-2022.
2. Convert each match into two team-match observations.
3. Read worldfootballR UEFA and domestic cup RDS files dated July 1, 2017 through June 30, 2022.
4. Harmonize FBref/worldfootballR team names to Football-Data team names using deterministic aliases.
5. Convert league and cup matches into a combined team-match schedule.
6. Compute rest days and workload variables within team-season using all included competitions.
7. Keep domestic league matches as the outcome rows.
8. Create rolling league-form variables.
9. Fit mixed-effects models with team and opponent random intercepts.
10. Export analysis datasets, tables, figures, and model objects.

Run:

```powershell
& 'C:\Program Files\R\R-4.4.2\bin\Rscript.exe' scripts\01_fixture_congestion_analysis.R
```

Then render:

```powershell
quarto render manuscript\manuscript.qmd
```
