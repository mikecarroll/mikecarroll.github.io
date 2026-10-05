# Elastic Software: Calculating tech debt using LLM tokens

Slide deck for Michael Carroll's talk at **XO Ruby Toronto 2026** (2026-10-03).

- **Live:** https://michael.carroll.io/talks/2026/elastic-software/
- **Self-contained:** all CSS/JS/QR are vendored here — no runtime dependencies.

## Present

Open `index.html` (or the live URL). **Click** / `→` / `Space` go forward
(revealing fragments, then advancing); `←` goes back. Press `?` for all keys,
`N`/`S` for speaker notes, `R` for the reading/transcript view.

## Build (from the repo's `tools/` folder)

```bash
cd ../../../tools && npm install        # first time
npx playwright install chromium         # first time (for PDF / og-cover)

npm run qr  -- ../talks/2026/elastic-software   # regenerate QR SVGs
npm run pdf -- ../talks/2026/elastic-software   # export to PDF
```

## Still to supply

- **Real cost figures** — Slides 12–14 show `$ TBD` / `$X` / `$Y` / `$Z`.
  Use real (or clearly labelled reconstructed) numbers; do not invent precision.
- **Live demo** — Slide 29 is a `[VISUAL: …]` placeholder. Confirm the demo runs on
  conference wifi, or record it and play the recording.

`assets/img/og-cover.png` is generated from the real headshot via
`npm run og-cover -- ../talks/2026/elastic-software` — rerun it if the
headshot or title copy changes.

See the repo root `CLAUDE.md` for full deck conventions.
