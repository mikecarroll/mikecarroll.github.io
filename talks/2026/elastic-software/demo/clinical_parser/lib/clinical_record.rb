# lib/clinical_record.rb — the normalized shape every format below is
# mapped onto: patient name, patient gender, diagnosis code(s), symptoms.
#
# patient_gender is one of exactly four values: "male", "female", "trans"
# (an asserted identity), or "unknown" (the source didn't assert one at
# all). See lib/normalizers.rb for how real-world source values — FHIR
# administrative gender, HL7 v2 Table 0001, SNOMED gender-identity codes —
# get translated into these four.
ClinicalRecord = Struct.new(
  :patient_name, :patient_gender, :diagnosis_codes, :symptoms,
  keyword_init: true
) do
  def to_h
    {
      "patient_name" => patient_name,
      "patient_gender" => patient_gender,
      "diagnosis_codes" => diagnosis_codes,
      "symptoms" => symptoms,
    }
  end

  # Order-independent equality — a record is the same record regardless of
  # what order a format happened to list its diagnoses or symptoms in.
  def matches?(expected)
    patient_name == expected["patient_name"] &&
      patient_gender == expected["patient_gender"] &&
      diagnosis_codes.sort == expected["diagnosis_codes"].sort &&
      symptoms.sort == expected["symptoms"].sort
  end
end
