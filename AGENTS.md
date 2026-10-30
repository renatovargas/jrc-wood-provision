
## Rules

- **Processing script:** The whole purpose of this website is to have one single `/documentation/methods/wood-provision/index.qmd` document that describes, with text and human-readable code chunks, the steps to update the wood provision ecosystem services for JRC.
- **Language:** all calculation is in R. Never create auxiliary Python tools. If an API requires Python, use an R wrapper.
- **Paths in R code:** `execute-dir: project`, so paths are relative to the project root wherever the `.qmd` lives. Never use `here::here()`.
- **Links and images in text:** resolved relative to the `.qmd`.
- **Tables:** with `flextable`, never `gt()`; Word output is a priority.
- **Data:** `data/` (inputs and `data/inputs/`) and `data/outputs/` (exported results in suitable folders such as Excel, GIS).
- **Calculation notes:** short, readable steps. Helper functions in `/scripts/*.R`. Each note exports its dataset (rds and xlsx) to `data/outputs/`; those datasets are the source of truth for the documents.
- **Context sources:** the content of terms of reference may be used, but never cited, and payments or other confidential contract information are never mentioned.
- **Rendering:** `docs/` is generated output. Do not render the project unless asked.
- **File size (GitHub):** never add large files to the repository. `data/` only contains compact data files (`.rds`, `.csv`, `.xlsx`, `.xls`, `.ods`, `.parquet`, `.duckdb`, plus compact GIS products such as small `.tif` and `.gpkg`) under 50 MB each. Never version official PDFs, zips or bulk downloads.
- **Downloads:** everything a subagent downloads from the internet (PDFs, laws, reports, heavy datasets) goes to `refs/` (already in `.gitignore`; PDFs that were in `data/` were moved to `refs/descargas/` with the same relative path). Agent research, notes and anything that must stay stably available for future changes is summarised in `.md` files in `research/` (notes with source, page and verification level), never copying the PDF. If a note needs a datum from a PDF, extract it to a small `.rds` in `data/<appropriate-name>/`.
- **Encoding (UTF-8):** all text files are UTF-8. To edit `.qmd`, `.R`, `.md` and `.bib` files with accents or ñ, always use the `edit` (or `write`) tool, which preserves encoding. If `perl` or `sed` is needed in the shell, use `perl -CSDA -Mutf8 -0pi -e ...`, which reads and writes UTF-8; without `-CSDA`, text inserted from a file or decoded variables is written as latin1 and corrupts the line. After any shell edit, verify with `iconv -f UTF-8 -t UTF-8 file >/dev/null && echo ok`. To repair an already damaged file (stray latin1 lines): `perl -MEncode -e 'binmode(STDOUT,":utf8"); while(<>){ my $d=eval{decode("UTF-8",$_,Encode::FB_CROAK)}; print defined $d ? $d : decode("latin1",$_) }' file > tmp && cp tmp file`. In R, read and write with `encoding = "UTF-8"` (`readLines`, `source`, `writeLines`).

## Prose style (applies to Spanish text)

- Never use long dashes (em dashes) or sentences that need them.
- Prefer declarative sentences; use semicolons, commas or colons for subordinate clauses.
- Never use the "It is not X, it is Y" construction or its derivatives.
- No Oxford comma: in Spanish, the "y" (also "o" and "ni") that closes a list is not preceded by a comma or semicolon ("capacitar a analistas, certificar competencias y publicar un reporte", not "..., certificar competencias, y publicar un reporte"). Applies to new text and future edits.
- Avoid unnecessary colons that introduce an enumeration after an already complete sentence (for example, "La propuesta es priorizar tres acciones: capacitar a ..., certificar ... y publicar ..."). Rewrite with a full, fluent sentence that integrates the list through a linking phrase ("La propuesta es priorizar tres acciones, a través de las cuales se busca capacitar a ..., certificar ... y publicar ..."). Colons are reserved for definitions, verbatim quotes and formal lists; in prose, prefer the run-on sentence. Applies to new text and future edits; existing documents are not rewritten unless asked.
