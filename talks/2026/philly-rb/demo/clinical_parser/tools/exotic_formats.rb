# frozen_string_literal: true

# tools/exotic_formats.rb — renderers for the 22 "go crazy" fixtures
# (079–100). Same real Synthea patient identity + diagnoses as every other
# fixture; each renderer buries the four fields that matter (name, gender,
# diagnosis codes, symptoms) in a format v1/v2 were never built for, under
# a pile of invented-but-plausible noise. Every value that isn't the
# patient's real name/DOB/address/phone or a real diagnosis is made up.
#
# Required by tools/generate_fixtures.rb; nothing here ships with the demo.
require "base64"
require "cgi"
require "json"
require "yaml"

module ExoticFormats
  Ctx = Struct.new(
    :index, :name, :first, :last, :gender_source, :dob, :mrn, :street, :city,
    :state, :zip, :phone, :dx, :symptoms, :patient_id, :facility, :provider,
    keyword_init: true
  )

  FACILITIES = [
    "Lakeside Regional", "St. Brigid Medical Center", "Harborview Community Hospital",
    "Northfield Family Clinic", "Cedar Ridge Health", "Mercy Valley Urgent Care",
  ].freeze
  PROVIDERS = ["A. Whitfield", "R. Okafor", "L. Ferreira", "S. Nakamura", "D. Castellanos", "P. Lindqvist"].freeze
  MEDS = [
    ["lisinopril 10 MG Oral Tablet", "314076"], ["Metformin hydrochloride 500 MG Oral Tablet", "861007"],
    ["atorvastatin 20 MG Oral Tablet", "617310"], ["Acetaminophen 325 MG Oral Tablet", "313782"],
    ["Ibuprofen 200 MG Oral Tablet", "197806"],
  ].freeze
  NOISE_TEXT = [
    "Patient verbalized understanding of discharge instructions.",
    "Interpreter not required. Preferred language: English.",
    "Allergies reviewed with patient; NKDA on file as of last visit.",
    "Fall risk screen negative. PHQ-2 score 0.",
    "Advance directive status: not on file. Information offered.",
    "Parking validation stamped at front desk.",
    "Please bring your insurance card to every visit.",
  ].freeze

  module_function

  def esc(s) = CGI.escapeHTML(s.to_s)

  def meds_for(c) = MEDS.rotate(c.index).first(2 + (c.index % 2))

  def vitals_for(c)
    { "bp" => "#{110 + (c.index * 7) % 35}/#{66 + (c.index * 3) % 20}", "hr" => 58 + (c.index * 5) % 40,
      "temp_f" => (97.2 + (c.index % 14) / 10.0).round(1), "spo2" => 94 + c.index % 6,
      "weight_kg" => 52 + (c.index * 11) % 50, "height_cm" => 150 + (c.index * 3) % 40 }
  end

  def date_compact = "20260115"

  def symptom_phrase(c)
    c.symptoms.empty? ? "no presenting symptoms" : c.symptoms.join(", ")
  end

  # -- 1. C-CDA (HL7 CDA R2) -------------------------------------------------

  def cda_xml(c)
    problems = c.dx.each_with_index.map do |(code, display), i|
      <<~XML
        <entry typeCode="DRIV">
          <act classCode="ACT" moodCode="EVN">
            <templateId root="2.16.840.1.113883.10.20.22.4.3"/>
            <id root="#{c.patient_id}" extension="prob-#{i + 1}"/>
            <code code="CONC" codeSystem="2.16.840.1.113883.5.6"/>
            <statusCode code="active"/>
            <effectiveTime><low value="20100101"/></effectiveTime>
            <entryRelationship typeCode="SUBJ">
              <observation classCode="OBS" moodCode="EVN">
                <code code="64572001" codeSystem="2.16.840.1.113883.6.96" displayName="Condition"/>
                <statusCode code="completed"/>
                <value xsi:type="CD" code="#{code}" codeSystem="2.16.840.1.113883.6.96" codeSystemName="SNOMED CT" displayName="#{esc(display)}"/>
              </observation>
            </entryRelationship>
          </act>
        </entry>
      XML
    end.join
    hpi_items = c.symptoms.map { |s| "<item>#{esc(s)}</item>" }.join
    hpi_text = c.symptoms.empty? ? "<paragraph>No presenting symptoms reported.</paragraph>" : "<list listType=\"unordered\">#{hpi_items}</list>"
    hpi_entries = c.symptoms.each_with_index.map do |s, i|
      <<~XML
        <entry>
          <observation classCode="OBS" moodCode="EVN">
            <id root="#{c.patient_id}" extension="sym-#{i + 1}"/>
            <code code="418799008" codeSystem="2.16.840.1.113883.6.96" displayName="Symptom"/>
            <statusCode code="completed"/>
            <value xsi:type="ST">#{esc(s)}</value>
          </observation>
        </entry>
      XML
    end.join
    meds = meds_for(c).map { |m, rx| "<item>#{esc(m)} (RxNorm #{rx})</item>" }.join
    v = vitals_for(c)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <?xml-stylesheet type="text/xsl" href="CDA.xsl"?>
      <ClinicalDocument xmlns="urn:hl7-org:v3" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:sdtc="urn:hl7-org:sdtc">
        <realmCode code="US"/>
        <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
        <templateId root="2.16.840.1.113883.10.20.22.1.1" extension="2015-08-01"/>
        <id root="2.16.840.1.113883.19.5.99999.1" extension="CCD-#{c.mrn}"/>
        <code code="34133-9" codeSystem="2.16.840.1.113883.6.1" displayName="Summarization of Episode Note"/>
        <title>Continuity of Care Document — #{esc(c.facility)}</title>
        <effectiveTime value="20260115090000-0500"/>
        <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
        <languageCode code="en-US"/>
        <recordTarget>
          <patientRole>
            <id extension="#{c.mrn}" root="2.16.840.1.113883.19.5"/>
            <addr use="HP"><streetAddressLine>#{esc(c.street)}</streetAddressLine><city>#{esc(c.city)}</city><state>#{esc(c.state)}</state><postalCode>#{c.zip}</postalCode><country>US</country></addr>
            <telecom use="HP" value="tel:#{c.phone}"/>
            <patient>
              <name use="L"><given>#{esc(c.first)}</given><family>#{esc(c.last)}</family></name>
              <administrativeGenderCode code="#{c.gender_source}" codeSystem="2.16.840.1.113883.5.1"/>
              <birthTime value="#{c.dob.delete('-')}"/>
              <maritalStatusCode code="S" codeSystem="2.16.840.1.113883.5.2"/>
              <languageCommunication><languageCode code="en"/><preferenceInd value="true"/></languageCommunication>
            </patient>
          </patientRole>
        </recordTarget>
        <author>
          <time value="20260115090000-0500"/>
          <assignedAuthor><id root="2.16.840.1.113883.4.6" extension="1#{(c.index * 7919).to_s.rjust(9, '0')}"/>
            <assignedPerson><name><given>#{esc(c.provider.split('. ').first)}.</given><family>#{esc(c.provider.split('. ').last)}</family></name></assignedPerson>
          </assignedAuthor>
        </author>
        <custodian><assignedCustodian><representedCustodianOrganization><id root="2.16.840.1.113883.19.5"/><name>#{esc(c.facility)}</name></representedCustodianOrganization></assignedCustodian></custodian>
        <component>
          <structuredBody>
            <component>
              <section>
                <templateId root="2.16.840.1.113883.10.20.22.2.6.1"/>
                <code code="48765-2" codeSystem="2.16.840.1.113883.6.1" displayName="Allergies"/>
                <title>Allergies</title>
                <text>No known allergies.</text>
              </section>
            </component>
            <component>
              <section>
                <templateId root="2.16.840.1.113883.10.20.22.2.1.1"/>
                <code code="10160-0" codeSystem="2.16.840.1.113883.6.1" displayName="Medications"/>
                <title>Medications</title>
                <text><list>#{meds}</list></text>
              </section>
            </component>
            <component>
              <section>
                <templateId root="2.16.840.1.113883.10.20.22.2.4.1"/>
                <code code="8716-3" codeSystem="2.16.840.1.113883.6.1" displayName="Vital signs"/>
                <title>Vital Signs</title>
                <text><table><tbody><tr><td>BP</td><td>#{v['bp']}</td></tr><tr><td>HR</td><td>#{v['hr']}</td></tr><tr><td>Temp F</td><td>#{v['temp_f']}</td></tr><tr><td>SpO2</td><td>#{v['spo2']}%</td></tr></tbody></table></text>
              </section>
            </component>
            <component>
              <section>
                <templateId root="2.16.840.1.113883.10.20.22.2.5.1"/>
                <code code="11450-4" codeSystem="2.16.840.1.113883.6.1" displayName="Problem list"/>
                <title>Problems</title>
                <text>#{c.dx.map { |code, d| "#{esc(d)} (#{code})" }.join('; ')}</text>
      #{problems.lines.map { |l| "          #{l}" }.join}
              </section>
            </component>
            <component>
              <section>
                <templateId root="2.16.840.1.113883.10.20.22.2.13"/>
                <code code="10164-2" codeSystem="2.16.840.1.113883.6.1" displayName="History of Present Illness"/>
                <title>Presenting symptoms</title>
                <text>#{hpi_text}</text>
      #{hpi_entries.lines.map { |l| "          #{l}" }.join}
              </section>
            </component>
            <component>
              <section>
                <code code="29762-2" codeSystem="2.16.840.1.113883.6.1" displayName="Social history"/>
                <title>Social History</title>
                <text>#{esc(NOISE_TEXT[c.index % NOISE_TEXT.size])}</text>
              </section>
            </component>
          </structuredBody>
        </component>
      </ClinicalDocument>
    XML
  end

  # -- 2. FHIR XML Bundle ----------------------------------------------------

  def fhir_xml(c)
    conds = c.dx.each_with_index.map do |(code, display), i|
      <<~XML
        <entry>
          <fullUrl value="urn:uuid:cond-#{c.index}-#{i}"/>
          <resource>
            <Condition>
              <id value="cond-#{c.index}-#{i}"/>
              <clinicalStatus><coding><system value="http://terminology.hl7.org/CodeSystem/condition-clinical"/><code value="active"/></coding></clinicalStatus>
              <code><coding><system value="http://snomed.info/sct"/><code value="#{code}"/><display value="#{esc(display)}"/></coding><text value="#{esc(display)}"/></code>
              <subject><reference value="urn:uuid:#{c.patient_id}"/></subject>
              <onsetDateTime value="2010-01-01T00:00:00+00:00"/>
            </Condition>
          </resource>
        </entry>
      XML
    end.join
    obs = c.symptoms.each_with_index.map do |s, i|
      <<~XML
        <entry>
          <resource>
            <Observation>
              <id value="symptom-#{i + 1}-#{c.patient_id}"/>
              <status value="final"/>
              <category><coding><system value="http://terminology.hl7.org/CodeSystem/observation-category"/><code value="symptom"/></coding></category>
              <code><text value="symptom"/></code>
              <subject><reference value="urn:uuid:#{c.patient_id}"/></subject>
              <effectiveDateTime value="2026-01-15T09:00:00+00:00"/>
              <valueString value="#{esc(s)}"/>
            </Observation>
          </resource>
        </entry>
      XML
    end.join
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Bundle xmlns="http://hl7.org/fhir">
        <id value="bundle-#{c.mrn.downcase}"/>
        <meta><lastUpdated value="2026-01-15T09:00:00.000+00:00"/><profile value="http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"/></meta>
        <type value="collection"/>
        <entry>
          <fullUrl value="urn:uuid:#{c.patient_id}"/>
          <resource>
            <Patient>
              <id value="#{c.patient_id}"/>
              <identifier><type><coding><system value="http://terminology.hl7.org/CodeSystem/v2-0203"/><code value="MR"/></coding></type><value value="#{c.mrn}"/></identifier>
              <name><use value="official"/><family value="#{esc(c.last)}"/><given value="#{esc(c.first)}"/></name>
              <telecom><system value="phone"/><value value="#{c.phone}"/><use value="home"/></telecom>
              <gender value="#{c.gender_source}"/>
              <birthDate value="#{c.dob}"/>
              <address><line value="#{esc(c.street)}"/><city value="#{esc(c.city)}"/><state value="#{esc(c.state)}"/><postalCode value="#{c.zip}"/></address>
            </Patient>
          </resource>
        </entry>
      #{conds.lines.map { |l| "  #{l}" }.join}#{obs.lines.map { |l| "  #{l}" }.join}  <entry>
          <resource>
            <Coverage>
              <status value="active"/>
              <subscriberId value="MBR#{c.index * 31337}"/>
              <beneficiary><reference value="urn:uuid:#{c.patient_id}"/></beneficiary>
              <payor><display value="Lakeside PPO Gold"/></payor>
            </Coverage>
          </resource>
        </entry>
      </Bundle>
    XML
  end

  # -- 3. PDF (uncompressed, hand-assembled) ---------------------------------

  def pdf_escape(s) = s.to_s.gsub("\\") { "\\\\" }.gsub("(") { "\\(" }.gsub(")") { "\\)" }

  # lines: [[font(1|2), size, text], ...] per page
  def build_pdf(pages, info)
    objs = {}
    objs[1] = "<< /Type /Catalog /Pages 2 0 R >>"
    page_ids = pages.each_index.map { |i| 6 + i * 2 }
    objs[2] = "<< /Type /Pages /Kids [#{page_ids.map { |id| "#{id} 0 R" }.join(' ')}] /Count #{pages.size} >>"
    objs[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
    objs[4] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>"
    objs[5] = "<< " + info.map { |k, v| "/#{k} (#{pdf_escape(v)})" }.join(" ") + " >>"
    pages.each_with_index do |lines, i|
      pid = 6 + i * 2
      cid = pid + 1
      y = 750
      body = +"BT\n"
      lines.each do |font, size, text|
        body << "/F#{font} #{size} Tf 1 0 0 1 54 #{y} Tm (#{pdf_escape(text)}) Tj\n"
        y -= (size * 1.5).round
      end
      body << "ET\n"
      objs[pid] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents #{cid} 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> >>"
      objs[cid] = "<< /Length #{body.bytesize} >>\nstream\n#{body}endstream"
    end
    out = +"%PDF-1.4\n"
    offsets = {}
    objs.keys.sort.each do |id|
      offsets[id] = out.bytesize
      out << "#{id} 0 obj\n#{objs[id]}\nendobj\n"
    end
    xref_at = out.bytesize
    out << "xref\n0 #{objs.size + 1}\n0000000000 65535 f \n"
    objs.keys.sort.each { |id| out << format("%010d 00000 n \n", offsets[id]) }
    out << "trailer\n<< /Size #{objs.size + 1} /Root 1 0 R /Info 5 0 R >>\nstartxref\n#{xref_at}\n%%EOF\n"
    out
  end

  def pdf(c)
    v = vitals_for(c)
    p1 = [
      [2, 16, "#{c.facility.upcase} - DISCHARGE SUMMARY"],
      [1, 9, "Dept. of Medicine | 1 Hospital Way, #{c.city}, #{c.state} | Tel (555) 010-#{(1000 + c.index).to_s[-4..]} | Fax (555) 010-9#{(100 + c.index).to_s[-3..]}"],
      [1, 9, "CONFIDENTIAL - contains protected health information (synthetic test data)"],
      [1, 6, " "],
      [2, 11, "PATIENT"],
      [1, 10, "Name: #{c.name}        MRN: #{c.mrn}        DOB: #{c.dob}"],
      [1, 10, "Sex: #{c.gender_source}        Phone: #{c.phone}"],
      [1, 10, "Address: #{c.street}, #{c.city}, #{c.state} #{c.zip}"],
      [1, 6, " "],
      [2, 11, "ENCOUNTER"],
      [1, 10, "Admit: 2026-01-15 08:41        Discharge: 2026-01-16 11:05        Ward: B-#{c.index % 9 + 1}"],
      [1, 10, "Attending: Dr. #{c.provider}        Disposition: Home with outpatient follow-up"],
      [1, 6, " "],
      [2, 11, "VITALS ON ADMISSION"],
      [1, 10, "BP #{v['bp']} mmHg   HR #{v['hr']} bpm   Temp #{v['temp_f']} F   SpO2 #{v['spo2']}%   Wt #{v['weight_kg']} kg   Ht #{v['height_cm']} cm"],
      [1, 6, " "],
      [2, 11, "DISCHARGE MEDICATIONS"],
      *meds_for(c).map { |m, rx| [1, 10, "  - #{m}   [RxNorm #{rx}]   1 tab PO daily"] },
      [1, 6, " "],
      [2, 11, "INSURANCE / BILLING"],
      [1, 10, "Payer: Lakeside PPO Gold   Group: GRP-8842   Member: MBR#{c.index * 31337}   Copay: $25.00"],
      [1, 10, "Claim ref: CLM-2026-#{(c.index * 4099).to_s.rjust(7, '0')}   Status: pending adjudication"],
      [1, 8, "Page 1 of 2"],
    ]
    p2 = [
      [2, 16, "#{c.facility.upcase} - DISCHARGE SUMMARY (cont.)"],
      [1, 9, "Patient: #{c.name}   MRN: #{c.mrn}"],
      [1, 6, " "],
      [2, 11, "DIAGNOSES (SNOMED CT)"],
      *c.dx.each_with_index.map { |(code, display), i| [1, 10, "  #{i + 1}. #{code} - #{display}"] },
      [1, 6, " "],
      [2, 11, "PRESENTING SYMPTOMS"],
      *(c.symptoms.empty? ? [[1, 10, "  None reported."]] : c.symptoms.map { |s| [1, 10, "  * #{s}"] }),
      [1, 6, " "],
      [2, 11, "HOSPITAL COURSE"],
      [1, 10, NOISE_TEXT[c.index % NOISE_TEXT.size]],
      [1, 10, NOISE_TEXT[(c.index + 3) % NOISE_TEXT.size]],
      [1, 10, "Follow-up in 2 weeks with primary care. Return precautions reviewed."],
      [1, 6, " "],
      [1, 10, "Electronically signed: Dr. #{c.provider}   2026-01-16 11:12"],
      [1, 8, "Page 2 of 2"],
    ]
    build_pdf([p1, p2], "Title" => "Discharge Summary #{c.mrn}", "Author" => "#{c.facility} HIM", "Producer" => "LegacyReportEngine 4.2",
                        "Keywords" => "discharge,summary,#{c.mrn},draft", "CreationDate" => "D:20260116110500-05'00'")
  end

  # -- 4. Plain-text SOAP note ----------------------------------------------

  def soap_note(c)
    v = vitals_for(c)
    age = 2026 - c.dob[0, 4].to_i
    <<~TXT
      ================================================================
      #{c.facility.upcase}                             PROGRESS NOTE
      Date of service: 01/15/2026   Provider: #{c.provider}, MD
      ================================================================
      PT: #{c.last.upcase}, #{c.first.upcase}   MRN #{c.mrn}   DOB #{c.dob}   #{age} y/o #{c.gender_source}
      Pharmacy on file: CornerDrug #0#{c.index}   Ins: Lakeside PPO Gold

      S: #{age} y/o #{c.gender_source} here for follow-up. #{c.symptoms.empty? ? 'Denies any new complaints today.' : "C/o #{c.symptoms.join('; ')}."}
         #{NOISE_TEXT[c.index % NOISE_TEXT.size]}
         #{NOISE_TEXT[(c.index + 2) % NOISE_TEXT.size]}
         Current meds: #{meds_for(c).map(&:first).join(', ')}.

      O: BP #{v['bp']}  HR #{v['hr']}  T #{v['temp_f']}  SpO2 #{v['spo2']}%  Wt #{v['weight_kg']}kg
         Gen: NAD. Lungs CTAB. CV RRR no m/r/g. Abd soft NT/ND.

      A/P:
      #{c.dx.each_with_index.map { |(code, d), i| "  #{i + 1}) #{d} [SNOMED #{code}] - continue current mgmt" }.join("\n")}

      RTC 4 wks sooner prn. Labs ordered: CBC, CMP, lipid panel.

      /s/ #{c.provider}, MD   (dictated, not proofread)
    TXT
  end

  # -- 5. CSV ---------------------------------------------------------------

  def csv(c)
    headers = %w[export_id exported_at facility_code mrn last_name first_name sex dob street city state zip phone
                 payer_id group_no copay_usd attending bp hr temp_f spo2 dx_1_code dx_1_text dx_2_code dx_2_text
                 dx_3_code dx_3_text symptom_1 symptom_2 symptom_3 symptom_4 note]
    v = vitals_for(c)
    row = [
      "EXP-#{c.index.to_s.rjust(6, '0')}", "2026-01-15T09:00:00Z", "FAC-0#{c.index % 9 + 1}", c.mrn, c.last, c.first, c.gender_source,
      c.dob, c.street, c.city, c.state, c.zip, c.phone, "PAYER-4471", "GRP-8842", "25.00", c.provider, v["bp"], v["hr"],
      v["temp_f"], v["spo2"],
      *c.dx.flat_map { |code, d| [code, d] },
      *(c.symptoms + [""] * 4).first(4),
      NOISE_TEXT[c.index % NOISE_TEXT.size],
    ]
    quote = ->(f) { f.to_s.match?(/[",\n]/) ? "\"#{f.to_s.gsub('"', '""')}\"" : f.to_s }
    "#{headers.join(',')}\n#{row.map(&quote).join(',')}\n"
  end

  # -- 6. YAML --------------------------------------------------------------

  def yaml(c)
    v = vitals_for(c)
    doc = {
      "schema" => "ehr-export/v7", "generated" => "2026-01-15T09:00:00Z", "source" => { "system" => "ChartKeeper", "site" => c.facility },
      "encounter" => { "id" => "ENC-#{c.index * 977}", "date" => "2026-01-15", "provider" => c.provider, "ward" => "B-#{c.index % 9 + 1}" },
      "person" => {
        "mrn" => c.mrn, "legal_name" => c.name, "sex_or_gender" => c.gender_source, "born" => c.dob,
        "contact" => { "phone" => c.phone, "address" => "#{c.street}, #{c.city}, #{c.state} #{c.zip}" },
      },
      "vitals" => v,
      "medications" => meds_for(c).map { |m, rx| { "name" => m, "rxnorm" => rx, "active" => true } },
      "problems" => c.dx.map { |code, d| { "snomed" => code, "label" => d, "status" => "active" } },
      "reported_symptoms" => c.symptoms,
      "billing" => { "payer" => "PAYER-4471", "group" => "GRP-8842", "copay_usd" => 25.0, "prior_auth" => false },
      "notes" => [NOISE_TEXT[c.index % NOISE_TEXT.size], NOISE_TEXT[(c.index + 5) % NOISE_TEXT.size]],
    }
    "# ChartKeeper nightly export - do not edit by hand\n#{YAML.dump(doc)}"
  end

  # -- 7. EML (RFC 5322 + MIME) ----------------------------------------------

  def eml(c)
    boundary = "----=_Part_#{c.index}_#{c.mrn}"
    body = <<~TXT
      Hi team,

      Referral for the 2pm slot. Details below, please add to the chart before the visit.

      Patient: #{c.name} (MRN #{c.mrn}, DOB #{c.dob}, #{c.gender_source})
      Phone: #{c.phone}
      Working diagnoses:
      #{c.dx.map { |code, d| "  - #{d} (SNOMED CT #{code})" }.join("\n")}
      Presenting symptoms: #{c.symptoms.empty? ? 'none reported' : c.symptoms.join(', ')}

      #{NOISE_TEXT[c.index % NOISE_TEXT.size]}
      Lunch is on the 3rd floor again today - the cafeteria is doing the lentil soup.

      Thanks,
      #{c.provider}
      Referrals Coordinator | #{c.facility}

      --
      This message and any attachments are confidential and intended solely for the addressee.
    TXT
    junk_attachment = Base64.encode64("order_id,test,status\n#{c.index}001,CBC,final\n#{c.index}002,CMP,final\n#{c.index}003,Lipid panel,pending\n")
    <<~EML
      Return-Path: <referrals@#{c.facility.downcase.gsub(/[^a-z]/, '')}.example.org>
      Received: from mail-gw1.example.org (10.0.#{c.index}.12) by mx.example.org with ESMTPS; Thu, 15 Jan 2026 08:55:#{(c.index % 50 + 10)} -0500
      Message-ID: <#{c.patient_id}.#{c.index}@referrals.example.org>
      Date: Thu, 15 Jan 2026 08:55:00 -0500
      From: "Referrals Desk" <referrals@#{c.facility.downcase.gsub(/[^a-z]/, '')}.example.org>
      To: "Scheduling" <scheduling@example-clinic.example.org>
      Subject: RE: FWD: referral #{c.mrn} - please add to chart
      X-Priority: 3
      X-Mailer: MailBridge 11.4
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="#{boundary}"

      --#{boundary}
      Content-Type: text/plain; charset=UTF-8
      Content-Transfer-Encoding: 7bit

      #{body.rstrip}

      --#{boundary}
      Content-Type: text/csv; name="pending_orders.csv"
      Content-Transfer-Encoding: base64
      Content-Disposition: attachment; filename="pending_orders.csv"

      #{junk_attachment.rstrip}

      --#{boundary}--
    EML
  end

  # -- 8. RTF ----------------------------------------------------------------

  def rtf_escape(s) = s.to_s.gsub("\\") { "\\\\" }.gsub("{") { "\\{" }.gsub("}") { "\\}" }

  def rtf(c)
    dx_lines = c.dx.map { |code, d| "\\bullet\\tab #{rtf_escape(d)} (SNOMED #{code})\\par" }.join("\n")
    sym = c.symptoms.empty? ? "None reported.\\par" : c.symptoms.map { |s| "\\bullet\\tab #{rtf_escape(s)}\\par" }.join("\n")
    <<~RTF
      {\\rtf1\\ansi\\ansicpg1252\\deff0\\nouicompat
      {\\fonttbl{\\f0\\fswiss\\fcharset0 Arial;}{\\f1\\fmodern\\fcharset0 Courier New;}}
      {\\colortbl ;\\red0\\green0\\blue0;\\red192\\green0\\blue0;}
      {\\info{\\title Visit Letter #{c.mrn}}{\\author #{c.provider}}{\\company #{rtf_escape(c.facility)}}}
      \\viewkind4\\uc1\\pard\\f0\\fs22
      {\\b\\fs28 #{rtf_escape(c.facility)}}\\par
      {\\i Visit letter - generated from template VL-#{c.index + 100}}\\par\\par
      {\\b Patient:} #{rtf_escape(c.name)}\\par
      {\\b Gender:} #{c.gender_source}\\par
      {\\b Date of birth:} #{c.dob}\\par
      {\\b MRN:} #{c.mrn}\\par
      {\\b Address:} #{rtf_escape(c.street)}, #{rtf_escape(c.city)}, #{rtf_escape(c.state)} #{c.zip}\\par\\par
      {\\b Diagnoses}\\par
      #{dx_lines}
      \\par
      {\\b Symptoms reported at visit}\\par
      #{sym}
      \\par
      {\\cf2 #{rtf_escape(NOISE_TEXT[c.index % NOISE_TEXT.size])}}\\par
      {\\f1\\fs18 Template merge fields: <<PAYER>>=PAYER-4471 <<GROUP>>=GRP-8842 <<COPAY>>=25.00}\\par
      Sincerely,\\par #{c.provider}, MD\\par
      }
    RTF
  end

  # -- 9. Markdown -----------------------------------------------------------

  def markdown(c)
    v = vitals_for(c)
    <<~MD
      ---
      title: "Visit note - #{c.mrn}"
      tags: [clinic, followup, draft]
      template: visit-note-v3
      ---

      # #{c.facility}: visit note

      > Auto-published from the clinic wiki. Last edited by #{c.provider} on 2026-01-15.

      ## Who

      | Field | Value |
      | ----- | ----- |
      | Patient | **#{c.name}** |
      | Gender | #{c.gender_source} |
      | DOB | #{c.dob} |
      | MRN | `#{c.mrn}` |
      | Phone | #{c.phone} |

      ## Vitals

      | BP | HR | Temp F | SpO2 |
      | -- | -- | ------ | ---- |
      | #{v['bp']} | #{v['hr']} | #{v['temp_f']} | #{v['spo2']}% |

      ## Diagnoses

      #{c.dx.map { |code, d| "1. #{d} - SNOMED CT `#{code}`" }.join("\n")}

      ## Symptoms

      #{c.symptoms.empty? ? '_None reported._' : c.symptoms.map { |s| "- #{s}" }.join("\n")}

      ## Admin

      - [x] Insurance verified (PAYER-4471 / GRP-8842)
      - [ ] Parking validated
      - [ ] Survey sent

      <!-- #{NOISE_TEXT[c.index % NOISE_TEXT.size]} -->
    MD
  end

  # -- 10. Patient-portal HTML ----------------------------------------------

  def html_portal(c)
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <title>MyChart-ish | After Visit Summary</title>
        <style>
          body { font-family: Verdana, sans-serif; background: #f4f6f8; }
          .card { background: #fff; border: 1px solid #ccd; margin: 12px; padding: 12px; }
          .banner { background: #004a7c; color: #fff; padding: 8px; }
          th { text-align: left; }
        </style>
        <script>window.dataLayer = window.dataLayer || []; dataLayer.push({visit: "#{c.mrn}"});</script>
      </head>
      <body>
        <div class="banner"><img src="/static/logo.svg" alt="#{esc(c.facility)}"> #{esc(c.facility)} - Patient Portal</div>
        <nav><a href="/inbox">Messages (3)</a> | <a href="/billing">Billing</a> | <a href="/appointments">Appointments</a> | <a href="/logout">Log out</a></nav>
        <div class="card" id="demographics">
          <h2>After Visit Summary</h2>
          <table>
            <tr><th>Name</th><td class="pt-name">#{esc(c.name)}</td></tr>
            <tr><th>Gender</th><td class="pt-gender">#{esc(c.gender_source)}</td></tr>
            <tr><th>Date of birth</th><td>#{c.dob}</td></tr>
            <tr><th>MRN</th><td>#{c.mrn}</td></tr>
          </table>
        </div>
        <div class="card" id="diagnoses">
          <h3>Your diagnoses</h3>
          <ul>
            #{c.dx.map { |code, d| "<li data-snomed=\"#{code}\"><strong>#{esc(d)}</strong> <small>(code #{code})</small></li>" }.join("\n      ")}
          </ul>
        </div>
        <div class="card" id="symptoms">
          <h3>Symptoms you reported</h3>
          #{c.symptoms.empty? ? '<p><em>None reported.</em></p>' : "<ul>#{c.symptoms.map { |s| "<li>#{esc(s)}</li>" }.join}</ul>"}
        </div>
        <div class="card" id="billing"><h3>Balance</h3><p>Copay due: $25.00. Payer PAYER-4471, group GRP-8842.</p><button onclick="pay()">Pay now</button></div>
        <footer><small>#{esc(NOISE_TEXT[c.index % NOISE_TEXT.size])} &copy; 2026 #{esc(c.facility)}</small></footer>
      </body>
      </html>
    HTML
  end

  # -- 11. HTML page with a FHIR Bundle in a <script> tag ---------------------

  def html_embedded_fhir(c)
    bundle = {
      "resourceType" => "Bundle", "type" => "collection",
      "entry" => [
        { "resource" => { "resourceType" => "Patient", "id" => c.patient_id,
                          "name" => [{ "use" => "official", "family" => c.last, "given" => [c.first] }], "gender" => c.gender_source, "birthDate" => c.dob } },
        *c.dx.map { |code, d| { "resource" => { "resourceType" => "Condition", "code" => { "coding" => [{ "system" => "http://snomed.info/sct", "code" => code, "display" => d }] }, "subject" => { "reference" => "urn:uuid:#{c.patient_id}" } } } },
        *c.symptoms.map { |s| { "resource" => { "resourceType" => "Observation", "status" => "final", "code" => { "text" => "symptom" }, "valueString" => s, "subject" => { "reference" => "urn:uuid:#{c.patient_id}" } } } },
      ],
    }
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>SMART app launch - #{esc(c.facility)}</title>
        <link rel="stylesheet" href="/assets/app-#{c.index}.css">
        <script src="https://cdn.example.org/jquery-3.7.1.min.js"></script>
        <script id="launch-context" type="application/json">{"iss":"https://fhir.example.org/r4","launch":"#{c.patient_id[0, 8]}","scope":"patient/*.read launch openid fhirUser","state":"#{c.mrn.downcase}"}</script>
      </head>
      <body class="loading">
        <div id="app">Loading chart for MRN #{c.mrn}&hellip;</div>
        <script id="prefetched-bundle" type="application/fhir+json">
      #{JSON.pretty_generate(bundle).lines.map { |l| "    #{l}" }.join}
        </script>
        <script>
          document.addEventListener("DOMContentLoaded", function () {
            var raw = document.getElementById("prefetched-bundle").textContent;
            renderChart(JSON.parse(raw));
            document.body.className = "ready";
          });
        </script>
      </body>
      </html>
    HTML
  end

  # -- 12. SQL dump ----------------------------------------------------------

  def sql_quote(s) = "'#{s.to_s.gsub("'", "''")}'"

  def sql_dump(c)
    v = vitals_for(c)
    <<~SQL
      -- MySQL dump 10.13  Distrib 8.0.36, for Linux (x86_64)
      -- Host: ehr-db-prod-02    Database: ehr_legacy
      -- Server version 8.0.36
      /*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
      /*!40103 SET TIME_ZONE='+00:00' */;

      DROP TABLE IF EXISTS `patients`;
      CREATE TABLE `patients` (
        `id` int NOT NULL AUTO_INCREMENT,
        `mrn` varchar(16) NOT NULL,
        `last_name` varchar(64) NOT NULL,
        `first_name` varchar(64) NOT NULL,
        `sex` varchar(16) DEFAULT NULL,
        `dob` date DEFAULT NULL,
        PRIMARY KEY (`id`)
      ) ENGINE=InnoDB;
      INSERT INTO `patients` (`id`,`mrn`,`last_name`,`first_name`,`sex`,`dob`) VALUES (#{c.index},#{sql_quote(c.mrn)},#{sql_quote(c.last)},#{sql_quote(c.first)},#{sql_quote(c.gender_source)},#{sql_quote(c.dob)});

      DROP TABLE IF EXISTS `encounters`;
      CREATE TABLE `encounters` (`id` int, `patient_id` int, `admit_ts` datetime, `ward` varchar(8), `attending` varchar(64), `bp` varchar(8), `hr` int, `temp_f` decimal(4,1));
      INSERT INTO `encounters` VALUES (#{c.index * 10},#{c.index},'2026-01-15 08:41:00','B-#{c.index % 9 + 1}',#{sql_quote(c.provider)},#{sql_quote(v['bp'])},#{v['hr']},#{v['temp_f']});

      DROP TABLE IF EXISTS `diagnoses`;
      CREATE TABLE `diagnoses` (`id` int, `encounter_id` int, `code_system` varchar(16), `code` varchar(24), `description` varchar(255));
      INSERT INTO `diagnoses` VALUES
      #{c.dx.each_with_index.map { |(code, d), i| "  (#{c.index * 100 + i},#{c.index * 10},'SNOMED',#{sql_quote(code)},#{sql_quote(d)})" }.join(",\n")};

      DROP TABLE IF EXISTS `symptoms`;
      CREATE TABLE `symptoms` (`id` int, `encounter_id` int, `description` varchar(128), `severity` varchar(8));
      #{c.symptoms.empty? ? '-- (no rows for this encounter)' : "INSERT INTO `symptoms` VALUES\n#{c.symptoms.each_with_index.map { |s, i| "  (#{c.index * 100 + i},#{c.index * 10},#{sql_quote(s)},#{sql_quote(%w[mild moderate severe][i % 3])})" }.join(",\n")};"}

      DROP TABLE IF EXISTS `billing_events`;
      CREATE TABLE `billing_events` (`id` int, `encounter_id` int, `payer_id` varchar(16), `amount_cents` int, `status` varchar(16));
      INSERT INTO `billing_events` VALUES (#{c.index * 7},#{c.index * 10},'PAYER-4471',#{12500 + c.index * 37},'PENDING'),(#{c.index * 7 + 1},#{c.index * 10},'PAYER-4471',2500,'COPAY');

      DROP TABLE IF EXISTS `audit_log`;
      CREATE TABLE `audit_log` (`ts` datetime, `user` varchar(32), `action` varchar(32));
      INSERT INTO `audit_log` VALUES ('2026-01-15 08:40:12','frontdesk3','VIEW_PATIENT'),('2026-01-15 09:02:51','awhitfield','OPEN_CHART'),('2026-01-15 09:30:07','svc_batch','EXPORT');
      -- Dump completed on 2026-01-15 23:59:59
    SQL
  end

  # -- 13. X12 837P claim ----------------------------------------------------

  def x12_837(c)
    segs = []
    segs << "ISA*00*          *00*          *ZZ*LAKESIDEEHR    *ZZ*PAYER4471      *260115*0900*^*00501*#{(c.index * 13).to_s.rjust(9, '0')}*0*P*:"
    segs << "GS*HC*LAKESIDEEHR*PAYER4471*20260115*0900*#{c.index}*X*005010X222A1"
    segs << "ST*837*0001*005010X222A1"
    segs << "BHT*0019*00*#{c.index * 101}*20260115*0900*CH"
    segs << "NM1*41*2*#{c.facility.upcase}*****46*#{(c.index * 7919).to_s.rjust(9, '0')}"
    segs << "PER*IC*BILLING OFFICE*TE*5550100000"
    segs << "NM1*40*2*LAKESIDE PPO GOLD*****46*PAYER4471"
    segs << "HL*1**20*1"
    segs << "NM1*85*2*#{c.facility.upcase}*****XX*1#{(c.index * 104729).to_s.rjust(9, '0')}"
    segs << "N3*1 HOSPITAL WAY"
    segs << "N4*#{c.city.upcase}*MA*#{c.zip}"
    segs << "HL*2*1*22*0"
    segs << "SBR*P*18*GRP-8842******CI"
    segs << "NM1*IL*1*#{c.last.upcase}*#{c.first.upcase}****MI*MBR#{c.index * 31337}"
    segs << "N3*#{c.street.upcase}"
    segs << "N4*#{c.city.upcase}*MA*#{c.zip}"
    segs << "DMG*D8*#{c.dob.delete('-')}*#{c.gender_source}"
    segs << "NM1*PR*2*LAKESIDE PPO GOLD*****PI*PAYER4471"
    segs << "CLM*CLM#{c.index * 4099}*125.00***11:B:1*Y*A*Y*Y"
    segs << "DTP*431*D8*20260115"
    segs << "HI*#{c.dx.each_with_index.map { |(code, _), i| "#{i.zero? ? 'ABK' : 'ABF'}:#{code}" }.join('*')}"
    c.symptoms.each { |s| segs << "NTE*ADD*SYMPTOM #{s.upcase}" }
    segs << "NTE*ADD*#{NOISE_TEXT[c.index % NOISE_TEXT.size].upcase.delete('.')}"
    segs << "LX*1"
    segs << "SV1*HC:99213*125.00*UN*1***#{c.dx.size.times.map { |i| i + 1 }.join(':')}"
    segs << "DTP*472*D8*20260115"
    segs << "SE*#{segs.size - 1}*0001"
    segs << "GE*1*#{c.index}"
    segs << "IEA*1*#{(c.index * 13).to_s.rjust(9, '0')}"
    segs.map { |s| "#{s}~" }.join("\n") + "\n"
  end

  # -- 14. FHIR Bulk Data NDJSON ----------------------------------------------

  def ndjson_bulk(c)
    lines = []
    lines << { "resourceType" => "Patient", "id" => c.patient_id, "meta" => { "versionId" => "1", "lastUpdated" => "2026-01-15T09:00:00Z" },
               "identifier" => [{ "system" => "urn:oid:2.16.840.1.113883.19.5", "value" => c.mrn }],
               "name" => [{ "use" => "official", "family" => c.last, "given" => [c.first] }],
               "gender" => c.gender_source, "birthDate" => c.dob,
               "address" => [{ "line" => [c.street], "city" => c.city, "state" => c.state, "postalCode" => c.zip }] }
    lines << { "resourceType" => "Encounter", "id" => "enc-#{c.index}", "status" => "finished", "class" => { "system" => "http://terminology.hl7.org/CodeSystem/v3-ActCode", "code" => "AMB" },
               "subject" => { "reference" => "Patient/#{c.patient_id}" }, "period" => { "start" => "2026-01-15T08:41:00Z", "end" => "2026-01-15T09:30:00Z" } }
    lines << { "resourceType" => "Coverage", "id" => "cov-#{c.index}", "status" => "active", "subscriberId" => "MBR#{c.index * 31337}", "beneficiary" => { "reference" => "Patient/#{c.patient_id}" } }
    c.dx.each_with_index do |(code, d), i|
      lines << { "resourceType" => "Condition", "id" => "cond-#{c.index}-#{i}", "clinicalStatus" => { "coding" => [{ "system" => "http://terminology.hl7.org/CodeSystem/condition-clinical", "code" => "active" }] },
                 "code" => { "coding" => [{ "system" => "http://snomed.info/sct", "code" => code, "display" => d }], "text" => d },
                 "subject" => { "reference" => "Patient/#{c.patient_id}" }, "encounter" => { "reference" => "Encounter/enc-#{c.index}" } }
    end
    meds_for(c).each_with_index do |(m, rx), i|
      lines << { "resourceType" => "MedicationRequest", "id" => "mr-#{c.index}-#{i}", "status" => "active", "intent" => "order",
                 "medicationCodeableConcept" => { "coding" => [{ "system" => "http://www.nlm.nih.gov/research/umls/rxnorm", "code" => rx, "display" => m }] },
                 "subject" => { "reference" => "Patient/#{c.patient_id}" } }
    end
    c.symptoms.each_with_index do |s, i|
      lines << { "resourceType" => "Observation", "id" => "symptom-#{i + 1}-#{c.patient_id}", "status" => "final",
                 "category" => [{ "coding" => [{ "system" => "http://terminology.hl7.org/CodeSystem/observation-category", "code" => "symptom" }] }],
                 "code" => { "text" => "symptom" }, "subject" => { "reference" => "Patient/#{c.patient_id}" }, "valueString" => s }
    end
    lines.map { |l| JSON.generate(l) }.join("\n") + "\n"
  end

  # -- 15. Fixed-width mainframe record ---------------------------------------

  def fixed_width(c)
    cols = [["REC-TYPE", 4], ["FACILITY", 10], ["MRN", 10], ["PATIENT-NAME", 32], ["SEX", 2], ["DOB", 12], ["DX-1", 16], ["DX-2", 16], ["DX-3", 16], ["SYMPTOMS", 80], ["PAYER", 12]]
    vals = [
      "ADM1", "FAC#{(c.index % 9 + 1).to_s.rjust(3, '0')}", c.mrn, "#{c.last.upcase}, #{c.first.upcase}", c.gender_source, c.dob,
      *(c.dx.map(&:first) + [""] * 3).first(3), c.symptoms.join("/"), "PAYER-4471",
    ]
    <<~TXT
      *****************************************************************
      * COPYBOOK ADMREC01  -  LEGACY ADMISSIONS EXTRACT (BATCH ADM0420)
      * RECORD LENGTH #{cols.sum { |_, w| w }}   RECFM=FB   BLOCK=0
      * FIELD LAYOUT (POSITION IS 1-BASED, LEFT-JUSTIFIED, SPACE PADDED):
      #{cols.each_with_index.map { |(n, w), i| "*   #{n.ljust(14)} PIC X(#{w.to_s.rjust(2, '0')})   START #{(cols.first(i).sum { |_, cw| cw } + 1).to_s.rjust(3, '0')}" }.join("\n")}
      * DX-n FIELDS ARE SNOMED CT CONCEPT IDS. SYMPTOMS IS SLASH-SEPARATED.
      * EXTRACT DATE 2026-01-15   JOB ADM0420J   STEP 03   RC=0000
      *****************************************************************
      #{cols.zip(vals).map { |(_, w), v| v.to_s.ljust(w)[0, w] }.join}
      TRAILER 000001 RECORDS  #{NOISE_TEXT[c.index % NOISE_TEXT.size].upcase}
    TXT
  end

  # -- 16. SMS / chat transcript ----------------------------------------------

  def sms_chat(c)
    dx_msg = c.dx.map { |code, d| "#{d} = #{code}" }.join("\n    ")
    <<~TXT
      [Care Team Chat export - channel #triage-#{c.index} - 2026-01-15]

      [08:57] Dana (front desk): morning! got a walk-in, checking them in now
      [08:58] Dana (front desk): name is #{c.name}, they said to put #{c.gender_source} for gender, dob #{c.dob}
      [08:58] Dana (front desk): mrn #{c.mrn} btw
      [09:01] Nurse Tran: thanks. also did anyone move the 10:30 to room 4?? the whiteboard is a mess
      [09:01] Dana (front desk): yes room 4. coffee machine is broken again lol
      [09:04] Nurse Tran: ok intake done. they're here for: #{c.symptoms.empty? ? 'nothing new, just a follow up' : c.symptoms.join(' + ')}
      [09:05] Dr. #{c.provider.split('. ').last}: ok. problem list is
          #{dx_msg}
      [09:05] Dr. #{c.provider.split('. ').last}: (those are snomed ids)
      [09:06] Nurse Tran: 👍 adding to chart
      [09:07] Dana (front desk): copay collected $25, payer 4471
      [09:12] Nurse Tran: #{NOISE_TEXT[c.index % NOISE_TEXT.size].downcase}
      [09:30] Dana (front desk): who has the good stapler
    TXT
  end

  # -- 17. SpreadsheetML 2003 -------------------------------------------------

  def spreadsheetml(c)
    cell = ->(v, t = "String") { "<Cell><Data ss:Type=\"#{t}\">#{esc(v)}</Data></Cell>" }
    row = ->(*vals) { "    <Row>#{vals.map { |v| cell.call(v) }.join}</Row>" }
    <<~XML
      <?xml version="1.0"?>
      <?mso-application progid="Excel.Sheet"?>
      <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
        <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office"><Author>HIM Reporting</Author><LastAuthor>jdoe</LastAuthor><Created>2026-01-15T09:00:00Z</Created><Company>#{esc(c.facility)}</Company></DocumentProperties>
        <Styles><Style ss:ID="hdr"><Font ss:Bold="1"/></Style></Styles>
        <Worksheet ss:Name="Cover">
          <Table>
      #{row.call('Weekly census report', 'DRAFT')}
      #{row.call('Generated', '2026-01-15')}
      #{row.call('Unit', "B-#{c.index % 9 + 1}")}
      #{row.call('Notes', NOISE_TEXT[c.index % NOISE_TEXT.size])}
          </Table>
        </Worksheet>
        <Worksheet ss:Name="Patient">
          <Table>
      #{row.call('Field', 'Value')}
      #{row.call('Name', c.name)}
      #{row.call('Gender', c.gender_source)}
      #{row.call('DOB', c.dob)}
      #{row.call('MRN', c.mrn)}
      #{row.call('Phone', c.phone)}
          </Table>
        </Worksheet>
        <Worksheet ss:Name="Diagnoses">
          <Table>
      #{row.call('SNOMED code', 'Description')}
      #{c.dx.map { |code, d| row.call(code, d) }.join("\n")}
          </Table>
        </Worksheet>
        <Worksheet ss:Name="Symptoms">
          <Table>
      #{row.call('Reported symptom')}
      #{c.symptoms.empty? ? row.call('(none reported)') : c.symptoms.map { |s| row.call(s) }.join("\n")}
          </Table>
        </Worksheet>
        <Worksheet ss:Name="Billing">
          <Table>
      #{row.call('Payer', 'PAYER-4471')}
      #{row.call('Group', 'GRP-8842')}
      #{row.call('Copay', '25.00')}
          </Table>
        </Worksheet>
      </Workbook>
    XML
  end

  # -- 18. FHIR RDF (Turtle) ---------------------------------------------------

  def ttl_str(s) = "\"#{s.to_s.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }}\""

  def rdf_turtle(c)
    pat = "<https://fhir.example.org/r4/Patient/#{c.patient_id}>"
    conds = c.dx.each_with_index.map do |(code, d), i|
      <<~TTL
        <https://fhir.example.org/r4/Condition/cond-#{c.index}-#{i}> a fhir:Condition ;
          fhir:nodeRole fhir:treeRoot ;
          fhir:Condition.clinicalStatus [ fhir:CodeableConcept.coding [ fhir:Coding.code [ fhir:value "active" ] ] ] ;
          fhir:Condition.code [
            fhir:CodeableConcept.coding [
              fhir:index 0 ;
              fhir:Coding.system [ fhir:value "http://snomed.info/sct" ] ;
              fhir:Coding.code [ fhir:value #{ttl_str(code)} ] ;
              fhir:Coding.display [ fhir:value #{ttl_str(d)} ]
            ] ;
            fhir:CodeableConcept.text [ fhir:value #{ttl_str(d)} ]
          ] ;
          fhir:Condition.subject [ fhir:link #{pat} ] .
      TTL
    end.join("\n")
    obs = c.symptoms.each_with_index.map do |s, i|
      <<~TTL
        <https://fhir.example.org/r4/Observation/symptom-#{i + 1}-#{c.patient_id}> a fhir:Observation ;
          fhir:nodeRole fhir:treeRoot ;
          fhir:Observation.status [ fhir:value "final" ] ;
          fhir:Observation.code [ fhir:CodeableConcept.text [ fhir:value "symptom" ] ] ;
          fhir:Observation.subject [ fhir:link #{pat} ] ;
          fhir:Observation.valueString [ fhir:value #{ttl_str(s)} ] .
      TTL
    end.join("\n")
    <<~TTL
      @prefix fhir: <http://hl7.org/fhir/> .
      @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
      @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
      @prefix sct: <http://snomed.info/id/> .
      @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

      # Exported by RDF-Gateway 2.9 at 2026-01-15T09:00:00Z (#{NOISE_TEXT[c.index % NOISE_TEXT.size]})
      <https://fhir.example.org/r4/Bundle/export-#{c.index}> a fhir:Bundle ;
        fhir:Bundle.type [ fhir:value "collection" ] .

      #{pat} a fhir:Patient ;
        fhir:nodeRole fhir:treeRoot ;
        fhir:Patient.identifier [ fhir:Identifier.value [ fhir:value #{ttl_str(c.mrn)} ] ] ;
        fhir:Patient.name [
          fhir:index 0 ;
          fhir:HumanName.use [ fhir:value "official" ] ;
          fhir:HumanName.family [ fhir:value #{ttl_str(c.last)} ] ;
          fhir:HumanName.given [ fhir:value #{ttl_str(c.first)} ; fhir:index 0 ]
        ] ;
        fhir:Patient.gender [ fhir:value #{ttl_str(c.gender_source)} ] ;
        fhir:Patient.birthDate [ fhir:value #{ttl_str(c.dob)}^^xsd:date ] .

      #{conds}
      #{obs}
    TTL
  end

  # -- 19. JSON-LD (schema.org) -----------------------------------------------

  def json_ld(c)
    doc = {
      "@context" => { "@vocab" => "https://schema.org/", "snomed" => "http://snomed.info/id/" },
      "@graph" => [
        { "@type" => "MedicalClinic", "@id" => "#clinic", "name" => c.facility, "telephone" => "(555) 010-#{(1000 + c.index).to_s[-4..]}",
          "address" => { "@type" => "PostalAddress", "addressLocality" => c.city, "addressRegion" => c.state } },
        { "@type" => "Patient", "@id" => "#patient", "identifier" => c.mrn, "name" => c.name, "givenName" => c.first, "familyName" => c.last,
          "gender" => "https://schema.org/#{c.gender_source.capitalize}", "birthDate" => c.dob, "telephone" => c.phone,
          "diagnosis" => c.dx.map { |code, d|
            { "@type" => "MedicalCondition", "name" => d,
              "code" => { "@type" => "MedicalCode", "codeValue" => code, "codingSystem" => "SNOMED CT" } }
          },
          "signOrSymptom" => c.symptoms.map { |s| { "@type" => "MedicalSymptom", "name" => s } } },
        { "@type" => "MedicalTherapy", "name" => "Follow-up visit", "provider" => { "@id" => "#clinic" }, "description" => NOISE_TEXT[c.index % NOISE_TEXT.size] },
        { "@type" => "HealthInsurancePlan", "name" => "Lakeside PPO Gold", "healthPlanId" => "GRP-8842" },
      ],
    }
    JSON.pretty_generate(doc) + "\n"
  end

  # -- 20. Faxed-then-OCR'd scan ----------------------------------------------

  def ocr_noise(str, seed)
    rng = Random.new(seed)
    str.chars.map { |ch|
      case ch
      when "l" then rng.rand < 0.12 ? "1" : ch
      when "o" then rng.rand < 0.06 ? "0" : ch
      when "e" then rng.rand < 0.04 ? "c" : ch
      else ch
      end
    }.join
  end

  def ocr_fax(c)
    n = ->(s) { ocr_noise(s, c.index) }
    <<~TXT
      -- 1 of 2 --
      #{n.call('FAX TRANSMISSION')}  ====  #{n.call('Received')}: 01/15/2026 08:12  ====  #{n.call('From')}: (555) 010-#{(2000 + c.index).to_s[-4..]}  p. 1/2
      ~~~~ ~~ . ,,
      #{n.call(c.facility.upcase)}
      #{n.call('REGISTRATION / REFERRAL FORM')}      form no. RF-#{c.index + 200}
      __________________________________________________

      PATIENT NAME:  #{c.last.upcase}, #{c.first.upcase}
      SEX:  #{c.gender_source}        DOB:  #{c.dob}
      #{n.call('MEDICAL RECORD')} #:  #{c.mrn}
      #{n.call('ADDRESS')}:  #{c.street}, #{c.city} #{c.state} #{c.zip}
      PH:  #{c.phone}

      #{n.call('INSURANCE')}:  Lakeside PPO Gold    ID  MBR#{c.index * 31337}    GRP  GRP-8842
      #{n.call('Referring physician')}:  Dr. #{c.provider}      #{n.call('signature')}:  ______________

      [x] #{n.call('Urgent')}   [ ] #{n.call('Routine')}   [ ] #{n.call('Lab only')}

      DIAGNOSES (SNOMED):
      #{c.dx.map { |code, d| "   #{code}   #{d}" }.join("\n")}

      #{n.call('PRESENTING SYMPTOMS')}:  #{c.symptoms.empty? ? 'N/A' : c.symptoms.join(', ')}

      #{n.call(NOISE_TEXT[c.index % NOISE_TEXT.size])}
      ' ,.  |||  . ..
      -- 2 of 2 --
      #{n.call('CONFIDENTIALITY NOTICE')}: #{n.call('This facsimile contains privileged and confidential information')}.
      #{n.call('If you have received this fax in error please call')} (555) 010-0000 #{n.call('immediately')}.
      ~~~~ [scan quality: low] ~~~~
    TXT
  end

  # -- 21. Voice-dictation transcript ----------------------------------------

  DIGIT_WORDS = %w[zero one two three four five six seven eight nine].freeze

  def spoken_digits(code) = code.chars.map { |d| DIGIT_WORDS[d.to_i] }.join(" ")

  def dictation(c)
    pron = c.gender_source == "female" ? "she" : "he"
    diag = c.dx.each_with_index.map { |(code, d), i| "Diagnosis number #{DIGIT_WORDS[i + 1]}, #{d.sub(/ \((disorder|finding|situation)\)\z/, '')}, SNOMED code #{spoken_digits(code)}." }.join(" ")
    symp = c.symptoms.empty? ? "Patient denies any new symptoms today." : "Today #{pron} presents with #{c.symptoms.size == 1 ? c.symptoms.first : "#{c.symptoms[0..-2].join(', ')}, and #{c.symptoms.last}"}."
    <<~TXT
      [VOICE-TO-TEXT v3.2 | confidence 0.91 | speaker 1 of 1 | duration 02:41 | job #{c.index * 5003}]
      [00:00] uh okay this is doctor #{c.provider.split('. ').last} dictating a note for #{c.facility} um date of service january fifteenth twenty twenty six
      [00:09] the patient is #{c.name} that's #{c.first.chars.join(' ')} #{c.last.chars.join(' ')} medical record number #{c.mrn.chars.join(' ')} gender #{c.gender_source} uh date of birth #{c.dob}
      [00:24] okay so, #{symp}
      [00:41] vitals are stable. um blood pressure #{vitals_for(c)['bp'].sub('/', ' over ')} and heart rate #{vitals_for(c)['hr']}
      [00:58] #{diag}
      [01:30] we'll continue current medications, #{meds_for(c).map(&:first).first}, and uh follow up in four weeks
      [01:44] ah sorry just a second. the parking validation thing. never mind, #{NOISE_TEXT[c.index % NOISE_TEXT.size].downcase}
      [02:20] okay that's the end of dictation, please route to billing, payer forty four seventy one thanks
      [END OF TRANSCRIPT]
    TXT
  end

  # -- 22. Base64-wrapped payload in a JSON message envelope ----------------

  GENDER_IDENTITY_LABEL = {
    "446151000124109" => "Identifies as male gender",
    "446141000124107" => "Identifies as female gender",
  }.freeze

  def base64_envelope(c)
    inner = <<~TXT
      CLINICAL SUMMARY (plain text attachment)
      Patient name: #{c.name}
      MRN: #{c.mrn}
      DOB: #{c.dob}
      Gender identity (SNOMED CT): #{c.gender_source} - #{GENDER_IDENTITY_LABEL.fetch(c.gender_source)}
      Diagnoses:
      #{c.dx.map { |code, d| "  #{code} | #{d}" }.join("\n")}
      Symptoms: #{c.symptoms.empty? ? '(none)' : c.symptoms.join('; ')}
      Comment: #{NOISE_TEXT[c.index % NOISE_TEXT.size]}
    TXT
    envelope = {
      "messageId" => c.patient_id, "receivedAt" => "2026-01-15T09:00:07Z",
      "channel" => { "type" => "sftp-drop", "host" => "sftp.gateway.example.org", "path" => "/inbound/#{c.mrn.downcase}/" },
      "routing" => { "priority" => "normal", "retries" => 0, "tenant" => "lakeside", "tags" => %w[clinical inbound unparsed] },
      "attachment" => {
        "filename" => "summary_#{c.mrn.downcase}.txt", "contentType" => "text/plain; charset=utf-8", "encoding" => "base64",
        "sizeBytes" => inner.bytesize, "sha1" => "0" * 40, "payload" => Base64.strict_encode64(inner),
      },
      "trace" => { "hops" => ["edge-3", "mq-1", "ingest-7"], "elapsedMs" => 41 + c.index },
    }
    JSON.pretty_generate(envelope) + "\n"
  end

  # [manifest/format name, file extension, renderer, gender-source chooser(real_gender)]
  # Gender sources are keys of Normalizers::GENDER_TRANSLATIONS, written the
  # way that format would plausibly carry them.
  FORMATS = [
    ["cda_xml", "xml", :cda_xml, ->(g) { g[0].upcase }],
    ["fhir_xml", "xml", :fhir_xml, ->(_g) { "other" }],
    ["pdf", "pdf", :pdf, ->(g) { g.capitalize }],
    ["soap_note", "txt", :soap_note, ->(g) { g[0].upcase }],
    ["csv", "csv", :csv, ->(g) { g.capitalize }],
    ["yaml", "yaml", :yaml, ->(_g) { "non-binary" }],
    ["eml", "eml", :eml, ->(g) { g }],
    ["rtf", "rtf", :rtf, ->(g) { g.capitalize }],
    ["markdown", "md", :markdown, ->(g) { g }],
    ["html_portal", "html", :html_portal, ->(g) { g.capitalize }],
    ["html_embedded_fhir", "html", :html_embedded_fhir, ->(g) { g }],
    ["sql_dump", "sql", :sql_dump, ->(g) { g[0].upcase }],
    ["x12_837", "x12", :x12_837, ->(_g) { "U" }],
    ["ndjson_bulk", "ndjson", :ndjson_bulk, ->(g) { g }],
    ["fixed_width", "dat", :fixed_width, ->(_g) { "O" }],
    ["sms_chat", "txt", :sms_chat, ->(_g) { "nonbinary" }],
    ["spreadsheetml", "xml", :spreadsheetml, ->(_g) { "Transgender" }],
    ["rdf_turtle", "ttl", :rdf_turtle, ->(g) { g }],
    ["json_ld", "jsonld", :json_ld, ->(g) { g }],
    ["ocr_fax", "txt", :ocr_fax, ->(g) { g[0].upcase }],
    ["dictation", "txt", :dictation, ->(g) { g }],
    ["base64_envelope", "json", :base64_envelope, ->(g) { g == "male" ? "446151000124109" : "446141000124107" }],
  ].freeze
end
