/* sitemap.mjs — regenerate the root sitemap.xml by discovering pages.
 *
 *   node sitemap.mjs
 *   npm run sitemap
 *
 * Walks talks/<year>/<slug>/index.html plus the homepage and the talks/
 * listing page, cross-checks each page's <link rel="canonical"> against the
 * URL the path implies, pulls lastmod from git history, and writes
 * sitemap.xml at the repo root. Never hand-edit sitemap.xml — always
 * regenerate it with this script.
 */
import { readFile, readdir, stat, writeFile } from "node:fs/promises";
import { execFileSync } from "node:child_process";
import { dirname, resolve, relative } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const SITE = "https://michael.carroll.io";

function gitLastmod(absPath) {
  const rel = relative(repoRoot, absPath);
  try {
    const out = execFileSync(
      "git",
      ["log", "-1", "--format=%cs", "--", rel],
      { cwd: repoRoot, encoding: "utf8" }
    ).trim();
    return out || undefined;
  } catch {
    return undefined;
  }
}

async function findDecks() {
  const talksDir = resolve(repoRoot, "talks");
  const decks = [];
  for (const year of await readdir(talksDir)) {
    const yearDir = resolve(talksDir, year);
    if (!(await stat(yearDir)).isDirectory()) continue;
    for (const slug of await readdir(yearDir)) {
      const deckDir = resolve(yearDir, slug);
      const indexPath = resolve(deckDir, "index.html");
      if (!(await stat(deckDir)).isDirectory()) continue;
      try {
        await stat(indexPath);
      } catch {
        continue;
      }
      decks.push({ year, slug, indexPath });
    }
  }
  return decks;
}

async function checkCanonical(indexPath, expectedUrl) {
  const html = await readFile(indexPath, "utf8");
  const match = html.match(/rel="canonical"\s+href="([^"]+)"/);
  if (!match) {
    console.warn(`  ! no canonical tag found in ${relative(repoRoot, indexPath)}`);
    return;
  }
  if (match[1] !== expectedUrl) {
    console.warn(
      `  ! canonical mismatch in ${relative(repoRoot, indexPath)}: found "${match[1]}", expected "${expectedUrl}"`
    );
  }
}

const pages = [];

const homepagePath = resolve(repoRoot, "index.html");
pages.push({
  url: `${SITE}/`,
  lastmod: gitLastmod(homepagePath),
});

const talksIndexPath = resolve(repoRoot, "talks/index.html");
await checkCanonical(talksIndexPath, `${SITE}/talks/`);
pages.push({
  url: `${SITE}/talks/`,
  lastmod: gitLastmod(talksIndexPath),
});

const decks = await findDecks();
decks.sort((a, b) => a.year.localeCompare(b.year) || a.slug.localeCompare(b.slug));

for (const deck of decks) {
  const url = `${SITE}/talks/${deck.year}/${deck.slug}/`;
  await checkCanonical(deck.indexPath, url);
  pages.push({ url, lastmod: gitLastmod(deck.indexPath) });
}

const urlEntries = pages
  .map(
    (p) =>
      `  <url>\n    <loc>${p.url}</loc>\n${p.lastmod ? `    <lastmod>${p.lastmod}</lastmod>\n` : ""}  </url>`
  )
  .join("\n");

const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urlEntries}\n</urlset>\n`;

const openTags = (xml.match(/<url>/g) || []).length;
const closeTags = (xml.match(/<\/url>/g) || []).length;
if (openTags !== closeTags || openTags !== pages.length) {
  throw new Error(
    `Malformed sitemap: ${openTags} <url> open tags, ${closeTags} close tags, ${pages.length} pages`
  );
}

const outPath = resolve(repoRoot, "sitemap.xml");
await writeFile(outPath, xml, "utf8");

for (const p of pages) {
  console.log(`✓ ${p.url}${p.lastmod ? ` (lastmod ${p.lastmod})` : ""}`);
}
console.log(`\nDone. ${pages.length} page(s) written to ${relative(repoRoot, outPath)}`);
