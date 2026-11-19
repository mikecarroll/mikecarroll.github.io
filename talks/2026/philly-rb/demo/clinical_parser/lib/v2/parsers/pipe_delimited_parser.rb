# Client format: a legacy flat-file export — a pipe-delimited header line
# followed by one pipe-delimited data line. Column order carries a dozen
# fields (facility, MRN, admit/discharge dates, billing code, insurance,
# ward, attending) this parser never asked for; it locates what it needs
# by header name and ignores the rest.
require_relative "../base_parser"
require_relative "../../normalizers"

module V2
  module Parsers
    class PipeDelimitedParser < BaseParser
      REQUIRED_COLUMNS = %w[PATIENT_NAME GENDER DIAGNOSIS_CODES SYMPTOMS].freeze

      def self.handles?(raw)
        return false unless raw.is_a?(String)

        lines = raw.strip.split(/\r\n|\r|\n/)
        return false if lines.size < 2

        headers = lines.first.split("|")
        REQUIRED_COLUMNS.all? { |c| headers.include?(c) }
      end

      def parse
        lines = @raw.strip.split(/\r\n|\r|\n/)
        headers = lines.first.split("|")
        values = lines[1].split("|", -1)
        row = headers.zip(values).to_h

        ClinicalRecord.new(
          patient_name: row.fetch("PATIENT_NAME"),
          patient_gender: Normalizers.translate_gender(row.fetch("GENDER")),
          diagnosis_codes: Normalizers.split_list(row.fetch("DIAGNOSIS_CODES"), on: ","),
          symptoms: Normalizers.split_list(row.fetch("SYMPTOMS"), on: ",")
        )
      end
    end
  end
end
