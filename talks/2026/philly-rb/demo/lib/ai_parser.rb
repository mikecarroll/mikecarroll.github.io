# lib/ai_parser.rb — slide 19's "entire AI parser in a dozen lines of Ruby."
# Same dozen lines regardless of whether `data` is FHIR JSON, an HL7 v2
# message, or whatever the next client happens to send.
require "ruby_llm"
require "json"
require_relative "patient_schema"

CHEAP_MINI_MODEL = "claude-haiku-4-5-20251001"

def ai_parser(client_name, data)
  response = RubyLLM
    .chat(model: CHEAP_MINI_MODEL)
    .with_temperature(0.1)
    .with_instructions(<<~PROMPT)
      You are a data engineer. Map the inbound record to our internal patient
      schema and return ONLY valid JSON in that format. Use null for anything
      you can't find.

      Internal patient schema:
      #{PatientSchema::DESCRIPTION}
    PROMPT
    .ask(data)

  JSON.parse(response.content)
end
