# Fixture provenance

Both fixtures describe the same synthetic patient in two different wire
formats — that's the point (slide 29's demo).

- **`fhir_patient.json`** — the `Patient` resource from a real
  [Synthea](https://github.com/synthetichealth/synthea) (Apache-2.0)
  synthetic-patient bundle, `Abdul_Koepp_e925b0f3-…json`, mirrored at
  [smart-on-fhir/generated-sample-data](https://github.com/smart-on-fhir/generated-sample-data)
  (`R4/SYNTHEA/`). Untouched apart from extracting the single `Patient`
  entry out of its bundle. All values are synthetic — no real patient data.

- **`hl7_adt_a01.hl7`** — a hand-built HL7 v2.3 `ADT^A01` message, written
  from scratch against the public HL7 v2.3 segment spec (`MSH`/`EVN`/`PID`/`PV1`),
  carrying the *same* synthetic demographics as the FHIR fixture but in
  legacy field-position-and-pipe form: name as `KOEPP^ABDUL^^^MR.`, DOB as
  `19560803` instead of `1956-08-03`, and — deliberately — no SSN field at
  all (`PID-19` is absent). This is what should map to `"ssn": null`.

  This was written rather than vendored from an existing sample repo because
  the two HL7-example repos found during research
  ([`Work-In-Progress-For-Health/hl7-v2-examples`](https://github.com/Work-In-Progress-For-Health/hl7-v2-examples),
  the closest concrete-instance-data match) don't declare a license.
