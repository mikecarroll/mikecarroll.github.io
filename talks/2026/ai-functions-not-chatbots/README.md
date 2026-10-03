# Stop being the boss you hate: build AI functions, not chatbots

Slide deck for Michael Carroll's talk at **XO Ruby Toronto 2026**.

- **Live:** https://michael.carroll.io/talks/2026/ai-functions-not-chatbots/
- **Self-contained:** all CSS/JS/QR are vendored here — no runtime dependencies.
- **Case study:** the code slides are lightly trimmed excerpts of the Coolhand
  help-center pipeline (`HelpCenter::*`, `HelpArticleIdea`).

## Present

Open `index.html` (or the live URL). **Click** / `→` / `Space` go forward
(revealing fragments, then advancing); `←` goes back. Press `?` for all keys,
`N`/`S` for speaker notes, `R` for the reading/transcript view.

## Build (from the repo's `tools/` folder)

```bash
cd ../../../tools && npm install        # first time
npx playwright install chromium         # first time (for PDF)

npm run qr  -- ../talks/2026/ai-functions-not-chatbots   # regenerate QR SVGs
npm run pdf -- ../talks/2026/ai-functions-not-chatbots   # export to PDF
```

## Still to supply

- **Slide 31 (impressions chart)** — the real Search Console screenshots never
  made it into the repo, so this is now a hand-built inline SVG line chart
  instead (no external chart library, stays zero-runtime-dependency): daily
  impressions, Aug 2 – Sep 2, 2026, one line for regular Google search (SEO)
  and one for AI answer engines (AEO), each independently min-max scaled to
  its own range so both trends read clearly — there's deliberately no y-axis
  or value labels, since the point is the shape of the growth, not the raw
  numbers. Source data: Search Console "Performance on Search" and
  "Performance on Search: Generative AI Features" CSV exports.
- The "edits become changes" and "where this goes next" slides were cut; the
  Coolhand Labs slide (previously the deck's closer) now sits in the former's
  spot, right before the final "Thank You" close.
- The old "installed vs. built tools" / "the output object" / "it proposes,
  it never writes" / "Step 3" divider slides were replaced by one new slide
  22: "Same function, smaller more specialized agents." It copies the v1
  pipeline flow chart from slide 13 and, on a beat, crosses out the single
  "AI" box, then reveals four named subagents (Revision, Features, Review,
  Symlink) in a 2×2 grid below with color-coded outlines (no arrows between
  them — tried a few arrow treatments, none read well at a glance, so the
  grid stands alone). Slide 23 ("new page and a revision aren't the same
  job") was moved up to sit right after it, so the two "Step 3" slides are
  adjacent; the "Step 2: Bonus!" wildcard divider and content slide (24-25)
  now follow both.
- The live demo and open-sourcing-captainslog slides were cut from the deck;
  `github.com/Coolhand-Labs/captainslog` is mentioned only by name now (notes
  on the "review gates levers" and "what a review surface needs" slides, and
  in the transcript) — still worth confirming the repo is public before the
  talk, since the transcript links nothing but speaker notes say it by name.
- Confirm the **event date/venue** in the JSON-LD `Event` block (currently
  `2026-10-03`, "Toronto").

`assets/img/og-cover.png` is generated from the real headshot via
`npm run og-cover -- ../talks/2026/ai-functions-not-chatbots` — rerun it if the
headshot or title copy changes.

See the repo root `CLAUDE.md` for full deck conventions.
