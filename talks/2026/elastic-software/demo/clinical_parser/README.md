# Clinical parser — v1 vs v2 vs v3 vs v4

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

## v3 — no format-specific code at all

`lib/v3/parser.rb` is a [squishling](https://github.com/Coolhand-Labs/squishling)
class — Michael's own gem, built on this talk's own premise. It declares
`instructions` and an `output_schema` and nothing else: no `call` method is
ever defined, so every invocation is unconditionally routed to the LLM
(squishling's own rule — "the method has no implementation" — see its
README). There's no shape detection, no gender-translation table, no
per-format class. One class handles all 35 fixtures, including the 15 v1
never could.

```bash
export ANTHROPIC_API_KEY=sk-...
bin/run_v3
```

This one makes a real LLM call per fixture — there's no offline path to
fall back to, because v3 was never given one. Expect some genuine misses;
that variance is itself part of the point: v1 and v2 are exact because
they're code; v3 trades that exactness for not having to write sixteen
fewer classes.

**What actually happened running this for real**, against `claude-haiku-4-5`,
for the record:

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
3. **Fixed it in `instructions` instead** — spelled out HL7's `LAST^FIRST`
   convention, said explicitly that a diagnosis is not a symptom, and gave
   the gender translation concrete examples (including HL7's O/U/A/N
   letter codes). Re-ran: **31/35.**

The remaining 4 are the two failure modes instructions genuinely can't
fix: two bare SNOMED gender-identity codes with no label attached (the
model correctly refuses to guess what an opaque code means — see
`PROVENANCE.md`), and two HL7 letter codes (`O`, `A`) the model still
reads as a gender despite being told not to. v2's hand-written translation
table gets those right for a reason v3 structurally can't: it was handed
the mapping instead of having to infer it.

## v4 — real Ruby for the common case, `squish!` for the rest

`lib/v4/parser.rb` is the hybrid both earlier versions were pointing at:
**the same deterministic FHIR Bundle parser as v1**, but instead of raising
on anything it can't handle, two separate `rescue`s hand that one call to
the LLM with [squishling's `squish!`](https://github.com/Coolhand-Labs/squishling/pull/3)
(PR #3, not yet merged — see `Gemfile`):

1. **The input isn't a FHIR Bundle this parser can read at all** — not
   JSON, no `"entry"`, no `Patient` resource. Wrong shape, not just wrong
   values.
2. **It *is* a well-formed Bundle, but a required field came back nil** —
   `MissingFieldError`, raised by this class itself after the Ruby
   extraction runs, when the name, gender, or diagnosis codes it found are
   empty.

Both rescues call `squish!(context: { parse_error: e }, append_instructions: "...")` —
handing the LLM the *original* raw record (not whatever Ruby partially
extracted) plus the specific error as context, and — via
`append_instructions "...", self` at the class level — this class's own
Ruby source, so the model has the same shape and intent Ruby was working
from.

```bash
export ANTHROPIC_API_KEY=sk-...
bin/run_v4
```

This runs the same 35 fixtures as v1/v2/v3, plus one more:
`fixtures/missing_gender.json` — a real, well-formed `canonical_fhir`
bundle (patient 001, Abdul Koepp) with `gender` set to `null`, built
specifically to exercise rescue 2 (none of the other 35 have a nil field
in an otherwise-valid Bundle, by construction).

**What actually happened, running it for real:** 20 of the 36 cases never
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

## Regenerating fixtures

Fixtures are committed, static files — normally you'd never touch this.
If the fixture set itself needs to change:

```bash
ruby tools/generate_fixtures.rb
```

This rewrites every file under `fixtures/`, including `manifest.json`,
from `tools/synthea_source.json` (no network access needed — see
`PROVENANCE.md` if you need to change which real patients are used).
