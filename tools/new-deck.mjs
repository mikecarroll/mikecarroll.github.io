/* new-deck.mjs — scaffold a new self-contained slide deck under talks/<year>/.
 *
 *   node new-deck.mjs <slug> [year] [--title "Talk Title"]
 *   npm run new-deck -- my-talk 2026 --title "My Great Talk"
 *
 * Creates talks/<year>/<slug>/ by:
 *   • copying the reusable framework (deck.css, deck.js) from the canonical
 *     deck so every deck shares one engine but stays self-contained, and
 *   • copying tools/deck-template/ (skeleton index.html, theme.css, qr config),
 *     substituting {{TITLE}}, {{SLUG}}, {{YEAR}}, {{DESCRIPTION}} tokens.
 */
import { cp, mkdir, readFile, writeFile, readdir, stat } from "node:fs/promises";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");

// --- args ---
const args = process.argv.slice(2);
const slug = args.find((a) => !a.startsWith("--"));
const year = args.filter((a) => !a.startsWith("--"))[1] || "2026";
const titleIdx = args.indexOf("--title");
const title =
  titleIdx >= 0 ? args[titleIdx + 1] : slug ? toTitle(slug) : undefined;

if (!slug) {
  console.error('Usage: node new-deck.mjs <slug> [year] [--title "Talk Title"]');
  process.exit(1);
}

function toTitle(s) {
  return s.replace(/-/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

const FRAMEWORK_DECK = resolve(repoRoot, "talks/2026/your-ai-agent-has-notes");
const TEMPLATE = resolve(here, "deck-template");
const dest = resolve(repoRoot, "talks", year, slug);

const tokens = {
  "{{TITLE}}": title,
  "{{SLUG}}": slug,
  "{{YEAR}}": year,
  "{{DESCRIPTION}}": `${title} — a talk by Michael Carroll.`,
};

function fill(text) {
  return Object.entries(tokens).reduce(
    (acc, [k, v]) => acc.split(k).join(v),
    text
  );
}

// copy a tree, applying token substitution to text files
async function copyTree(src, dst) {
  await mkdir(dst, { recursive: true });
  for (const entry of await readdir(src)) {
    const s = join(src, entry);
    const d = join(dst, entry);
    if ((await stat(s)).isDirectory()) {
      await copyTree(s, d);
    } else if (/\.(html|css|json|js|md|txt|svg)$/.test(entry)) {
      await writeFile(d, fill(await readFile(s, "utf8")));
    } else {
      await cp(s, d);
    }
  }
}

await mkdir(dest, { recursive: true });
await copyTree(TEMPLATE, dest);

// pull the shared framework engine from the canonical deck
await mkdir(resolve(dest, "assets"), { recursive: true });
for (const f of ["deck.css", "deck.js"]) {
  await cp(
    resolve(FRAMEWORK_DECK, "assets", f),
    resolve(dest, "assets", f)
  );
}

console.log(`✓ Created talks/${year}/${slug}/`);
console.log(`  Title: ${title}`);
console.log(`  Next:  edit index.html, then:`);
console.log(`         npm run qr  -- ../talks/${year}/${slug}`);
console.log(`         npm run pdf -- ../talks/${year}/${slug}`);
