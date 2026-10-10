# lib/v3/parser_judged_escalation.rb — the refined purpose, with squishling's
# own documented pattern for combining escalation and judged_squishsum (see
# docs/harnesses.md):
#
#   escalation: [{ model: "claude-haiku-4-5", attempts: 2 }, "claude-sonnet-5-5"],
#   harness: :judged_squishsum   # two Haiku samples; Sonnet judges when they differ
#
# Worth being precise about what this actually samples: squishsum's two
# concurrent samples both run on the escalation's *first* step only
# (lib/squishling/invoker.rb's Invoker#squishsum: `steps =
# path.take_while { |step| step == path.first }`) — so both samples here are
# claude-haiku-4-5, not one Haiku and one Sonnet. Sonnet only ever appears
# as the judge, consulted when the two Haiku samples disagree, and never
# contributes a candidate answer of its own. See bin/run_v3_judged_escalation.
require "squishling"
require_relative "../clinical_record"

module V3
  class ParserJudgedEscalation
    include Squishling

    squishling params: { temperature: 0.1 }, provider: :anthropic,
      escalation: [{ model: "claude-haiku-4-5-20251001", attempts: 2 }, "claude-sonnet-5-5"],
      harness: :judged_squishsum

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
