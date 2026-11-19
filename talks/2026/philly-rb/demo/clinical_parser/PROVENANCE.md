# Fixture provenance

Patient identity and diagnoses in every one of the 100 fixtures are **real**
— not invented — pulled from actual [Synthea](https://github.com/synthetichealth/synthea)
(Apache-2.0) synthetic-patient output. Only the symptom values and each
format's surrounding "noise" fields are this exercise's own invention.

## What's real

`tools/synthea_source.json` holds, for each of 100 patients, an unmodified
excerpt of one real Synthea-generated FHIR bundle: the full `Patient`
resource, up to 3 distinct `Condition` resources (real SNOMED CT codes and
displays), and a handful of that patient's other real resources
(`Immunization`, `Procedure`, `Encounter`) kept around purely as bundle
noise. (Patients 36–100 were added later, by hand, the same way: a random draw
from the same directory excluding the first 35, keeping only patients with
at least three distinct active conditions, two immunizations, a procedure
and an encounter, and a name free of Synthea's numeric suffixes.) Bundles
were mirrored from
[smart-on-fhir/generated-sample-data](https://github.com/smart-on-fhir/generated-sample-data)
(`R4/SYNTHEA/`) — each patient's `source_file`/`source_url` in
`synthea_source.json` points at exactly which file it came from.

## What's invented

- **Symptoms** — Synthea doesn't model symptoms as their own resource (its
  `Observation`s are vitals, labs, and surveys; see the research notes in
  the `demo/` README one level up). `tools/generate_fixtures.rb` assigns
  each patient 0–4 symptoms from a small fixed vocabulary, deterministically
  by index, and renders them into whatever shape that patient's format uses.
- **Everything format-specific that isn't demographic or diagnostic** — the
  `fhir_variant` format's `billing`/`insurance` blocks, the HL7 fixtures'
  `NK1`/`PV1`/`IN1`/`ZPI` segments, and the pipe-delimited fixtures'
  `FACILITY_ID`/`BILLING_CODE`/`WARD`/etc. columns are invented noise —
  plausible values in a plausible shape, standing in for the dozen fields a
  real inbound record carries that this parser has no reason to care about.
- **The gender/sex value on the 15 v2-only fixtures** — real Synthea data
  is only ever "male" or "female", but real inbound feeds carry more than
  that. `GENDER_SOURCE_OVERRIDE` in `tools/generate_fixtures.rb` replaces
  those 15 patients' gender value with a real code from one of three actual
  code systems (see `lib/normalizers.rb` for the full list and citations),
  in whatever representation that record's own format would plausibly use.
  The underlying patient identity, name, and diagnoses are untouched —
  only the gender/sex field itself is substituted, deliberately, to
  exercise the translation table.

## What's invented in the exotic fixtures (079–100)

Same rule as the rest: patient name, DOB, address, phone and the three
diagnoses are real Synthea values; **everything else is made up** —
symptoms, vitals, medications (real RxNorm codes, invented prescriptions),
payer/group IDs, provider names, facility names (rotated from a short
list), claim numbers, chat messages, dictation filler, and the OCR errors
injected into the fax's label text. The patient's own data is never
corrupted in any of them: even the OCR'd fax and the digit-by-digit
dictation carry the codes exactly. Gender sources on these 22 are chosen per
format by `FORMATS` in `tools/exotic_formats.rb`.

## Format assignment

- **001–020** (v1, `canonical_fhir`): a full FHIR `Bundle` — the real
  `Patient` + `Condition` + noise resources, plus one synthetic `Observation`
  per symptom.
- **021–025** (`fhir_variant`): the same real patient data, re-keyed into a
  different, still-FHIR-flavored JSON shape a different vendor might export.
- **026–030** (`hl7`): the same real patient data as an HL7 v2.3 message.
- **031–035** (`pipe_delimited`): the same real patient data as a legacy
  pipe-delimited flat-file export.

- **036–078** (`canonical_fhir`): 43 more of the same, from the added patients.
- **079–100** (exotic): 22 one-off formats, one fixture each — see the table
  in `README.md`.

Regenerating (`ruby tools/generate_fixtures.rb`) re-derives every fixture
from `synthea_source.json` — no network access needed. Re-deriving
`synthea_source.json` itself does need network access to GitHub; there's no
committed script for that step since it was a one-time, by-hand extraction
(see the file's own `source_url` fields to re-fetch by hand if ever needed).

## squishling, as a dependency

`lib/v3/parser.rb` and `lib/v4/parser.rb` are the only things in this
exercise with a real external dependency: `Gemfile` pulls
[squishling](https://github.com/Coolhand-Labs/squishling) straight from
GitHub (git source, not a published gem yet). It's moved twice so far:

1. Built and validated against the `squish_me` development branch.
2. Re-validated unchanged after that branch merged to `main` as the v0.1.0
   release — which also moved it onto `ruby_llm ~> 2.0` and swapped
   `ruby_llm-schema` for a new standalone gem, `schematist`; the
   `output_schema` DSL was unaffected by that swap.
3. Pinned for a while to [PR #3](https://github.com/Coolhand-Labs/squishling/pull/3)'s
   branch (`mikecarroll/append-instructions-squish-bang`), for `squish!` and
   `append_instructions` — v4 needed both; v3 didn't and worked unchanged
   back on `main`.
4. **Currently pinned to a specific commit on `main`**
   (`ce4146bd7bd0c42518142f9402ee5a2282b1e833`, 2026-10-09) now that PR #3
   merged (2026-10-08). Two renames landed with the merge: the class-level
   `instructions` became `purpose`, and `append_instructions` became
   `append_to_purpose` — both `lib/v3/parser.rb` and `lib/v4/parser.rb` were
   updated to match. `main` is still unreleased and moving, so this is
   pinned to a commit, not the branch, to keep the demo reproducible.

See the top-level conversation / commit history for the issues found while
integrating any of these against this machine (unrelated `json`/`bigdecimal`
native-extension mismatches, both pinned around in the `Gemfile` — nothing
in squishling's own code).

## v4's extra fixture

`fixtures/missing_gender.json` is **not** one of the 100 — it's
`001_canonical_fhir.json` (the real patient Abdul Koepp) with the
`Patient.gender` field set to `null`, built specifically to exercise v4's
second `rescue` (a well-formed Bundle with a genuinely empty required
field), which none of the 100 trigger by construction. `bin/run_v4` runs it
as a 36th, separate case.
