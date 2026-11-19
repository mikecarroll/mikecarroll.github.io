# lib/v3/parser_final.rb — everything from the talk in one class: a short purpose, the
# rules as field descriptions, an escalation + judged_squishsum harness, and a
# `call` that routes the standard FHIR shape to plain Ruby and squishes the rest.
# Run with bin/run_v3_final.
require "squishling"
require_relative "../clinical_record"
require_relative "../v1/parser"

module V3
  class ParserFinal
    include Squishling

    squishling provider: :anthropic,
      escalation: [
        { model: "claude-haiku-4-5-20251001", params: { temperature: 0.1 } },
        { model: "claude-sonnet-5-5", params: { temperature: nil } }
      ],
      harness: { type: :judged_squishsum,
                 judge: { model: "claude-opus-5-5", params: { temperature: nil } } }

    purpose "Map the inbound clinical record, in whatever format it arrives, onto the schema. Ignore every field that is not the patient's name, gender, diagnosis codes, or symptoms."

    output_schema do
      string :patient_name,
        description: 'Output in "First Last" order and normal capitalization, even if the source writes it as HL7\'s LAST^FIRST, often in all caps.'
      string :patient_gender, enum: %w[male female trans unknown],
        description: 'Translate the source value. "trans" only when the source itself asserts a trans or gender-nonconforming identity (a plain word like "transgender" or "non-binary", or a code labeled that way). "unknown" when the source does not assert a gender: an administrative "other" / "unknown" / "ambiguous" / "not applicable" code, including HL7\'s bare O / U / A / N letter codes, or any code you do not recognize. Never guess "male" or "female" from an unfamiliar code.'
      array :diagnosis_codes, of: :string
      array :symptoms, of: :string,
        description: 'Only symptoms the record reports explicitly, in a symptom/observation entry or a labeled "symptoms" field. A diagnosis is not a symptom; never infer one from a diagnosis name. [] if none.'
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
