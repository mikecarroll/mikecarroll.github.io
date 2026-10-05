# lib/v2/base_parser.rb — every format parser under lib/v2/parsers/ is a
# subclass of this. `.handles?` sniffs the raw record (JSON parses can fail,
# shapes can collide) and must never raise; `#parse` does the real work and
# is only ever called once `.handles?` has already said yes.
require "json"
require_relative "../clinical_record"

module V2
  class BaseParser
    def self.handles?(_raw)
      raise NotImplementedError, "#{name} must implement .handles?"
    end

    def initialize(raw)
      @raw = raw
    end

    def parse
      raise NotImplementedError, "#{self.class.name} must implement #parse"
    end

    # Shared by every JSON-shaped subclass's `.handles?` — parse once,
    # yield the result, and quietly say "not a match" on any failure
    # (malformed JSON, wrong top-level type, missing key) rather than
    # letting detection itself blow up.
    def self.safe_json(raw)
      yield JSON.parse(raw)
    rescue JSON::ParserError, TypeError, NoMethodError, KeyError
      false
    end
  end
end
