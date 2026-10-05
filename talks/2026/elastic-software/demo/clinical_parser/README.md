# Clinical parser — v1 vs v2

A self-contained companion to the `ai_parser`/`call_parser` demo one level
up: same "onboard a new client's data" premise from slides 5–8 and 18–22,
but worked the traditional way (deterministic Ruby, no LLM) so you can show
the actual cost of the hardened-parser path before the AI-parser slides
make their case.

Target schema (`ClinicalRecord`): patient name, patient gender, diagnosis
code(s), symptoms.

## The setup

**35 fixtures, four formats, real patient data.** Patient demographics and
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

Expected: **20 pass, 15 fail** — every failure is `V1::UnrecognizedFormatError`,
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

Expected: **35/35 pass.**

## Why this is worth showing before the AI-parser slides

Four classes, a dispatcher, and a shared normalizer module — for four
formats. The `ai_parser` one directory up does the same job in a dozen
lines, for a format it has never seen before, with zero new classes. Same
problem, two very different token-vs-engineering-hours bills — which is
the whole point of the talk.

## Regenerating fixtures

Fixtures are committed, static files — normally you'd never touch this.
If the fixture set itself needs to change:

```bash
ruby tools/generate_fixtures.rb
```

This rewrites every file under `fixtures/`, including `manifest.json`,
from `tools/synthea_source.json` (no network access needed — see
`PROVENANCE.md` if you need to change which real patients are used).
