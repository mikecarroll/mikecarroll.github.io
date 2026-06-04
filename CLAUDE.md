# CLAUDE.md — working in this repo

This is **`mikecarroll.github.io`**, Michael Carroll's personal site, served by
GitHub Pages at **`michael.carroll.io`** (see `CNAME`). It is a plain static
site — no build system for the site itself, no Jekyll config. There are two
kinds of content here: the **personal homepage** and **slide decks** for talks.

---

## 1. Never break the personal homepage

The homepage is hand-rolled and must be treated as off-limits unless the user
explicitly asks to change it:

- `index.html` — the homepage
- `stylesheets/styles.css`, `stylesheets/github-light.css`
- `javascripts/scale.fix.js`
- `params.json` (used for page regeneration — do not delete), `CNAME`, `README.md`

When adding talks or tooling, only add **new** files/folders. Do not edit, move,
or restyle the homepage or its assets. (A single "Talks" link could be added to
the homepage for SEO if the user requests it — otherwise leave it alone.)

---

## 2. Where slide decks live

```
talks/<year>/<slug>/        e.g. talks/2026/your-ai-agent-has-notes/
  index.html                all slides + transcript + SEO/JSON-LD, one file
  assets/
    deck.css                reusable framework: layout, fragments, print
    deck.js                 reusable framework: navigation engine
    theme.css               per-talk palette + motif (loaded after deck.css)
    qr/
      qr.config.json        { name, url } list → SVGs
      *.svg                 generated, committed (deck stays runtime-dep-free)
    img/                    speaker-supplied visuals + og-cover.png
  README.md                 per-deck preview/export notes
```

Each deck is **self-contained**: it vendors its own CSS/JS/QR and has **zero
external runtime dependencies**. `deck.css` + `deck.js` are the shared framework
(identical across decks); `theme.css` is where each talk diverges.

The public URL of a deck is
`https://michael.carroll.io/talks/<year>/<slug>/`.

---

## 3. Deck conventions (how to build a presentation here)

**Markup drives everything — no per-slide JavaScript.**

- Each slide is `<section class="slide" id="slide-N" aria-label="…">` inside
  `.deck > .stage`. The stage is a fixed **1280×720** canvas that `deck.js`
  scales to fit any viewport (no media-query churn).
- **Dark slides:** add `class="slide--dark"` (use for title + close; light
  content in between — the "sandwich").
- **Incremental reveals:** add `class="fragment"` (+ optional
  `data-fragment-index="N"`) to anything that should appear on a later click.
- **Speaker notes / the spoken "Beat":** put an `<aside class="notes">` in each
  slide. It is hidden on stage, shown via the notes overlay, **and stays in the
  DOM for SEO/AEO**.
- **Do not advance on a click:** `deck.js` already ignores clicks on `a`,
  `button`, and `[data-no-advance]`. Mark interactive/visual elements
  accordingly so links and demos work.

**Navigation (built into `deck.js`):**

| Action | Keys |
| --- | --- |
| Forward (reveal, then next slide) | **click**, `→`, `Space`, `PageDown` |
| Back | `←`, `↑`, `PageUp` |
| First / last | `Home` / `End` |
| Speaker notes | `N` or `S` |
| Reading mode (transcript) | `R` |
| Keyboard help | `?` |

`#slide-N` deep-links a slide. `?print=1` lays all slides out for PDF;
`?read=1` opens the transcript view.

**Design rules (from the talk brief, apply to all decks):**

- **Minimal on-slide text** — the substance lives in speaker notes + transcript.
- **No fancy transitions** unless the user asks (only a subtle fragment fade).
- Pick a **content-informed palette** in `theme.css` (not default blue); commit
  to one accent and repeat it. Use shadcn zinc neutrals as the base.
- **Placeholder visuals only** for assets the speaker will supply — use
  `<figure class="visual" data-no-advance>` with a `[VISUAL: …]` description.
  **Never fabricate** real traces, screenshots, or data.
- **QR codes** are generated as local SVGs (no runtime QR library).

**SEO / AEO (every deck):**

- `<title>`, `description`, `canonical`, `robots`, `theme-color`.
- Open Graph + Twitter card (`og:image` → `assets/img/og-cover.png`, 1200×630).
- JSON-LD `@graph`: `PresentationDigitalDocument` + `Person` (Michael, with
  `sameAs`) + `Event` (if applicable) + `BreadcrumbList`.
- A visible-on-`?read=1`, always-in-DOM `<article class="transcript">` carrying
  the full narrative as prose — this is what answer engines actually read.

---

## 4. Tooling (`tools/`, build-only)

`tools/` holds Node scripts used at build time only. Nothing here ships with a
deck. Install once:

```bash
cd tools
npm install            # installs playwright + qrcode; then:
npx playwright install chromium   # one-time browser download for PDF export
```

Commands (run from `tools/`; the path arg is relative to `tools/`):

```bash
# Generate QR SVGs from a deck's assets/qr/qr.config.json
npm run qr  -- ../talks/2026/your-ai-agent-has-notes

# Export a deck to PDF (headless Chromium, file://, no server)
npm run pdf -- ../talks/2026/your-ai-agent-has-notes

# Scaffold a new deck (copies framework + template, fills tokens)
npm run new-deck -- my-slug 2026 --title "My Talk Title"
```

`tools/deck-template/` is the scaffold skeleton; `new-deck.mjs` also copies the
canonical `deck.css`/`deck.js` from `talks/2026/your-ai-agent-has-notes/` so all
decks share one engine. If you change the framework, the canonical deck is the
source of truth — re-copy into other decks (or re-scaffold).

---

## 5. Preview locally

```bash
# from the repo root
python3 -m http.server 8000
# open http://localhost:8000/talks/2026/your-ai-agent-has-notes/
```

**Always terminate the server when done** (Ctrl-C / kill the process). PDF
export does **not** need a server — it loads the deck over `file://`.

---

## 6. Open items for the AI-agent talk

- **`og-cover.png`** (1200×630 social share image) is not yet supplied — drop it
  into `assets/img/` so Open Graph / Twitter cards render.
- QR targets are final: talk page, Substack, Coolhand (UTM-tagged), and the
  skill repo (`github.com/Coolhand-Labs/feedback-collection-skill`). Edit
  `assets/qr/qr.config.json` + rerun `npm run qr` if any change.

## 7. GitHub Pages

This site serves files **verbatim** — a root `.nojekyll` disables Jekyll so the
deck (and the `{{TOKEN}}` placeholders in `tools/deck-template/`) ship as-is.
The deck uses **relative** asset paths, so it works at its public URL with no
build step. Merging to `master` publishes it at
`https://michael.carroll.io/talks/2026/your-ai-agent-has-notes/` (CNAME already
set). Do not remove `.nojekyll`.
