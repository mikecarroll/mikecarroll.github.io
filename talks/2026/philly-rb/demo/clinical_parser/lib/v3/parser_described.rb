# lib/v3/parser_described.rb — the same rules as lib/v3/parser.rb, but moved out of
# the purpose and into per-field `description:`s in the output schema (squishling's
# documented best practice: the guidance sits next to the value it explains, and
# the purpose stays short and about the goal). Run with bin/run_v3_described.
require "squishling"
require_relative "../clinical_record"

module V3
  class ParserDescribed
    include Squishling

    squishling params: { temperature: 0.1 }

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
