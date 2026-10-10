# lib/v3/parser_first_pass.rb — v3 before the Name/Gender/Symptoms
# refinement in lib/v3/parser.rb: the purpose this class shipped with for
# the "first real run against all 35: 23 pass" result in the deck's slide 19
# notes and the top-level README's "What actually happened running this for
# real" step 1. Preserved as its own class, rather than as a stashed diff,
# so that number stays a real, re-runnable run (see bin/run_v3_first_pass)
# instead of a remembered one once lib/v3/parser.rb moved on to the refined
# purpose. No `squishling params:` override either — that was added in step
# 2, after this purpose, and didn't change the pass count on its own.
require "squishling"
require_relative "../clinical_record"

module V3
  class ParserFirstPass
    include Squishling

    purpose <<~PURPOSE
      Map the inbound clinical record — in whatever format it arrives — onto
      the schema below. Ignore every field that isn't the patient's name,
      their gender, their diagnosis codes, or their symptoms.
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
