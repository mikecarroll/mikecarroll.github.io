# lib/rescue/data_normalizer.rb — "the upstream shape changed" rescue test.
#
# The Ruby below was written for a caller that sends { data: "this is the data" }.
# Then the caller changes and sends something else (a bare String, JSON, a
# string-keyed Hash, ...). The Ruby raises; `squish!` hands that one call to the
# LLM with the error as context.
#
# Two otherwise-identical classes:
#   DataNormalizer          — append_to_purpose "...", self   (the LLM sees this source)
#   DataNormalizerNoSource  — no source appended              (the LLM sees only purpose + schema)
require "squishling"

module Rescue
  class DataNormalizer
    include Squishling

    purpose "Return the record's data field as a string."
    append_to_purpose "The Ruby that handles the shape this caller used to send, for context on the intent:", self

    output_schema do
      string :data
    end

    def call(payload)
      result(data: payload.fetch(:data).to_s.strip)
    rescue => e
      squish!(context: { error: e })
    end
  end

  class DataNormalizerNoSource
    include Squishling

    purpose "Return the record's data field as a string."

    output_schema do
      string :data
    end

    def call(payload)
      result(data: payload.fetch(:data).to_s.strip)
    rescue => e
      squish!(context: { error: e })
    end
  end
end
