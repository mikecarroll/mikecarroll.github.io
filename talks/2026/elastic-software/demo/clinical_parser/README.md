# Clinical parser — v1 vs v2 vs v3 vs v4

A self-contained companion to the `ai_parser`/`call_parser` demo one level
up: same "onboard a new client's data" premise from slides 5–8 and 18–22,
but worked the traditional way (deterministic Ruby, no LLM) so you can show
the actual cost of the hardened-parser path before the AI-parser slides
make their case.

Target schema (`ClinicalRecord`): patient name, patient gender, diagnosis
code(s), symptoms.

## The setup

**100 fixtures, 26 formats, real patient data.** The first 35 are the
original four-format set described next; fixtures `036`–`100` (see
"The 65 added fixtures" below) top it up with 43 more standard FHIR bundles
and 22 one-off formats. Patient demographics and
diagnoses are pulled from real [Synthea](https://github.com/synthetichealth/synthea)
synthetic-patient bundles — not invented — with each format's own noise
fields layered on top. See `PROVENANCE.md` for exactly what's real vs.
invented and where the real data came from.

- **20 fixtures** (`001`–`020`, `canonical_fhir`) — a full FHIR `Bundle`:
  the real `Patient` resource (extensions, multiple identifiers, address,
  telecom — all genuine Synthea noise), real `Condition` entries (SNOMED CT
  codes, `clinicalStatus`, `onsetDateTime`, encounter references), a few
  unrelated real resources thrown into the same bundle (`Immunization`,
  `Procedure`, `Encounter`), and one small synthetic `Observation` per
  symptom. This is v1's whole world.
- **15 fixtures** (`021`–`035`), same real patients, three different valid
  structures:
  - `021`–`025` **`fhir_variant`** — still nominally "FHIR," but re-keyed:
    `subject.fullName`/`birthSex` instead of a `Patient` resource,
    `diagnosisList[].codeValue` instead of `Condition.code.coding`, plus a
    `billing`/`insurance` block of noise.
  - `026`–`030` **`hl7`** — an HL7 v2.3 message: `PID` for name/gender,
    `DG1` per diagnosis, `OBX` per symptom, surrounded by real-shaped noise
    segments (`EVN`, `NK1`, `PV1`, `IN1`, a vendor `ZPI` segment).
  - `031`–`035` **`pipe_delimited`** — a legacy flat-file export: one
    pipe-delimited header line, one data line, a dozen irrelevant columns
    (facility, MRN, admit/discharge dates, billing code, ward, attending)
    around the four that matter.

## The 65 added fixtures

The original 35 are a neat little teaching set: four formats, every one
documented, every one handled by exactly one v2 class. Real inbound data is
messier, so `036`–`100` extend it to 100 fixtures — same real Synthea
patients (65 more, never reused), same four target fields, much less
politeness.

- **`036`–`078`: 43 more `canonical_fhir` bundles** — identical in shape to
  `001`–`020`, so every parser that handled those handles these. That makes
  63 canonical bundles (plus the 5 `fhir_variant` ones) out of 100, i.e.
  roughly two-thirds standard FHIR.
- **`079`–`100`: 22 one-off formats**, one fixture each, rendered by
  `tools/exotic_formats.rb`. Every one carries the patient's name, gender,
  SNOMED diagnosis codes, and symptoms *somewhere*, surrounded by invented
  noise (vitals, medications, billing, boilerplate, audit rows, chat
  chatter):

  | File | Format | Where the answer hides |
  | --- | --- | --- |
  | `079_cda_xml.xml` | C-CDA / CDA R2 XML | `recordTarget`, problem-list `observation/@code`, HPI `<list>` |
  | `080_fhir_xml.xml` | FHIR R4 Bundle as **XML** | `<gender value=…/>`, `<Condition><code>`, `<valueString>` |
  | `081_pdf.pdf` | real PDF (uncompressed, hand-assembled) | page 1 patient block, page 2 diagnoses/symptoms |
  | `082_soap_note.txt` | dictated SOAP note, abbreviations and all | `S:` complaint, `A/P:` numbered diagnoses |
  | `083_csv.csv` | wide denormalised CSV (32 columns) | `dx_n_code`, `symptom_n` columns |
  | `084_yaml.yaml` | YAML export | `person`, `problems`, `reported_symptoms` |
  | `085_eml.eml` | MIME email with an unrelated CSV attachment | referral body prose |
  | `086_rtf.rtf` | RTF visit letter | bulleted diagnoses, `\par` control words everywhere |
  | `087_markdown.md` | wiki-style Markdown note | tables + lists |
  | `088_html_portal.html` | patient-portal "after visit summary" | `.pt-name`, `data-snomed` attributes |
  | `089_html_embedded_fhir.html` | SMART-launch page | FHIR Bundle inside `<script type="application/fhir+json">` |
  | `090_sql_dump.sql` | mysqldump | `INSERT`s across `patients`/`diagnoses`/`symptoms` |
  | `091_x12_837.x12` | X12 837P claim | `NM1*IL`, `DMG`, `HI` segment, `NTE*ADD` |
  | `092_ndjson_bulk.ndjson` | FHIR Bulk Data `$export` (one resource per line) | `Patient`, `Condition`, `Observation` lines |
  | `093_fixed_width.dat` | mainframe fixed-width record + COBOL-style copybook | column positions |
  | `094_sms_chat.txt` | care-team chat export | free conversation |
  | `095_spreadsheetml.xml` | Excel 2003 SpreadsheetML workbook | `Patient`/`Diagnoses`/`Symptoms` sheets |
  | `096_rdf_turtle.ttl` | FHIR RDF (Turtle) | nested `fhir:Coding.code [ fhir:value … ]` blank nodes |
  | `097_json_ld.jsonld` | schema.org JSON-LD | `Patient.diagnosis` / `signOrSymptom` |
  | `098_ocr_fax.txt` | OCR'd fax, with scan artefacts | form fields, `LAST, FIRST` |
  | `099_dictation.txt` | speech-to-text transcript | codes **spoken as digits** ("one six two eight…") |
  | `100_base64_envelope.json` | JSON message envelope | the summary is a **base64** attachment |

Gender values on the exotic fixtures are keys of
`Normalizers::GENDER_TRANSLATIONS` written the way each format would carry
them (`M`, `Female`, `non-binary`, `other`, a SNOMED gender-identity code
with its label, …), so `manifest.json`'s `expected` stays computable from the
same table v2 uses. Several are deliberately not `male`/`female`.

**What this does to the pass rates** (deterministic runs, no API key needed):

| Runner | All 100 | `ORIGINAL_35=1` |
| --- | --- | --- |
| `bin/run_v1` | 63 / 100 | 20 / 35 |
| `bin/run_v2` | 78 / 100 | 35 / 35 |

v2's 22 misses are the point: every one is a format that would need its own
new subclass and detector. `bin/run_v3` and `bin/run_v3_first_pass` (see
below) have since been re-run against all 100 — `bin/run_v4` has not yet;
its results below, and in the deck, are still against the original 35 — run
with `ORIGINAL_35=1` to reproduce them.

## A second wrinkle: gender

It's not just the record's *shape* v1 only half-understands — it's individual
*values* too. Real Synthea data is only ever `"male"`/`"female"`, so v1 was
only ever built with a 3-word gender vocabulary: `male`, `female`, `trans`
(see `V1::Parser::GENDER_VOCABULARY`). The 15 v2-only fixtures each carry a
real gender/sex source value from outside that vocabulary — a FHIR
administrative code, an HL7 v2 Table 0001 letter, a Gender Harmony SNOMED
CT code, or a free-text label — in whatever representation that record's
own format would plausibly use. `lib/normalizers.rb::GENDER_TRANSLATIONS`
is the actual translation table v2 uses to turn each of those into one of
`ClinicalRecord`'s four accepted values (`male`/`female`/`trans`/`unknown`),
with real citations for every source code system. See `PROVENANCE.md` for
which fixture got which value and why.

## v1 — one parser, one shape

`lib/v1/parser.rb` is the "day one, it is beautiful" parser: it assumes a
`Patient`+`Condition` FHIR Bundle, and a gender value that's literally the
word `male`, `female`, or `trans` — nothing else.

```bash
bin/run_v1
```

Expected: **63 pass, 37 fail** across all 100 fixtures (**20 pass, 15 fail**
with `ORIGINAL_35=1`) — every failure is `V1::UnrecognizedFormatError`,
not a crash. v1 was never built to notice a different shape, let alone
handle one, and the same goes for a gender value outside its 3-word
vocabulary.

## v2 — detect the shape, delegate to a class

`lib/v2/base_parser.rb` defines the interface every format parser
implements: `.handles?(raw)` (sniff, never raise) and `#parse` (do the
work). `lib/v2/parsers/` has one subclass per format —
`CanonicalFhirParser` (delegates straight back to `V1::Parser`, so the
original logic is re-homed, not rewritten), `FhirVariantParser`,
`Hl7SegmentParser`, `PipeDelimitedParser`. `lib/v2/dispatcher.rb` tries
each class's `.handles?` in turn and hands the raw record to the first
match.

```bash
bin/run_v2
```

Expected: **78/100 pass** — the 22 exotic fixtures (`079`–`100`) have no
parser class and fail with `none of 4 known formats recognize this record`.
With `ORIGINAL_35=1`: **35/35 pass.**

## v3 — no format-specific code at all

`lib/v3/parser.rb` is a [squishling](https://github.com/Coolhand-Labs/squishling)
class — Michael's own gem, built on this talk's own premise. It declares
`purpose` and an `output_schema` and nothing else: no `call` method is
ever defined, so every invocation is unconditionally routed to the LLM
(squishling's own rule — "the method has no implementation" — see its
README). There's no shape detection, no gender-translation table, no
per-format class. One class handles every fixture, including the ones v1
never could.

```bash
export ANTHROPIC_API_KEY=sk-...
export COOLHAND_API_KEY=...   # optional — monitors every LLM call via Coolhand
bin/run_v3
```

This one makes a real LLM call per fixture — there's no offline path to
fall back to, because v3 was never given one. Expect some genuine misses;
that variance is itself part of the point: v1 and v2 are exact because
they're code; v3 trades that exactness for not having to write sixteen
fewer classes.

**What actually happened running this for real** (against the original 35
fixtures, `ORIGINAL_35=1`), against `claude-haiku-4-5`, for the record:

1. **First pass: 23/35.** Diagnosis codes — exact alphanumeric SNOMED codes,
   pulled verbatim out of four differently-shaped formats — were right in
   all 35. The failures: HL7 names came back untouched (`"REILLY^ALIX"`
   instead of `"Alix Reilly"`); bare, unlabeled gender-identity codes
   defaulted to `unknown`; and three of four zero-symptom `canonical_fhir`
   records hallucinated symptoms out of their *diagnosis* display text.
2. **Reported the hallucination to squishling's author**, who added
   `params:` (temperature, thinking, etc.) to the gem in response — see
   `lib/v3/parser.rb`'s `squishling params: { temperature: 0.1 }`.
   Re-ran: **still 23/35**, same 12 files — and the zero-symptom case got
   *more* consistent about being wrong, not less (011 flipped from pass to
   fail). That's the tell it was never sampling noise — the model was
   systematically treating "diagnosis nearby, no symptom entry" as license
   to invent one. Lower temperature just made the wrong call deterministic.
3. **Fixed it in `purpose` instead** — spelled out HL7's `LAST^FIRST`
   convention, said explicitly that a diagnosis is not a symptom, and gave
   the gender translation concrete examples (including HL7's O/U/A/N
   letter codes). Re-ran: **31/35.**

The remaining 4 are the two failure modes the purpose genuinely can't
fix: two bare SNOMED gender-identity codes with no label attached (the
model correctly refuses to guess what an opaque code means — see
`PROVENANCE.md`), and two HL7 letter codes (`O`, `A`) the model still
reads as a gender despite being told not to. v2's hand-written translation
table gets those right for a reason v3 structurally can't: it was handed
the mapping instead of having to infer it.

**Re-run against all 100 fixtures**, against `claude-haiku-4-5-20251001`,
once the fixture set grew past the original 35:

- `lib/v3/parser_first_pass.rb` — a second, frozen class holding step 1's
  purpose (the one-paragraph version, no `squishling params:` override), so
  the "first pass" result above stays a real, re-runnable number instead of
  a remembered one now that `lib/v3/parser.rb` has moved on to the refined
  purpose. `bin/run_v3_first_pass` runs it: **73/100.** Same two failure
  clusters as before (HL7 names, hallucinated symptoms, gender codes), now
  spread across a wider set of shapes.
- `bin/run_v3` (the refined purpose, unchanged): **95/100.** The same two
  structural failure modes survive from the original 35 (unlabeled SNOMED
  gender-identity codes, HL7 letter codes) — plus exactly one new miss from
  the added 65: a dictation transcript with diagnosis codes spoken as digits.

Both runners pass `Squishling.configure`'s `squawk:` hook to
`lib/usage_log.rb`, which writes one JSON line per LLM attempt — model,
token usage, pass/fail — to `tmp/usage_v3{,_first_pass}.jsonl` (gitignored).
At $1/$5 per MTok in/out (Claude Haiku 4.5 pricing), that's **$0.48** for
the first-pass run and **$0.51** for the refined run, across all 100 calls
each — real totals, not estimates, which is what's on the deck's pills.

**Would a second opinion help?** Four more variants, all the refined purpose
unchanged, each isolating one harness as the only variable against
`bin/run_v3`'s 95/100 (the exact same 5 misses throughout: 024, 025
unlabeled-SNOMED-identity fhir_variant; 028, 030 HL7 letter-code hl7; 099
dictation digit transcription):

- **`lib/v3/parser_judged.rb`** — `judged_squishsum`: two independent
  `claude-haiku-4-5` samples, `claude-sonnet-5-5` judging on disagreement.
  `bin/run_v3_judged`: **95/100**, roughly double the cost (**$1.02** for 200
  sample calls). `tmp/usage_v3_judged.jsonl` logged **zero** judge calls —
  at `temperature: 0.1` the two samples agreed on every fixture, including
  the five they both got wrong. Same conclusion as the temperature
  experiment two sections up: systematic misreadings, not sampling noise,
  so a harness built to catch *disagreement* never fires.
- **`lib/v3/parser_escalation.rb`** — squishling's default `:escalation`
  harness, `claude-haiku-4-5` escalating to `claude-sonnet-5-5` only on
  invalid output. Run on just the 5 known misses
  (`bin/run_v3_escalation <files>`): **0/5**, 0 escalations — all 5 are
  schema-valid, just wrong, so there's nothing to escalate from.
- **`lib/v3/parser_judged_escalation.rb`** — squishling's own documented
  pattern for combining the two (`escalation: [{model: haiku, attempts: 2},
  sonnet], harness: :judged_squishsum`). Run on the same 5
  (`bin/run_v3_judged_escalation <files>`): **0/5**. `judged_squishsum`'s two
  samples both run on the escalation's *first* step only
  (`Invoker#squishsum`: `steps = path.take_while { |step| step == path.first
  }`) — confirmed live via `squawk`, every sample reported
  `model: claude-haiku-4-5`, Sonnet never appeared, not even as judge. Filed
  as [squishling#19](https://github.com/Coolhand-Labs/squishling/issues/19):
  there was no way to compare two *different* models directly.
- **`lib/v3/parser_judged_ensemble.rb`** and **`lib/v3/parser_routed_judged_ensemble.rb`**
  — originally built against [squishling#20](https://github.com/Coolhand-Labs/squishling/pull/20)'s
  `:judged_ensemble` harness (shipped the same day as #19), which sampled
  the escalation's first *and second* steps instead of the first twice:
  `claude-haiku-4-5` and `claude-sonnet-5-5` each sampled directly,
  `claude-opus-5-5` judging on disagreement. That got **100/100**
  (`bin/run_v3_judged_ensemble`, every one of the 5 original failures
  resolved) and **98/100** for the routed version (`bin/run_v3_routed_judged_ensemble`,
  63 routed free / 37 squished), at real cost **$1.87** and **$0.27**
  respectively.

  PR #20's description was later rewritten to fold this into
  `:squishsum`/`:judged_squishsum` directly instead of keeping separate
  `:ensemble`/`:judged_ensemble` types — but **the code on the pinned
  commit (`issue-19`, `2838ee5`) never actually changed to match**;
  `:judged_squishsum` there still only samples the first escalation step
  twice. Both files now declare `harness: { type: :judged_squishsum, ... }`
  to match the description's intent, same escalation array
  (`claude-haiku-4-5`, `claude-sonnet-5-5`) and judge (`claude-opus-5-5`)
  as before. Re-run for real against all 100 fixtures: **95/100** for both
  — the exact same five misses as a single attempt, Sonnet never sampled
  (confirmed live via `squawk`: every sample reports `model:
  claude-haiku-4-5`), zero judge calls. Cost: **$1.02** (`bin/run_v3_judged_ensemble`,
  double the single-attempt cost for zero benefit) and **$0.12**
  (`bin/run_v3_routed_judged_ensemble`, still a 76% discount off squishing
  all 100 — routing the 63% that already matches a known shape keeps
  paying off even when the harness sampling doesn't help). Same
  conclusion as the original squishsum experiment, reproduced under the
  new name: asking the same model twice at `temperature: 0.1` doesn't
  catch what it confidently gets wrong — only a genuinely different model,
  or a better purpose, does. See the deck's slides 20 and 22.

## v4 — real Ruby for the common case, `squish!` for the rest

`lib/v4/parser.rb` is the hybrid both earlier versions were pointing at:
**the same deterministic FHIR Bundle parser as v1**, but instead of raising
on anything it can't handle, two separate `rescue`s hand that one call to
the LLM with [squishling's `squish!`](https://github.com/Coolhand-Labs/squishling/pull/3)
(landed on main via PR #3 — see `Gemfile` for the pinned commit):

1. **The input isn't a FHIR Bundle this parser can read at all** — not
   JSON, no `"entry"`, no `Patient` resource. Wrong shape, not just wrong
   values.
2. **It *is* a well-formed Bundle, but a required field came back nil** —
   `MissingFieldError`, raised by this class itself after the Ruby
   extraction runs, when the name, gender, or diagnosis codes it found are
   empty.

Both rescues call `squish!(context: { parse_error: e }, append_to_purpose: "...")` —
handing the LLM the *original* raw record (not whatever Ruby partially
extracted) plus the specific error as context, and — via
`append_to_purpose "...", self` at the class level — this class's own
Ruby source, so the model has the same shape and intent Ruby was working
from.

```bash
export ANTHROPIC_API_KEY=sk-...
export COOLHAND_API_KEY=...   # optional — monitors every escalated LLM call via Coolhand
bin/run_v4
```

This runs the same fixtures as v1/v2/v3, plus one more:
`fixtures/missing_gender.json` — a real, well-formed `canonical_fhir`
bundle (patient 001, Abdul Koepp) with `gender` set to `null`, built
specifically to exercise rescue 2 (none of the other 35 have a nil field
in an otherwise-valid Bundle, by construction).

**What actually happened, running it for real** (original 35 + the extra
case): 20 of the 36 cases never
leave Ruby — every `canonical_fhir` fixture, including the four with zero
symptoms, parses exactly, instantly, for free. The other 16 escalate: the
15 non-FHIR-Bundle formats hit rescue 1, and `missing_gender.json` hits
rescue 2 — correctly producing `patient_gender: "unknown"` from a genuinely
absent value, while still recovering the name and diagnoses from context.
Final count: **31/36** — the same two failure modes v3 couldn't clear
either (the two unlabeled SNOMED gender-identity codes, two HL7 letter
codes), plus one of them (`029`) flipped pass-to-fail against v3's last
run on a rerun — a reminder that `temperature: 0.1` is low, not zero.

## Why this is worth showing before the AI-parser slides

Four classes, a dispatcher, and a shared normalizer module for v2 — one
class with no implementation at all for v3 — the same one class as v1,
plus two rescues, for v4. The `ai_parser` one directory up does the same
job by hand in a dozen lines; squishling does it declaratively in about
the same space, and v4 shows the version you'd actually ship: hardened
where the data is well-behaved, elastic where it isn't, one class either
way. Same problem, four very different token-vs-engineering-hours bills —
which is the whole point of the talk.

Re-running the recorded results above means `ORIGINAL_35=1 bin/run_v3` /
`ORIGINAL_35=1 bin/run_v4` — the numbers predate fixtures `036`–`100`.

## Regenerating fixtures

Fixtures are committed, static files — normally you'd never touch this.
If the fixture set itself needs to change:

```bash
ruby tools/generate_fixtures.rb
```

This rewrites every file under `fixtures/`, including `manifest.json`
(plus the format renderers in `tools/exotic_formats.rb`),
from `tools/synthea_source.json` (no network access needed — see
`PROVENANCE.md` if you need to change which real patients are used).
