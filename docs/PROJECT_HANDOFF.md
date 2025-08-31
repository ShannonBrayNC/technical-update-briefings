# Project Handoff / Working Notes

## Repo
technical-update-briefings

## Goal
Generate a polished monthly M365 Technical Update deck (PowerPoint) by parsing:

- Roadmap export HTML (`tools/roadmap/RoadmapPrimarySource.html`)
- Message Center export HTML (`tools/message_center/MessageCenterBriefingSuppliments.html`)

The pipeline is PowerShell-orchestrated (`run.ps1`) and Python-implemented (`generate_deck.py` + parsers).
Configuration lives in `deck.config.json`.

## High-Level Flow

### PowerShell Launcher – `tools/ppt_builder/run.ps1`
- Ensures a local Python venv & dependencies (`requirements.txt`)
- Loads `deck.config.json`
- Calls `generate_deck.py` with config values
- Writes `RoadmapDeck_AutoGen.pptx`

### Python Deck Builder – `tools/ppt_builder/generate_deck.py`
- Parses inputs via modular parsers:
  - `tools/ppt_builder/parsers/roadmap_html.py`
  - `tools/ppt_builder/parsers/message_center.py`
- Merges & normalizes items
- Adds cover / separators / items / conclusion slides

### Outputs
- Deck: `tools/ppt_builder/RoadmapDeck_AutoGen.pptx`
- Optional: "self-check" console output (counts of inputs / cards / items)

## Repository Map (minimal)
```
/tools
  /ppt_builder
    generate_deck.py
    deck.config.json
    requirements.txt
    run.ps1
    /assets
      cover.png, agenda.png, separator.png, conclusion.png, thankyou.png,
      brand_bg.png, parex-logo.png, customer-logo.png, rocket.png, magnifier.png
    /parsers
      __init__.py
      message_center.py
      roadmap_html.py
  /roadmap
    RoadmapPrimarySource.html
  /message_center
    MessageCenterBriefingSuppliments.html
/tests
  Style.Tests.ps1
/docs
  WorkingAgreement.md
  /ADR
    0001..0011 (existing) + see ADRs added below (0012..0020)
```

## Run Commands (clean & reliable)

### One-shot build (from repo root)
```powershell
# Create deck with current config
.\tools\ppt_builder\run.ps1 -Config .\tools\ppt_builder\deck.config.json -Verbose
```

### Quick sanity after changes
```powershell
# PowerShell style checks
.\tools\ci\check-sanity.ps1

# Python lint/format (from repo root):
.\tools\ppt_builder\.venv\Scripts\python -m ruff format .\tools\ppt_builder\generate_deck.py
.\tools\ppt_builder\.venv\Scripts\python -m ruff check --fix .\tools\ppt_builder\generate_deck.py
```

## `deck.config.json` (canonical keys)
```json
{
  "Inputs": [
    "C:\\technical_update_briefings\\tools\\roadmap\\RoadmapPrimarySource.html",
    "C:\\technical_update_briefings\\tools\\message_center\\MessageCenterBriefingSuppliments.html"
  ],
  "Output": "C:\\technical_update_briefings\\tools\\ppt_builder\\RoadmapDeck_AutoGen.pptx",
  "Month": "September 2025",
  "CoverTitle": "M365 Technical Update Briefing",
  "CoverDates": "September 2025",
  "SeparatorTitle": "Technical Update Briefing — September 2025",
  "Template": "",
  "RailWidth": 3.5,

  "Cover": ".\\assets\\cover.png",
  "AgendaBg": ".\\assets\\agenda.png",
  "Separator": ".\\assets\\separator.png",
  "ConclusionBg": ".\\assets\\conclusion.png",
  "ThankYou": ".\\assets\\thankyou.png",
  "BrandBg": ".\\assets\\brand_bg.png",
  "Logo": ".\\assets\\parex-logo.png",
  "Logo2": ".\\assets\\customer-logo.png",
  "Rocket": ".\\assets\\rocket.png",
  "Magnifier": ".\\assets\\magnifier.png"
}
```

## Notes
- For Windows, absolute paths always work. Relative paths can work but must be resolved from the PowerShell current directory. When unsure, use absolute paths.
- `RailWidth` is in inches for layout math.

## New ADRs
See `docs/ADR/0012`–`0020` for recent decisions.

### 0012-slide-rail-geometry.md
- **Decision**: Slide geometry parameters are inches-first. We wrap all EMU conversions inside helpers, never mix EMU constants directly in slide code.
- **Why**: Eliminates off-by-factor bugs; makes layout predictable and parsable by humans.
- **Implication**: All UI placement helpers accept/return inches. Only shape API calls convert to EMUs as needed.

### 0013-parsers-as-modules.md
- **Decision**: Parsers live in dedicated modules: `parsers/roadmap_html.py`, `parsers/message_center.py`.
- **Why**: Reduce churn in `generate_deck.py`, isolate BeautifulSoup logic, simplify unit tests & cross-module reuse.
- **Implication**: `generate_deck.build()` imports and calls `parse_roadmap_html()` and `parse_message_center_html()`.

