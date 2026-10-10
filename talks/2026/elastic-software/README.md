# Elastic Software: Calculating tech debt using LLM tokens

Slide deck for Michael Carroll's talk at **XO Ruby NYC 2026** (2026-10-03).

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

- **Transcript cleanup** — the `?read=1` transcript still narrates several beats
  that have been cut from the slides: the "AI path: $X per month / Software
  path: $Y to build, $Z per month" cost comparison, the pure-AI-parser →
  "bill arrives" → hybrid-contract arc (formerly slides 18–23, replaced by the
  squishling introduction), the closing "what nobody has solved / what
  separates the teams doing it well" open-problems reflection, and the live
  demo / data-types / v1-vs-v2 arc (formerly slides 27–31, cut along with the
  per-client-cost "instrumentation" setup it depended on). Rewrite the
  transcript to match before presenting.

`assets/img/og-cover.png` is generated from the real headshot via
`npm run og-cover -- ../talks/2026/elastic-software` — rerun it if the
headshot or title copy changes.

See the repo root `CLAUDE.md` for full deck conventions.
