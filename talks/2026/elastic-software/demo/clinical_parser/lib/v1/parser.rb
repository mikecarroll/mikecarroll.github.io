# lib/v1/parser.rb — the "day one, it is beautiful" parser (slide 5). It
# knows exactly one wire format: a FHIR Bundle carrying one Patient, one or
# more Condition entries, and (since Synthea doesn't model symptoms as
# their own resource) a small "symptom" Observation per reported symptom.
#
# Every one of the 63 canonical-FHIR fixtures is a real Synthea-generated Patient and
# real Condition entries — full of genuine FHIR noise (extensions,
# identifiers, clinicalStatus, encounter references, meta tags) — plus a
# few unrelated resource entries (Immunization, Procedure, Encounter) that
# just happen to be sitting in the same bundle. v1 finds its four fields by
# resourceType and ignores everything else in the entry; what it can't
# survive is a bundle shaped any differently than this.
require "json"
require_relative "../clinical_record"

module V1
  class UnrecognizedFormatError < StandardError; end

  class Parser
    # v1's entire gender vocabulary. Real FHIR/HL7 feeds carry other values
    # — "other", "unknown", HL7 v2's O/U/A/N, SNOMED gender-identity codes —
    # but v1 was built before anyone thought to ask, so anything not in
    # this exact set of three literal words is unrecognized, same as a
    # wrong-shaped record. See lib/normalizers.rb for the version of this
    # that v2 actually needs.
    GENDER_VOCABULARY = %w[male female trans].freeze

    def initialize(raw)
      @raw = raw
    end

    def parse
      data = JSON.parse(@raw)
      entries = data.fetch("entry").map { |e| e.fetch("resource") }

      patient = entries.find { |r| r["resourceType"] == "Patient" }
      conditions = entries.select { |r| r["resourceType"] == "Condition" }
      symptoms = entries.select { |r| r["resourceType"] == "Observation" && r.dig("code", "text") == "symptom" }

      name = patient.fetch("name").find { |n| n["use"] == "official" } || patient.fetch("name").first
      full_name = ([*name.fetch("given")] + [name.fetch("family")]).join(" ")
      gender = patient.fetch("gender")
      raise UnrecognizedFormatError, "v1 doesn't recognize gender #{gender.inspect}" unless GENDER_VOCABULARY.include?(gender)

      ClinicalRecord.new(
        patient_name: full_name,
        patient_gender: gender,
        diagnosis_codes: conditions.map { |c| c.dig("code", "coding", 0, "code") },
        symptoms: symptoms.map { |s| s.fetch("valueString") }
      )
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError => e
      raise UnrecognizedFormatError, "v1 only understands a Patient+Condition FHIR Bundle: #{e.message}"
    end
  end
end
