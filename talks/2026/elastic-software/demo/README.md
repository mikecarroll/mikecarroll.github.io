# Elastic Software — demo code

Runnable version of the parser from slides 18/19/22 of "Elastic Software:
Calculating tech debt using LLM tokens" (XO Ruby Toronto 2026), plus the two
fixtures for slide 29's live demo.

## What this is

- `lib/patient_schema.rb` — the internal patient schema every inbound record
  gets mapped onto.
- `lib/ai_parser.rb` — slide 19's "entire AI parser in a dozen lines of Ruby,"
  using the [RubyLLM](https://rubyllm.com) gem.
- `lib/call_parser.rb` — slide 18/22's caller. `CLIENT_PARSERS` starts empty;
  add a hand-written parser per client only once its volume earns it
  (slide 24's threshold).
- `fixtures/` — two inbound records for the *same* synthetic patient in two
  different formats: a FHIR `Patient` resource and an HL7 v2.3 `ADT^A01`
  message with no SSN field. See `fixtures/PROVENANCE.md` for where each
  came from.
- `bin/demo` — runs both fixtures through `call_parser` and prints the
  normalized JSON for each, mirroring slide 29.

## Run it

```bash
bundle install
cp .env.example .env && edit .env    # set ANTHROPIC_API_KEY
export $(cat .env | xargs)
bin/demo
```

## Notes

- `CHEAP_MINI_MODEL` in `lib/ai_parser.rb` is set to `claude-haiku-4-5-20251001`
  — swap it for whatever "cheap mini model" you want to demo with.
- The HL7 fixture's missing SSN field should map to `"ssn": null` — that's
  the null-handling behavior the demo's speaker notes call out.
- This is demo/talk code, not the hardened-parser path — there's no error
  handling for a non-JSON or malformed model response, matching the
  deliberately minimal "dozen lines" of slide 19.