### 0014-beautifulsoup-tag-typing.md
- **Decision**: Use `from bs4.element import Tag, NavigableString`; do not import `BsTag` (private).
- **Why**: Pylance/Pyright false positives and private APIs led to friction. Tag/NavigableString are stable.
- **Implication**: All helpers accept `Tag | NavigableString | None` where appropriate.

### 0015-inches-wrapper-for-layout.md
- **Decision**: Provide `_inches(x: float | None) -> float` wrapper and `emu_to_in()` util.
- **Why**: A single place to coerce/guard numbers; avoids `None` and union-type surprises in geometry math.
- **Implication**: Slide functions never accept `None` for width/height; defaults handled before calls.

### 0016-config-driven-run-ps1.md
- **Decision**: `run.ps1` reads a JSON config for all inputs/paths rather than many flags.
- **Why**: Simpler CLI, consistent automation, versionable config.
- **Implication**: New parameters are added to JSON first; `run.ps1` keeps deserializing into a single object.

### 0017-powershell-here-strings-and-colon-safety.md
- **Decision**: No here-strings in automation scripts; write files line-by-line. Avoid `:$` after variables (`$var:...`) which can parse oddly.
- **Why**: Here-strings and colon-after-variable cause brittle parsing and quoting bugs.
- **Implication**: Use `[IO.File]::WriteAllLines()` and explicit arrays.

### 0018-powershell-host-reserved.md
- **Decision**: Do not use `$host` for storage or logic; it is reserved and can crash scripts.
- **Why**: `$host` is a special shell object.
- **Implication**: If needed, use `$pshost` or a differently named variable.

### 0019-eslint-flat-config.md
- **Decision**: ESLint 9+ requires flat config; migrate from `.eslintrc.*` to `eslint.config.js`.
- **Why**: Lint now errors without flat config.
- **Implication**: `npm run lint` expects `eslint.config.js`; update workspace globs and ignores there.

### 0020-ruff-config-and-usage.md
- **Decision**: Adopt `.ruff.toml` with supported keys only; run format+fix via venv Python.
- **Why**: We hit an invalid `fix = true` key; keep config compliant.
- **Implication**: Use:
  ```powershell
  .\tools\ppt_builder\.venv\Scripts\python -m ruff format tools\ppt_builder\generate_deck.py
  .\tools\ppt_builder\.venv\Scripts\python -m ruff check --fix tools\ppt_builder\generate_deck.py
  ```

## Python Helper Patterns We Standardized
- **Type-safe text helpers:**
  - `_to_text(x) -> str`: `Tag | NavigableString | str | iterables → clean string`
  - `_clean(s) -> str`: normalize whitespace (`" ".join(s.split())`)
- **Tag accessors (safe, typed):**
  - `safe_find(node, name, **kw) -> Tag | None`
  - `safe_find_all(node, name, **kw) -> list[Tag]`
  - `_classes(tag) -> list[str]`
- **URL/ID extraction:** never index BeautifulSoup attributes like `a["href"]`; use `a.get("href")` then normalize lists/tuples.

## Common Failure Points & Quick Diagnostics

### No items in deck
Run a quick soup count in REPL (PowerShell, inside venv):
```powershell
.\tools\ppt_builder\.venv\Scripts\python - <<'PY'
from bs4 import BeautifulSoup
p = r"C:\technical_update_briefings\tools\message_center\MessageCenterBriefingSuppliments.html"
html = open(p, "r", encoding="utf-8", errors="ignore").read()
s = BeautifulSoup(html, "lxml")
cards = s.find_all(attrs={"class": lambda c: c and ("card" in c or "ms-" in c)})
print("cards:", len(cards))
PY
```
If `cards == 0`, fallback to tables in `parsers/message_center.py` is used. Check that parser returns at least some items.

### Paths not found
If relative paths fail, switch to absolute in `deck.config.json`.

### Type nags (Pylance)
Ensure imports:
```python
from bs4.element import Tag, NavigableString
```
Avoid `BsTag`. Avoid `PageElement` in annotations.

### PowerShell `$host` or colon parsing
Rename variables; don’t do `$var:Suffix` or use `$host`.

### Minimal `.ruff.toml` that won’t explode
Place at repo root:
```toml
line-length = 120
target-version = "py312"

[lint]
select = [
  "E", "F", "W",
  "B",
  "UP",
  "I"
]
ignore = [
  # add rule codes to ignore if needed
]

[format]
quote-style = "double"
indent-style = "space"
line-ending = "auto"
docstring-code-format = true
```
Note: Don’t include `fix = true` in root. Use CLI `--fix`.

## Git Patching (quick refresher)
```bash
git add -A
git diff --cached > my-change.patch

git apply --check my-change.patch

git apply my-change.patch
```
If you receive “No valid patches in input”, the file likely doesn’t start with a valid `diff --git` header.

## Next Actions We Recommend
- Drop this file into the repo as `PROJECT_HANDOFF.md`.
- Add ADRs 0012–0020 using the template.
- Confirm `deck.config.json` uses absolute input paths for now.
- Re-run: `.\tools\ppt_builder\run.ps1 -Config .\tools\ppt_builder\deck.config.json -Verbose`.
- If deck has zero items, run the soup count REPL above. If cards > 0 but items still zero, the parser module is likely the culprit—ping me for a focused patch.
