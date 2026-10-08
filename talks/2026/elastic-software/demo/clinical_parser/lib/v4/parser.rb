# lib/v4/parser.rb — the hybrid: a real, deterministic FHIR Bundle parser
# (the same logic as v1), escalating to the LLM with `squish!` from two
# distinct rescues when Ruby can't handle what it got:
#
#   1. the input isn't a FHIR Bundle this parser can read at all — wrong
#      shape, not just wrong values (not JSON, no "entry", no Patient
#      resource);
#   2. it *is* a well-formed Bundle, but a required field came back
#      nil/empty — parsed fine, just incomplete.
#
# Harden the common case, squish the rest — the whole talk's thesis, as one
# class. `squish!`/`append_instructions` are from squishling PR #3
# (https://github.com/Coolhand-Labs/squishling/pull/3), not yet merged to
# main — see this exercise's Gemfile.
require "squishling"
require_relative "../clinical_record"

module V4
  class Parser
    include Squishling

    class MissingFieldError < StandardError; end

    instructions <<~INSTRUCTIONS
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
          all: it's missing, or an administrative "other" / "unknown" /
          "ambiguous" / "not applicable" code (including bare letter codes,
          e.g. HL7's O / U / A / N), or any gender code you don't recognize
          and have no label for. When in doubt, "unknown" — never guess
          "male" or "female" from an unfamiliar or absent value.

      Symptoms: only include one if the record reports it as a symptom
      explicitly — a dedicated symptom/observation entry, or a labeled
      "symptoms" field. A diagnosis is not a symptom; never infer symptoms
      from diagnosis or condition names. If the record reports none, return
      an empty array.
    INSTRUCTIONS

    append_instructions "The Ruby that parses a well-formed FHIR Bundle, for context on the shape and intent:",
      self

    squishling params: { temperature: 0.1 }

    output_schema do
      string :patient_name
      string :patient_gender, enum: %w[male female trans unknown]
      array :diagnosis_codes, of: :string
      array :symptoms, of: :string
    end

    def call(record:)
      data = JSON.parse(record)
      raise TypeError, "not a FHIR Bundle" unless data["resourceType"] == "Bundle" && data["entry"].is_a?(Array)

      entries = data["entry"].filter_map { |e| e["resource"] }
      patient = entries.find { |r| r["resourceType"] == "Patient" }
      raise TypeError, "no Patient resource in bundle" unless patient

      conditions = entries.select { |r| r["resourceType"] == "Condition" }
      symptoms = entries.select { |r| r["resourceType"] == "Observation" && r.dig("code", "text") == "symptom" }

      name_entry = patient["name"]&.find { |n| n["use"] == "official" } || patient["name"]&.first
      full_name = name_entry && ([*name_entry["given"]] + [name_entry["family"]]).compact.join(" ")
      gender = patient["gender"]
      diagnosis_codes = conditions.map { |c| c.dig("code", "coding", 0, "code") }
      symptom_texts = symptoms.map { |s| s["valueString"] }

      missing = []
      missing << "patient_name" if full_name.nil? || full_name.strip.empty?
      missing << "patient_gender" if gender.nil?
      missing << "diagnosis_codes" if diagnosis_codes.empty? || diagnosis_codes.any?(&:nil?)
      raise MissingFieldError, "required field(s) came back empty: #{missing.join(', ')}" if missing.any?

      result(
        patient_name: full_name,
        patient_gender: gender,
        diagnosis_codes: diagnosis_codes,
        symptoms: symptom_texts
      )
    rescue JSON::ParserError, TypeError => e
      # Rescue 1: not a FHIR Bundle this parser can read at all.
      squish!(
        context: { parse_error: e },
        append_instructions: "The Ruby parser above couldn't read this input as a FHIR Bundle at all — " \
                             "the error is in the context. It's some other format entirely; map it the same way."
      )
    rescue MissingFieldError => e
      # Rescue 2: it *was* a FHIR Bundle, but a required field came back
      # empty — read the whole record yourself rather than trust a partial
      # Ruby extraction.
      squish!(
        context: { parse_error: e },
        append_instructions: "The Ruby parser above recognized this as a FHIR Bundle but found at least one " \
                             "required field empty — the error is in the context."
      )
    end

    # Adapts the result (deterministic or squished — both are the same typed
    # class) onto this repo's own ClinicalRecord, so v4 drops into the same
    # bin/run_v1 / bin/run_v2 / bin/run_v3 harness and manifest.
    def self.parse(raw)
      parsed = call(record: raw)
      ClinicalRecord.new(
        patient_name: parsed.patient_name,
        patient_gender: parsed.patient_gender,
        diagnosis_codes: parsed.diagnosis_codes,
        symptoms: parsed.symptoms
      )
    end
  end
end
