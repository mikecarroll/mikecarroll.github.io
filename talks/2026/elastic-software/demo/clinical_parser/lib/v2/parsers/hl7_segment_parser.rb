# Client format: HL7 v2.3 — PID for name/gender, one DG1 per diagnosis,
# one OBX per symptom (abusing OBX-5 as free-text, which real HL7 shops do
# constantly for anything that doesn't have a cleaner segment). Real
# messages also carry EVN/NK1/PV1/IN1 and this client's own Z-segment —
# finding PID/DG1/OBX by tag means the rest is free to be ignored.
require_relative "../base_parser"
require_relative "../../normalizers"

module V2
  module Parsers
    class Hl7SegmentParser < BaseParser
      def self.handles?(raw)
        raw.is_a?(String) && raw.lstrip.start_with?("MSH|")
      end

      def parse
        segments = @raw.split(/\r\n|\r|\n/).map { |line| line.split("|") }

        pid = segments.find { |s| s.first == "PID" }
        dg1s = segments.select { |s| s.first == "DG1" }
        obxs = segments.select { |s| s.first == "OBX" }

        last, first = pid[5].split("^")

        ClinicalRecord.new(
          # HL7 names conventionally arrive upper-case on the wire; the
          # internal schema wants a proper-cased name, not a transcription
          # of this format's own convention.
          patient_name: "#{first.capitalize} #{last.capitalize}",
          patient_gender: Normalizers.translate_gender(pid[8]),
          diagnosis_codes: dg1s.map { |seg| seg[3].split("^").first },
          symptoms: obxs.map { |seg| seg[5] }
        )
      end
    end
  end
end
