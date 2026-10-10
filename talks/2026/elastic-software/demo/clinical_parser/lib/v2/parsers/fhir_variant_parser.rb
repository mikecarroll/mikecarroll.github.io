# Client format: still nominally "FHIR" by name (this vendor calls its
# export "fhirVersion": "R4"), but its own field names throughout —
# "subject"/"birthSex" instead of a Patient resource with "gender",
# "diagnosisList"/"codeValue" instead of Condition.code.coding, plain
# description strings for symptoms instead of an Observation per one.
require_relative "../base_parser"
require_relative "../../normalizers"

module V2
  module Parsers
    class FhirVariantParser < BaseParser
      def self.handles?(raw)
        safe_json(raw) do |data|
          data.is_a?(Hash) && data["subject"].is_a?(Hash) && data["subject"].key?("fullName") &&
            data.key?("diagnosisList") && data.key?("symptomList")
        end
      end

      def parse
        data = JSON.parse(@raw)
        subject = data.fetch("subject")

        ClinicalRecord.new(
          patient_name: subject.fetch("fullName"),
          patient_gender: Normalizers.translate_gender(subject.fetch("birthSex")),
          diagnosis_codes: data.fetch("diagnosisList").map { |d| d.fetch("codeValue") },
          symptoms: data.fetch("symptomList").map { |s| s.fetch("description") }
        )
      end
    end
  end
end
