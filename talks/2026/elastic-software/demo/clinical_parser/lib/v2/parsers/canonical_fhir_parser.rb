# The original v1 shape doesn't disappear in v2 — it becomes one branch
# among four, delegating straight back to V1::Parser's own logic.
require_relative "../base_parser"
require_relative "../../v1/parser"

module V2
  module Parsers
    class CanonicalFhirParser < BaseParser
      def self.handles?(raw)
        safe_json(raw) do |data|
          data.is_a?(Hash) && data["resourceType"] == "Bundle" && data["entry"].is_a?(Array) &&
            data["entry"].any? { |e| e.dig("resource", "resourceType") == "Patient" }
        end
      end

      def parse
        V1::Parser.new(@raw).parse
      end
    end
  end
end
