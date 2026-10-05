#!/usr/bin/env ruby
# frozen_string_literal: true

# tools/generate_fixtures.rb — the single source of truth for all 35
# fixtures. Patient demographics and diagnoses are *real* — extracted from
# actual Synthea-generated FHIR bundles (see synthea_source.json and its
# own PROVENANCE note) — only the symptom values, the gender-source
# override for the 15 v2 records (below), and the surrounding "noise"
# fields in each format are this script's own invention. Fixtures are
# static, committed files — this script is only ever re-run by hand if the
# fixture set itself changes.
require "json"
require_relative "../lib/normalizers"

root = File.expand_path("..", __dir__)
patients = JSON.parse(File.read(File.join(root, "tools", "synthea_source.json")))

raise "expected 35 patients, got #{patients.size}" unless patients.size == 35

# Real Synthea patients are only ever "male"/"female" — v1's 20 canonical
# fixtures stay exactly that (see lib/v1/parser.rb's own tiny 3-word
# vocabulary). The 15 v2-only fixtures (indices 20-34) instead each get a
# real-world gender/sex source value v1 was never built to recognize, in
# whatever representation that record's own format would plausibly use —
# see lib/normalizers.rb::GENDER_TRANSLATIONS for what every one of these
# actually means.
GENDER_SOURCE_OVERRIDE = {
  # fhir_variant (021-025): FHIR administrative gender words + Gender
  # Harmony SNOMED CT gender-identity codes.
  20 => "female",
  21 => "other",
  22 => "unknown",
  23 => "407377005",       # Female-to-male transsexual
  24 => "446131000124102", # Identifies as non-conforming gender
  # hl7 (026-030): HL7 v2 Table 0001 — Administrative Sex letter codes.
  25 => "F",
  26 => "M",
  27 => "O", # other
  28 => "U", # unknown
  29 => "A", # ambiguous
  # pipe_delimited (031-035): free-text labels, as a legacy flat file would use.
  30 => "Female",
  31 => "Male",
  32 => "Nonbinary",
  33 => "Transgender",
  34 => "Unknown",
}.freeze

SYMPTOMS = [
  "cough", "wheezing", "fever", "fatigue", "headache", "nausea", "dizziness",
  "shortness of breath", "sore throat", "chest pain", "joint pain", "rash",
  "chills", "congestion", "insomnia", "abdominal pain", "dry mouth",
  "blurred vision", "palpitations", "night sweats",
].freeze

def symptoms_for(index)
  count = [0, 1, 2, 3, 4][index % 5]
  SYMPTOMS.rotate(index * 3).first(count)
end

def full_name(patient)
  name = patient.fetch("name").find { |n| n["use"] == "official" } || patient.fetch("name").first
  ([*name.fetch("given")] + [name.fetch("family")]).join(" ")
end

# --- format renderers ----------------------------------------------------

def render_canonical_fhir(patient, conditions, noise_resources, symptoms)
  symptom_entries = symptoms.each_with_index.map do |symptom, i|
    {
      "resource" => {
        "resourceType" => "Observation",
        "id" => "symptom-#{i + 1}-#{patient['id']}",
        "status" => "final",
        "category" => [{ "coding" => [{ "system" => "http://terminology.hl7.org/CodeSystem/observation-category", "code" => "symptom" }] }],
        "code" => { "text" => "symptom" },
        "subject" => { "reference" => "urn:uuid:#{patient['id']}" },
        "effectiveDateTime" => "2026-01-15T09:00:00+00:00",
        "valueString" => symptom,
      },
    }
  end

  bundle = {
    "resourceType" => "Bundle",
    "type" => "collection",
    "entry" => [
      { "resource" => patient },
      *conditions.map { |c| { "resource" => c } },
      *noise_resources.map { |r| { "resource" => r } },
      *symptom_entries,
    ],
  }
  JSON.pretty_generate(bundle)
end

def render_fhir_variant(patient, conditions, symptoms, gender_source)
  doc = {
    "fhirVersion" => "R4",
    "exportedAt" => "2026-01-15T09:00:00Z",
    "sourceSystem" => "MedVantage-EHR",
    "subject" => {
      "resourceType" => "Patient",
      "fullName" => full_name(patient),
      "birthSex" => gender_source,
      "mrn" => "MV-#{patient['id'][0, 8]}",
      "facility" => "Lakeside Regional",
    },
    "diagnosisList" => conditions.map { |c|
      coding = c.dig("code", "coding", 0) || {}
      { "codeSystem" => "SNOMED-CT", "codeValue" => coding["code"], "label" => coding["display"], "recordedBy" => "Dr. A. Whitfield" }
    },
    "symptomList" => symptoms.each_with_index.map { |s, i|
      { "description" => s, "reportedAt" => "2026-01-15T09:0#{i}:00Z", "severity" => %w[mild moderate severe][i % 3] }
    },
    "billing" => { "payerId" => "PAYER-4471", "priorAuth" => false, "copayCents" => 2500 },
    "insurance" => { "planName" => "Lakeside PPO Gold", "groupNumber" => "GRP-8842", "memberSince" => "2019-03-01" },
  }
  JSON.pretty_generate(doc)
end

