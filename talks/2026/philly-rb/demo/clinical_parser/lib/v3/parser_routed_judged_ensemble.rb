# lib/v3/parser_routed_judged_ensemble.rb — slide 22's router ("Code the
# standard shapes. Squish the rest.") made real: the actual hardened
# V1::Parser (canonical FHIR Bundle only) handles what it recognizes, and
# squish! takes over on V1::UnrecognizedFormatError — now with
# :judged_squishsum instead of a single attempt, same as
# lib/v3/parser_judged_ensemble.rb (see that file's header: on the pinned
# commit, both samples are claude-haiku-4-5 — claude-sonnet-5-5 in the
# escalation below is currently unused). Isolates "does the harness change
# the router's own numbers" as the only variable against the single-attempt
# router's 95/100, $0.06/100 calls (bin/run_v3's log, filtered to the
# non-canonical-FHIR fixtures).
require "squishling"
require_relative "../clinical_record"
require_relative "../v1/parser"

module V3
  class ParserRoutedJudgedEnsemble
    include Squishling

    squishling provider: :anthropic,
      escalation: [
        { model: "claude-haiku-4-5-20251001", params: { temperature: 0.1 } },
        { model: "claude-sonnet-5-5", params: { temperature: nil } }
      ],
      harness: { type: :judged_squishsum,
                 judge: { model: "claude-opus-5-5", params: { temperature: nil } } }

    purpose <<~PURPOSE
      Map the inbound clinical record — in whatever format it arrives — onto
      the schema below. Ignore every field that isn't the patient's name,
      their gender, their diagnosis codes, or their symptoms.

      Name: output it in normal "First Last" order and capitalization, even
      if the source formats it differently — for example, HL7's PID segment
      writes names as LAST^FIRST, often all upper-case.

      Gender: translate to exactly one of "male", "female", "trans", or
      "unknown".
        - "trans" only when the source value itself asserts a trans or
          gender-nonconforming identity — a plain word like "transgender" or
          "non-binary" counts, and so does a code labeled that way.
        - "unknown" whenever the source value doesn't assert a gender at
          all: an administrative "other" / "unknown" / "ambiguous" / "not
          applicable" code (including bare letter codes, e.g. HL7's
          O / U / A / N), or any gender code you don't recognize and have no
          label for. When in doubt, "unknown" — never guess "male" or
          "female" from an unfamiliar code.

      Symptoms: only include one if the record reports it as a symptom
      explicitly — a dedicated symptom/observation entry, or a labeled
      "symptoms" field. A diagnosis is not a symptom; never infer symptoms
      from diagnosis or condition names. If the record reports none, return
      an empty array.
    PURPOSE

    output_schema do
      string :patient_name
      string :patient_gender, enum: %w[male female trans unknown]
      array :diagnosis_codes, of: :string
      array :symptoms, of: :string
    end

    def call(record:)
      parsed = V1::Parser.new(record).parse
      result(
        patient_name: parsed.patient_name,
        patient_gender: parsed.patient_gender,
        diagnosis_codes: parsed.diagnosis_codes,
        symptoms: parsed.symptoms
      )
    rescue V1::UnrecognizedFormatError
      squish!
    end

    def self.parse(raw)
      squished = call(record: raw)
      ClinicalRecord.new(
        patient_name: squished.patient_name,
        patient_gender: squished.patient_gender,
        diagnosis_codes: squished.diagnosis_codes,
        symptoms: squished.symptoms
      )
    end
  end
end
