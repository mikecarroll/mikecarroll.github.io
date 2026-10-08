# Fixture provenance

Patient identity and diagnoses in every one of the 35 fixtures are **real**
— not invented — pulled from actual [Synthea](https://github.com/synthetichealth/synthea)
(Apache-2.0) synthetic-patient output. Only the symptom values and each
format's surrounding "noise" fields are this exercise's own invention.

## What's real

`tools/synthea_source.json` holds, for each of 35 patients, an unmodified
excerpt of one real Synthea-generated FHIR bundle: the full `Patient`
resource, up to 3 distinct `Condition` resources (real SNOMED CT codes and
displays), and a handful of that patient's other real resources
(`Immunization`, `Procedure`, `Encounter`) kept around purely as bundle
noise. Bundles were mirrored from
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

## Format assignment

- **001–020** (v1, `canonical_fhir`): a full FHIR `Bundle` — the real
  `Patient` + `Condition` + noise resources, plus one synthetic `Observation`
  per symptom.
- **021–025** (`fhir_variant`): the same real patient data, re-keyed into a
  different, still-FHIR-flavored JSON shape a different vendor might export.
- **026–030** (`hl7`): the same real patient data as an HL7 v2.3 message.
- **031–035** (`pipe_delimited`): the same real patient data as a legacy
  pipe-delimited flat-file export.

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
3. **Currently pinned to
   [PR #3](https://github.com/Coolhand-Labs/squishling/pull/3)'s branch**
   (`mikecarroll/append-instructions-squish-bang`, not yet merged), for
   `squish!` and `append_instructions` — v4 needs both; v3 doesn't and
   would work unchanged back on `main`.

See the top-level conversation / commit history for the issues found while
integrating any of these against this machine (unrelated `json`/`bigdecimal`
native-extension mismatches, both pinned around in the `Gemfile` — nothing
in squishling's own code).

## v4's extra fixture

`fixtures/missing_gender.json` is **not** one of the 35 — it's
`001_canonical_fhir.json` (the real patient Abdul Koepp) with the
`Patient.gender` field set to `null`, built specifically to exercise v4's
second `rescue` (a well-formed Bundle with a genuinely empty required
field), which none of the 35 trigger by construction. `bin/run_v4` runs it
as a 36th, separate case.
