# lib/call_parser.rb — slide 18/22's caller. CLIENT_PARSERS starts empty:
# every client rides the flexible AI layer until its volume earns it a
# hardened parser (slide 22's "contract toward efficiency").
require_relative "ai_parser"

CLIENT_PARSERS = {
  # "acme_health" => method(:acme_health_parser),  # earned it at slide 24's threshold
}.freeze

def call_parser(client_name, data)
  parser = CLIENT_PARSERS[client_name]
  parser ? parser.call(data) : ai_parser(client_name, data)
end
