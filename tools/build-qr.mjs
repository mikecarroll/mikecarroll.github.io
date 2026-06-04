/* build-qr.mjs — generate QR-code SVGs for a deck from its qr.config.json.
 *
 *   node build-qr.mjs <deck-dir>
 *   npm run qr -- ../talks/2026/your-ai-agent-has-notes
 *
 * Reads <deck-dir>/assets/qr/qr.config.json and writes one <name>.svg per
 * entry into the same folder. SVGs are committed so the deck stays
 * dependency-free at runtime. Defaults to the AI-agent talk if no dir given.
 */
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import QRCode from "qrcode";

const here = dirname(fileURLToPath(import.meta.url));
const deckDir = resolve(
  here,
  process.argv[2] || "../talks/2026/your-ai-agent-has-notes"
);
const qrDir = resolve(deckDir, "assets/qr");
const configPath = resolve(qrDir, "qr.config.json");

const config = JSON.parse(await readFile(configPath, "utf8"));
if (!Array.isArray(config.codes)) {
  throw new Error(`No "codes" array in ${configPath}`);
}

for (const code of config.codes) {
  if (!code.name || !code.url) {
    console.warn("Skipping entry without name/url:", code);
    continue;
  }
  const svg = await QRCode.toString(code.url, {
    type: "svg",
    margin: 1,
    errorCorrectionLevel: "M",
    color: { dark: "#09090b", light: "#ffffff" },
  });
  const out = resolve(qrDir, `${code.name}.svg`);
  await writeFile(out, svg, "utf8");
  console.log(
    `✓ ${code.name}.svg → ${code.url}${code.placeholder ? "  (placeholder)" : ""}`
  );
}

console.log(`\nDone. ${config.codes.length} code(s) written to ${qrDir}`);
