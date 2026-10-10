# lib/v3/parser_judged_ensemble.rb — the refined purpose, with
# :judged_squishsum (squishling PR #20,
# https://github.com/Coolhand-Labs/squishling/pull/20, filed in response to
# https://github.com/Coolhand-Labs/squishling/issues/19). On the pinned
# commit, :judged_squishsum still samples the escalation's first step
# *twice* — it does not yet sample two different steps, despite the
# escalation below declaring claude-haiku-4-5 and claude-sonnet-5-5. That
# means both samples here are claude-haiku-4-5; claude-sonnet-5-5 is
# currently unused config. claude-opus-5-5 is the explicit judge, consulted
# when the two Haiku samples disagree. See bin/run_v3_judged_ensemble.
#
# params: { temperature: 0.1 } is Haiku-only, set on its own step rather
# than at the class level: claude-sonnet-5-5 and claude-opus-5-5 run
# adaptive thinking by default and reject `temperature` outright ("the
# provider rejected the request: `temperature` is deprecated for this
# model") — found by actually running this against the two newer models,
# not from docs. Each later step sets `params: { temperature: nil }` to
# unset the key rather than inherit it (see squishling's
# docs/configuration.md "Unsetting an inherited key").
require "squishling"
require_relative "../clinical_record"

module V3
  class ParserJudgedEnsemble
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
