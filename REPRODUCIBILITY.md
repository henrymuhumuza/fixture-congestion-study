# Reproducibility Notes: Fixture Congestion Study

This document records how the raw source files, analytic dataset, tables, figures, and manuscript outputs can be regenerated.

## Software

R is installed locally at:

```powershell
C:\Program Files\R\R-4.4.2\bin\Rscript.exe
```

The project uses:

- R 4.4.2
- Quarto CLI
- Required R packages: `tidyverse`, `lme4`, `jsonlite`, `glue`, and `knitr`

If `Rscript` is not on PATH, run scripts using the full executable path shown above.

## Data Sources

### League Match Data

League match results, match statistics, and betting odds come from Football-Data.co.uk:

```text
https://www.football-data.co.uk/data.php
```

Football-Data provides computer-ready CSV match files. The download script uses the public CSV pattern behind the site:

```text
https://www.football-data.co.uk/mmz4281/{season}/{league}.csv
```

The study downloads Big Five league files for seasons ending 2018-2022:

- English Premier League: `E0`
- German Bundesliga: `D1`
- French Ligue 1: `F1`
- Italian Serie A: `I1`
- Spanish La Liga: `SP1`

Downloaded files are stored in:

```text
data/raw/football_data_uk/
```

Example local file:

```text
data/raw/football_data_uk/1718_E0.csv
```

### Cup and European Match Data

Supplemental cup and European match-result files come from the archived `worldfootballR_data` GitHub repository:

```text
https://github.com/JaseZiv/worldfootballR_data
```

The download script reads the GitHub repository tree and downloads the required RDS files from raw GitHub URLs into:

```text
data/raw/worldfootballR_cups/
```

Files used:

- `uefa_champions_league_match_results.rds`
- `uefa_europa_league_match_results.rds`
- `uefa_europa_conference_league_match_results.rds`
- `fa_cup_match_results.rds`
- `english_football_league_cup_match_results.rds`
- `dfb_pokal_match_results.rds`
- `coppa_italia_match_results.rds`
- `copa_del_rey_match_results.rds`
- `coupe_de_france_match_results.rds`

## Folder Structure

```text
fixture-congestion-study/
|-- data/
|   |-- raw/
|   |   |-- football_data_uk/
|   |   `-- worldfootballR_cups/
|   |-- processed/
|   `-- final/
|-- outputs/
|   |-- figures/
|   |-- manuscript/
|   `-- tables/
|-- manuscript/
|   |-- manuscript.qmd
|   |-- reference.docx      # local only, ignored by Git
|   `-- styles.css
|-- scripts/
|   |-- 00_download_raw_data.R
|   |-- 01_fixture_congestion_analysis.R
|   `-- 02_format_docx_tables.ps1
```

Raw data files and generated outputs are ignored by Git.

## Run Order

Download raw data:

```powershell
& 'C:\Program Files\R\R-4.4.2\bin\Rscript.exe' scripts\00_download_raw_data.R
```

Generate analytic datasets, tables, figures, and model objects:

```powershell
& 'C:\Program Files\R\R-4.4.2\bin\Rscript.exe' scripts\01_fixture_congestion_analysis.R
```

Render HTML:

```powershell
quarto render manuscript\manuscript.qmd --to html
```

Render DOCX:

```powershell
quarto render manuscript\manuscript.qmd --to docx
powershell -ExecutionPolicy Bypass -File scripts\02_format_docx_tables.ps1 -DocxPath outputs\manuscript\manuscript.docx -TableFontHalfPoints 16
```

## Script Details

### `00_download_raw_data.R`

Downloads Football-Data.co.uk Big Five league CSV files for seasons ending 2018-2022. It also downloads required UEFA and domestic cup RDS files from `worldfootballR_data` on GitHub. Existing non-empty files are not redownloaded.

### `01_fixture_congestion_analysis.R`

Builds the team-match panel, harmonizes team names, combines league and cup schedules, computes rest and workload variables, fits mixed-effects models, writes analysis datasets, exports tables and figures, and saves model objects.

### `02_format_docx_tables.ps1`

Post-processes the generated Word manuscript so tables are full width, unshaded, and use smaller font size for better fit.
