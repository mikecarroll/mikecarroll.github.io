# lib/v3/parser_escalation.rb — the refined purpose (lib/v3/parser.rb)
# unchanged, with squishling's default :escalation harness instead of a
# single attempt: one claude-haiku-4-5 attempt, escalating to
# claude-sonnet-5-5 only if that attempt's output is invalid (fails the
# output_schema or a squish_validate check). Isolates the harness as the
# only variable against bin/run_v3's 95/100 — see bin/run_v3_escalation and
# its header for why this one, unlike judged_squishsum, structurally can't
# reach Sonnet on the 5 known failures: they're schema-valid, just wrong.
require "squishling"
require_relative "../clinical_record"

module V3
  class ParserEscalation
    include Squishling

    squishling params: { temperature: 0.1 }, provider: :anthropic,
      escalation: [{ model: "claude-haiku-4-5-20251001", attempts: 1 }, "claude-sonnet-5-5"]

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

    # No `call` method below this line — that's the whole implementation.
    # Leaving it undefined is what makes every invocation squish.

    # Adapts the squished result onto this repo's own ClinicalRecord, so it
    # drops into the same bin/run_v1 / bin/run_v2 harness and manifest.
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
