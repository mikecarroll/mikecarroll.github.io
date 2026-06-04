/* export-pdf.mjs — render a deck to PDF with headless Chromium (Playwright).
 *
 *   node export-pdf.mjs <deck-dir> [out.pdf]
 *   npm run pdf -- ../talks/2026/your-ai-agent-has-notes
 *
 * Loads <deck-dir>/index.html?print=1 over file:// (no server needed), which
 * reveals every fragment and lays each slide out as its own 1280x720 landscape
 * page, then prints to PDF. Defaults to the AI-agent talk if no dir is given.
 */
import { access } from "node:fs/promises";
import { dirname, resolve, basename } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const deckDir = resolve(
  here,
  process.argv[2] || "../talks/2026/your-ai-agent-has-notes"
);
const indexPath = resolve(deckDir, "index.html");
await access(indexPath); // throws a clear error if the deck is missing

const outPath = resolve(
  process.argv[3] ? resolve(process.cwd(), process.argv[3]) : deckDir,
  process.argv[3] ? "" : `${basename(deckDir)}.pdf`
);

const url = pathToFileURL(indexPath).href + "?print=1";
console.log(`Rendering ${url}`);

const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: "networkidle" });
  // give the print stylesheet + QR SVGs a beat to settle
  await page.waitForTimeout(300);
  await page.pdf({
    path: outPath,
    width: "1280px",
    height: "720px",
    printBackground: true,
    pageRanges: "", // all pages
  });
  console.log(`✓ Wrote ${outPath}`);
} finally {
  await browser.close();
}
