# lib/v2/dispatcher.rb — "the steps elastic software deletes" for the
# hand-written path: v1 hard-coded one shape; v2 detects which of four
# known shapes it got, and delegates to the class built for that shape.
# Adding a fifth format means adding a class here, not touching the other
# four — that's the whole point of the inheritance.
require_relative "base_parser"
require_relative "parsers/canonical_fhir_parser"
require_relative "parsers/fhir_variant_parser"
require_relative "parsers/hl7_segment_parser"
require_relative "parsers/pipe_delimited_parser"

module V2
  class UnrecognizedFormatError < StandardError; end

  class Dispatcher
    FORMATS = [
      Parsers::CanonicalFhirParser,
      Parsers::FhirVariantParser,
      Parsers::Hl7SegmentParser,
      Parsers::PipeDelimitedParser,
    ].freeze

    def self.parse(raw)
      parser_class = FORMATS.find { |klass| klass.handles?(raw) }
      raise UnrecognizedFormatError, "none of #{FORMATS.size} known formats recognize this record" unless parser_class

      parser_class.new(raw).parse
    end
  end
end
