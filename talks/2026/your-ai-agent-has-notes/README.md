# Your AI Agent Has Notes

Slide deck for Michael Carroll's talk at **LLMday NYC 2026**.

- **Live:** https://michael.carroll.io/talks/2026/your-ai-agent-has-notes/
- **Self-contained:** all CSS/JS/QR are vendored here — no runtime dependencies.

## Present

Open `index.html` (or the live URL). **Click** / `→` / `Space` go forward
(revealing fragments, then advancing); `←` goes back. Press `?` for all keys,
`N`/`S` for speaker notes, `R` for the reading/transcript view.

## Build (from the repo's `tools/` folder)

```bash
cd ../../../tools && npm install        # first time
npx playwright install chromium         # first time (for PDF)

npm run qr  -- ../talks/2026/your-ai-agent-has-notes   # regenerate QR SVGs
npm run pdf -- ../talks/2026/your-ai-agent-has-notes   # export to PDF
```

## Still to supply

- Real **skill QR URL** — edit `assets/qr/qr.config.json`, rerun `npm run qr`.
- Speaker **visuals** — Slide 5 (agent trace), Slide 8 (live demo), and
  `assets/img/og-cover.png` (1200×630 social card). Placeholders are in place;
  do not fabricate these.

See the repo root `CLAUDE.md` for full deck conventions.
