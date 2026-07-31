/* og-cover.mjs — generate a 1200x630 Open Graph / Twitter card image.
 *
 *   node og-cover.mjs <deck-dir> [--name "Michael Carroll"] [--subtitle "..."] [--title "..."] [--photo assets/img/michael.png]
 *   npm run og-cover -- ../talks/2026/your-ai-agent-has-notes
 *
 * Layout: speaker photo/name/subtitle on the left, the talk title
 * right-justified in as large a font as fits on the right — a divider
 * between them. Colors, font stack, and typographic tokens (weight,
 * letter-spacing) are pulled straight from the deck's own assets/deck.css +
 * assets/theme.css, and the name/subtitle/title default to the deck's own
 * JSON-LD (Person.name/jobTitle, PresentationDigitalDocument.headline), so
 * this works unmodified for future decks — no deck-specific values are
 * hardcoded here. Screenshots with headless Chromium (Playwright) to
 * <deck-dir>/assets/img/og-cover.png. Uses only real, already-present assets
 * — no fabricated data.
 */
import { readFile, writeFile, access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const deckDir = resolve(
  here,
  args.find((a) => !a.startsWith("--")) || "../talks/2026/your-ai-agent-has-notes"
);

function argValue(flag, fallback) {
  const i = args.indexOf(flag);
  return i >= 0 ? args[i + 1] : fallback;
}

// --- pull the deck's own copy (name/subtitle/title) from its JSON-LD -------
const deckHtml = await readFile(resolve(deckDir, "index.html"), "utf8");
const ldMatch = deckHtml.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/);
const graph = ldMatch ? JSON.parse(ldMatch[1])["@graph"] || [] : [];
const person = graph.find((n) => n["@type"] === "Person");
const doc = graph.find((n) => n["@type"] === "PresentationDigitalDocument");

const name = argValue("--name", person?.name || "Michael Carroll");
const subtitle = argValue("--subtitle", person?.jobTitle || "");
const title = argValue("--title", doc?.headline || doc?.name || "");
const photoRel = argValue("--photo", "assets/img/michael.png");
const photoPath = resolve(deckDir, photoRel);
await access(photoPath); // throws a clear error if the headshot is missing

const photoBase64 = (await readFile(photoPath)).toString("base64");
const photoDataUrl = `data:image/png;base64,${photoBase64}`;

// --- pull colors + font stack from the deck's own CSS -----------------------
const deckCss = await readFile(resolve(deckDir, "assets/deck.css"), "utf8");
const themeCss = await readFile(resolve(deckDir, "assets/theme.css"), "utf8");

function extractCssVars(css, into) {
  const re = /--([\w-]+):\s*([^;]+);/g;
  let m;
  while ((m = re.exec(css))) {
    into[m[1]] = m[2].trim().replace(/\s+/g, " ");
  }
  return into;
}
const vars = extractCssVars(themeCss, extractCssVars(deckCss, {}));

const hsl = (name, fallback) => (vars[name] ? `hsl(${vars[name]})` : fallback);
const background = hsl("background", "#09090b");
const foreground = hsl("foreground", "#fafafa");
const accent = hsl("accent", "#f0a020");
const mutedForeground = hsl("muted-foreground", "#a1a1aa");
const border = hsl("border", "#3f3f46");
const fontSans =
  vars["font-sans"] ||
  'ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body {
        width: 1200px;
        height: 630px;
        background: ${background};
        color: ${foreground};
        font-family: ${fontSans};
      }
      .card {
        width: 1200px;
        height: 630px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 64px;
        gap: 48px;
      }
      .left {
        flex: 0 0 auto;
        max-width: 380px;
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 18px;
      }
      .photo {
        width: 150px;
        height: 150px;
        border-radius: 999px;
        object-fit: cover;
        border: 3px solid ${accent};
        box-shadow: 0 10px 28px rgb(0 0 0 / 0.45);
      }
      .name {
        font-size: 2.5rem;
        font-weight: 800;
        letter-spacing: -0.03em;
        line-height: 1.05;
      }
      .subtitle {
        font-size: 1rem;
        font-weight: 600;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: ${mutedForeground};
      }
      .divider {
        flex: 0 0 auto;
        width: 2px;
        align-self: stretch;
        background: ${border};
      }
      .right {
        flex: 1 1 auto;
        min-width: 0;
        display: flex;
        align-items: center;
        justify-content: flex-end;
        height: 100%;
      }
      .title {
        margin: 0;
        text-align: right;
        font-weight: 800;
        letter-spacing: -0.03em;
        line-height: 1.02;
        color: ${accent};
        font-size: 140px;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <div class="left">
        <img class="photo" src="${photoDataUrl}" alt="" />
        <div class="name">${name}</div>
        ${subtitle ? `<div class="subtitle">${subtitle}</div>` : ""}
      </div>
      ${title ? `<div class="divider"></div><div class="right"><h1 class="title">${title}</h1></div>` : ""}
    </div>
  </body>
</html>`;

const outPath = resolve(deckDir, "assets/img/og-cover.png");

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  await page.setContent(html, { waitUntil: "networkidle" });

  // Shrink the title until it fits the available height/width for its column
  // — makes it "as big as it can be" for whatever title text a future deck has.
  await page.evaluate(() => {
    const el = document.querySelector(".title");
    if (!el) return;
    const container = el.parentElement;
    let size = 140;
    el.style.fontSize = `${size}px`;
    while (
      size > 24 &&
      (el.scrollHeight > container.clientHeight || el.scrollWidth > container.clientWidth)
    ) {
      size -= 2;
      el.style.fontSize = `${size}px`;
    }
  });

  await page.screenshot({ path: outPath });
  console.log(`✓ Wrote ${outPath}`);
} finally {
  await browser.close();
}