def render_hl7(patient, conditions, symptoms, gender_source)
  name = patient.fetch("name").find { |n| n["use"] == "official" } || patient.fetch("name").first
  first = name.fetch("given").first.upcase
  last = name.fetch("family").upcase
  mrn = patient["id"][0, 8].upcase
  msg_id = "MSG#{patient['id'][0, 6].upcase}"

  lines = []
  lines << "MSH|^~\\&|EHR|LAKESIDE_REGIONAL|COOLHAND|DEMO|20260115090000||ADT^A01|#{msg_id}|P|2.3"
  lines << "EVN|A01|20260115090000"
  lines << "PID|1||#{mrn}^^^LAKESIDE^MR||#{last}^#{first}|||#{gender_source}||||123 MAIN ST^^SPRINGFIELD^MA^01101^US||(555)010-#{patient['id'][0, 4]}"
  lines << "NK1|1|#{last}^JORDAN|SPOUSE|123 MAIN ST^^SPRINGFIELD^MA^01101^US"
  lines << "PV1|1|O|LAKESIDE^CLINIC^3||||5521^WHITFIELD^A^^^DR|||||||||||||#{mrn}"
  lines << "IN1|1|GRP-8842|PAYER-4471|Lakeside PPO Gold||||||||||||#{last}^#{first}"
  conditions.each_with_index do |c, i|
    coding = c.dig("code", "coding", 0) || {}
    lines << "DG1|#{i + 1}||#{coding['code']}^#{coding['display']}^SNOMED"
  end
  symptoms.each_with_index { |s, i| lines << "OBX|#{i + 1}|ST|SYM^Symptom^L||#{s}" }
  lines << "ZPI|LAKESIDE_REGIONAL|EPIC-COMPAT-9.2"

  lines.join("\n") + "\n"
end

def render_pipe_delimited(patient, conditions, symptoms, gender_source)
  headers = %w[
    RECORD_TYPE FACILITY_ID MRN PATIENT_NAME DOB GENDER ADMIT_DATE DISCHARGE_DATE
    DIAGNOSIS_CODES SYMPTOMS BILLING_CODE INSURANCE_ID WARD ATTENDING_PROVIDER
  ]
  values = [
    "ENC", "FAC-004", patient["id"][0, 8].upcase, full_name(patient),
    "1900-01-01", gender_source, "2026-01-15", "2026-01-16",
    conditions.map { |c| c.dig("code", "coding", 0, "code") }.join(","),
    symptoms.join(","),
    "BILL-#{patient['id'][0, 5].upcase}", "INS-4471", "WARD-B", "Dr. A. Whitfield",
  ]
  "#{headers.join('|')}\n#{values.join('|')}\n"
end

# --- assign each patient a format, render, and record the expected result

FORMAT_FOR_INDEX = ->(i) {
  case i
  when 0..19 then "canonical_fhir"
  when 20..24 then "fhir_variant"
  when 25..29 then "hl7"
  else "pipe_delimited"
  end
}

EXTENSIONS = { "canonical_fhir" => "json", "fhir_variant" => "json", "hl7" => "hl7", "pipe_delimited" => "txt" }.freeze

fixtures_dir = File.join(root, "fixtures")
manifest = []

patients.each_with_index do |entry, index|
  patient = entry.fetch("patient")
  conditions = entry.fetch("conditions")
  noise_resources = entry.fetch("noise_resources")
  symptoms = symptoms_for(index)
  fmt = FORMAT_FOR_INDEX.call(index)
  gender_source = GENDER_SOURCE_OVERRIDE.fetch(index, patient.fetch("gender"))

  raw =
    case fmt
    when "canonical_fhir" then render_canonical_fhir(patient, conditions, noise_resources, symptoms)
    when "fhir_variant" then render_fhir_variant(patient, conditions, symptoms, gender_source)
    when "hl7" then render_hl7(patient, conditions, symptoms, gender_source)
    when "pipe_delimited" then render_pipe_delimited(patient, conditions, symptoms, gender_source)
    end

  filename = "#{format('%03d', index + 1)}_#{fmt}.#{EXTENSIONS.fetch(fmt)}"
  File.write(File.join(fixtures_dir, filename), raw)

  # v1's 20 canonical fixtures pass through their real "male"/"female"
  # value untranslated; the 15 v2-only fixtures' expected gender is
  # whatever GENDER_SOURCE_OVERRIDE actually translates to — computed with
  # the same lib/normalizers.rb table the parsers themselves use, so the
  # manifest can't silently drift from what v2 is supposed to produce.
  expected_gender = fmt == "canonical_fhir" ? patient.fetch("gender") : Normalizers.translate_gender(gender_source)

  manifest << {
    "file" => filename,
    "format" => fmt,
    "source_file" => entry.fetch("source_file"),
    "expected" => {
      "patient_name" => full_name(patient),
      "patient_gender" => expected_gender,
      "diagnosis_codes" => conditions.map { |c| c.dig("code", "coding", 0, "code") },
      "symptoms" => symptoms,
    },
  }
end

File.write(File.join(fixtures_dir, "manifest.json"), JSON.pretty_generate(manifest))
puts "Wrote #{manifest.size} fixtures + manifest.json to #{fixtures_dir}"
