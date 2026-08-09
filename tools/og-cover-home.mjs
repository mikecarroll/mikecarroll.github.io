/* og-cover-home.mjs — regenerate the homepage's social card by screenshotting index.html.
 *
 *   node og-cover-home.mjs
 *   npm run og-cover-home
 *
 * Unlike og-cover.mjs (which draws each deck's card from its theme/JSON-LD),
 * the homepage card is a straight 1200x630 viewport screenshot of the live
 * page over file:// — the "carrollslist" look is the pitch, so showing it
 * directly is more honest than redrawing it. Never hand-edit og-cover.png;
 * always regenerate it with this script.
 */
import { chromium } from "playwright";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const indexPath = resolve(repoRoot, "index.html");
const outPath = resolve(repoRoot, "og-cover.png");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.goto(`file://${indexPath}`);
// let the recent-writing fetch resolve (or fail and hide itself) before capturing
await page.waitForTimeout(2000);
await page.screenshot({ path: outPath });
await browser.close();

console.log(`✓ wrote ${outPath}`);
