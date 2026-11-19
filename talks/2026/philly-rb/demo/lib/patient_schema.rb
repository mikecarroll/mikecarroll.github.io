# lib/patient_schema.rb — the internal patient schema every inbound record,
# regardless of the wire format it arrives in, gets mapped onto (slide 19).
module PatientSchema
  DESCRIPTION = <<~SCHEMA
    {
      "first_name": string,
      "last_name": string,
      "date_of_birth": "YYYY-MM-DD",
      "gender": "male" | "female" | "other" | null,
      "address": {
        "line1": string,
        "city": string,
        "state": string,
        "postal_code": string,
        "country": string
      } | null,
      "phone": string | null,
      "external_id": string | null,
      "ssn": string | null
    }
  SCHEMA
end
