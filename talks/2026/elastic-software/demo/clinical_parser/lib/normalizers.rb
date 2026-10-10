# lib/normalizers.rb — small shared helpers so the four format parsers
# don't each reinvent "split this string into a list," or gender translation.
module Normalizers
  # ClinicalRecord#patient_gender only ever holds one of four values:
  #   "male" / "female" / "trans"  — an asserted identity
  #   "unknown"                    — the source didn't assert one at all
  # v1 was only ever built to recognize the literal words "male"/"female"/
  # "trans" (see V1::Parser::GENDER_VOCABULARY) and rejects anything else.
  # v2 has to translate real-world source values into that same four-value
  # schema, because inbound gender data does not arrive as a tidy three-word
  # vocabulary. The keys below are real codes from three systems a FHIR- or
  # HL7-adjacent feed actually uses:
  #
  #   FHIR administrative gender (Patient.gender — http://hl7.org/fhir/administrative-gender)
  #     male | female | other | unknown
  #
  #   HL7 v2 Table 0001 — Administrative Sex
  #     M | F | O (other) | U (unknown) | A (ambiguous) | N (not applicable)
  #   Notably, table 0001 has no code that asserts a transgender identity —
  #   it's a 1980s-era standard with no room for one, not a gap in this
  #   parser. See PROVENANCE.md.
  #
  #   HL7's Gender Harmony gender-identity value set (SNOMED CT, as used by
  #   the US Core us-core-genderIdentity extension)
  #     446151000124109 Identifies as male gender
  #     446141000124107 Identifies as female gender
  #     407377005       Female-to-male transsexual
  #     407376001       Male-to-female transsexual
  #     446131000124102 Identifies as non-conforming gender
  #
  # "other"/"ambiguous"/"not applicable"/NullFlavor codes assert *that* a
  # value wasn't captured, not *that* someone is trans — so they translate
  # to "unknown", not "trans". Only a source value that actually asserts a
  # trans or gender-nonconforming identity earns "trans".
  GENDER_TRANSLATIONS = {
    # words
    "male" => "male", "female" => "female", "trans" => "trans",
    # FHIR administrative gender
    "other" => "unknown", "unknown" => "unknown",
    # HL7 v2 Table 0001 — Administrative Sex
    "m" => "male", "f" => "female", "o" => "unknown", "u" => "unknown",
    "a" => "unknown", "n" => "unknown",
    # Gender Harmony / US Core genderIdentity (SNOMED CT)
    "446151000124109" => "male", "446141000124107" => "female",
    "407377005" => "trans", "407376001" => "trans", "446131000124102" => "trans",
    # NullFlavor, as used by several HL7/CDA-adjacent extensions
    "oth" => "unknown", "unk" => "unknown", "asku" => "unknown",
    # free-text labels a legacy flat-file export might use
    "nonbinary" => "trans", "non-binary" => "trans", "transgender" => "trans",
  }.freeze

  def self.translate_gender(value)
    GENDER_TRANSLATIONS.fetch(value.to_s.strip.downcase, "unknown")
  end

  # Splits a delimiter-joined string ("cough, wheezing" / "J45.909,I10")
  # into a clean array; already-an-array value passes through untouched.
  def self.split_list(value, on: /[,;|]/)
    return [] if value.nil?
    return value.map { |v| v.to_s.strip } if value.is_a?(Array)

    value.to_s.split(on).map(&:strip).reject(&:empty?)
  end
end
