# lib/v3/parser.rb — the squishling version. No case statement, no class
# per format, no gender-translation table: one class, no Ruby
# implementation at all. Every call is unconditionally squished straight to
# the LLM (see https://github.com/Coolhand-Labs/squishling —
# "the method has no implementation" is one of squishling's two routing
# triggers, and `call` is squished by default).
require "squishling"
require_relative "../clinical_record"

module V3
  class Parser
    include Squishling

    # Low temperature for a structured-extraction task — squishling added params:
    # (temperature/thinking/etc.) after the first run of this class showed symptom
    # hallucination on empty-symptom records. Kept for genuine determinism value even though it
    # didn't fix that particular failure on its own — see the purpose below for the actual
    # fix: it was a systematic misreading, not sampling noise (temperature 0.1 made it *more*
    # consistent, not less).
    squishling params: { temperature: 0.1 }

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

    # Adapts the squished result onto this repo's own ClinicalRecord, so v3
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
