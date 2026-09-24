# Protiti to Bangladesh Police Online e-GD Schema Mapping
**Document Reference:** PROTITI-EGD-MAP-2026-V1  
**Target Systems:** Bangladesh Police Online GD Portal (`gd.police.gov.bd`), Police Cyber Support for Women (PCSW), CID Cyber Police Centre (CPC), National Emergency Service (999).  
**Purpose:** Technical and administrative specification for transforming Protiti's in-app legal questionnaire into the official Bangladesh Police Online General Diary API payload.

---

## 1. Architectural Overview & Integration Model

When a victim of cyber harassment or gender-based violence uses Protiti's **GD-Automator**, the application captures user responses through a trauma-informed, 4-step wizard. To bridge the gap identified in judicial critiques—where police station (*Thana*) Duty Officers reject freeform or unformatted complaints—Protiti structures this data to match the **Bangladesh Police Online GD (e-GD)** system.

```mermaid
flowchart TD
    User([Protiti User]) --> Wizard[Trauma-Informed GD Wizard]
    Wizard --> Schema[Protiti Canonical Incident Model]
    
    Schema --> Validate{NID & Data Complete?}
    Validate -- Yes --> Transform[e-GD Schema Transformer]
    
    Transform --> Route{Incident Severity & Type}
    
    Route -- "Standard Cyber Complaint" --> EGD[Bangladesh Police e-GD Portal API<br/>gd.police.gov.bd]
    Route -- "Female Victim / Blackmail / NCII" --> PCSW[PCSW Escalation Dossier<br/>01320000888 / pcsw@police.gov.bd]
    Route -- "Physical Danger / Imminent Standoff" --> NES[999 Emergency Dispatch Payload]
    Route -- "Organized / Deepfake Syndicate" --> CID[CID Cyber Police Centre (CPC)]
    
    Transform --> PDF[Court-Ready Signed PDF with QR Hash]
```

---

## 2. Administrative Hierarchy & Thana Directory Mapping

A primary reason e-GD submissions fail is incorrect administrative jurisdiction coding. Under the **Cyber Protection Act, 2026** and **CrPC Section 177-182**, jurisdiction for online offenses lies in:
1.  **The Thana of the victim's ordinary residence** (where harm/intimidation was received); OR
2.  **The Thana where the suspect published/transmitted the material**; OR
3.  **The Thana where the server/intermediary operates**.

Protiti implements an internal jurisdictional lookup matching Bangladesh's 8 administrative divisions:

| Division ID | Division Name (EN) | বিভাগ (BN) | Metropolitan Units Covered | Total Districts | Standard Thana Code Range |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `DIV-01` | Dhaka | ঢাকা | DMP, GMP (Gazipur) | 13 | `1001` – `1150` |
| `DIV-02` | Chattogram | চট্টগ্রাম | CMP | 11 | `2001` – `2120` |
| `DIV-03` | Rajshahi | রাজশাহী | RMP | 8 | `3001` – `3080` |
| `DIV-04` | Khulna | খুলনা | KMP | 10 | `4001` – `4095` |
| `DIV-05` | Barishal | বরিশাল | BMP | 6 | `5001` – `5055` |
| `DIV-06` | Sylhet | সিলেট | SMP | 4 | `6001` – `6045` |
| `DIV-07` | Rangpur | রংপুর | RPMP | 8 | `7001` – `7075` |
| `DIV-08` | Mymensingh | ময়মনসিংহ | Range Police | 4 | `8001` – `8040` |

---

## 3. Incident Taxonomy & Categorization

The Bangladesh Police e-GD portal categorizes cyber incidents under specific statutory codes. Protiti maps user-friendly intake questions directly into official police incident taxonomies:

| Protiti Intake Selection | e-GD Category Code | e-GD Sub-Category (Bangla) | Primary Statutory Citation |
| :--- | :--- | :--- | :--- |
| **Blackmail with Photos/Videos (Sextortion)** | `CYBER-01` | অন্তরঙ্গ ছবি/ভিডিও দিয়ে ব্ল্যাকমেইল ও চাঁদাবাজি | Cyber Protection Act 2026, Sec 25; Pornography Control Act 2012, Sec 8(3) |
| **Fake Account / Identity Theft** | `CYBER-02` | ভুয়া বা ছদ্মবেশী ফেসবুক/ইনস্টাগ্রাম অ্যাকাউন্ট | Cyber Protection Act 2026, Sec 25; Penal Code 1860, Sec 419 |
| **AI Deepfakes / Altered Images** | `CYBER-03` | কৃত্রিম বুদ্ধিমত্তা (AI) দিয়ে তৈরি আপত্তিকর ছবি | Cyber Protection Act 2026, Sec 25(A) |
| **Cyberstalking & Persistent Threats** | `CYBER-04` | সামাজিক মাধ্যমে নিরবচ্ছিন্ন নজরদারি ও প্রাণনাশের হুমকি | Cyber Protection Act 2026, Sec 28; Penal Code 1860, Sec 506 |
| **Defamation & Malicious Slander** | `CYBER-05` | মানহানিকর ও বানোয়াট তথ্য প্রচার | Cyber Protection Act 2026, Sec 29; Penal Code 1860, Sec 500 |
| **Hacked / Compromised Account** | `CYBER-06` | অ্যাকাউন্ট বা ডিজিটাল ডিভাইস অননুমোদিত অ্যাক্সেস | Cyber Protection Act 2026, Sec 19/20 |

---

## 4. Complete JSON Schema Specification (`protiti_egd_payload_v1.json`)

This schema represents the JSON payload produced by Protiti for automated submission to `gd.police.gov.bd` and generation of courtroom-compliant documentation:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "ProtitiToPoliceEGDPayload",
  "type": "object",
  "required": [
    "submission_metadata",
    "complainant",
    "jurisdiction",
    "incident",
    "evidence_manifest",
    "legal_declaration"
  ],
  "properties": {
    "submission_metadata": {
      "type": "object",
      "required": ["dossier_id", "app_version", "created_at_utc", "triage_route"],
      "properties": {
        "dossier_id": { "type": "string", "pattern": "^PROTITI-[A-Z0-9]{8}-[0-9]{4}$" },
        "app_version": { "type": "string", "example": "1.0.4-fellowship" },
        "created_at_utc": { "type": "string", "format": "date-time" },
        "created_at_bst": { "type": "string", "example": "2026-09-25T07:30:00+06:00" },
        "triage_route": { 
          "type": "string", 
          "enum": ["EGD_DIRECT", "PCSW_PRIORITY", "EMERGENCY_999", "CID_CPC"] 
        }
      }
    },
    "complainant": {
      "type": "object",
      "required": [
        "nid_number",
        "full_name_en",
        "full_name_bn",
        "father_name",
        "mother_name",
        "mobile_msisdn",
        "present_address"
      ],
      "properties": {
        "nid_number": { "type": "string", "pattern": "^[0-9]{10}|[0-9]{17}$" },
        "porichoy_verified": { "type": "boolean" },
        "full_name_en": { "type": "string" },
        "full_name_bn": { "type": "string" },
        "father_name": { "type": "string" },
        "mother_name": { "type": "string" },
        "spouse_name": { "type": "string" },
        "gender": { "type": "string", "enum": ["FEMALE", "MALE", "THIRD_GENDER"] },
        "date_of_birth": { "type": "string", "format": "date" },
        "mobile_msisdn": { "type": "string", "pattern": "^\\+8801[3-9][0-9]{8}$" },
        "email": { "type": "string", "format": "email" },
        "present_address": {
          "type": "object",
          "required": ["division_id", "district_id", "thana_id", "post_code", "address_line_bn"],
          "properties": {
            "division_id": { "type": "string" },
            "district_id": { "type": "string" },
            "thana_id": { "type": "string" },
            "post_code": { "type": "string" },
            "address_line_bn": { "type": "string" }
          }
        },
        "permanent_address": {
          "type": "object",
          "properties": {
            "division_id": { "type": "string" },
            "district_id": { "type": "string" },
            "thana_id": { "type": "string" },
            "post_code": { "type": "string" },
            "address_line_bn": { "type": "string" }
          }
        }
      }
    },
    "jurisdiction": {
      "type": "object",
      "required": ["target_thana_code", "target_thana_name", "jurisdiction_rationale"],
      "properties": {
        "target_thana_code": { "type": "string", "example": "1042" },
        "target_thana_name": { "type": "string", "example": "Dhanmondi Model Thana, DMP" },
        "jurisdiction_rationale": { 
          "type": "string", 
          "enum": ["VICTIM_RESIDENCE", "PERPETRATOR_LOCATION", "OCCURRENCE_PLACE"] 
        }
      }
    },
    "incident": {
      "type": "object",
      "required": [
        "category_code",
        "platforms_involved",
        "first_noticed_timestamp",
        "statement_summary_bn",
        "suspect_profile"
      ],
      "properties": {
        "category_code": { "type": "string", "example": "CYBER-01" },
        "platforms_involved": {
          "type": "array",
          "items": {
            "type": "string",
            "enum": ["FACEBOOK", "MESSENGER", "INSTAGRAM", "WHATSAPP", "TELEGRAM", "TIKTOK", "IMO", "SMS", "WEBSITE", "OTHER"]
          }
        },
        "first_noticed_timestamp": { "type": "string", "format": "date-time" },
        "is_ongoing": { "type": "boolean" },
        "blackmail_demands": {
          "type": "object",
          "properties": {
            "money_extortion": { "type": "boolean" },
            "demanded_amount_bdt": { "type": "number" },
            "sexual_favors": { "type": "boolean" },
            "threats_to_share_family": { "type": "boolean" }
          }
        },
        "suspect_profile": {
          "type": "object",
          "required": ["identity_status"],
          "properties": {
            "identity_status": { "type": "string", "enum": ["KNOWN", "UNKNOWN", "SUSPECTED"] },
            "suspect_name": { "type": "string" },
            "suspect_relation": { "type": "string" },
            "suspect_mobile": { "type": "string" },
            "target_profile_url": { "type": "string", "format": "uri" },
            "target_account_uid": { "type": "string" },
            "target_handle": { "type": "string" }
          }
        },
        "statement_summary_bn": { "type": "string" },
        "statement_summary_en": { "type": "string" }
      }
    },
    "evidence_manifest": {
      "type": "array",
      "items": {
        "type": "object",
        "required": [
          "item_id",
          "file_name",
          "mime_type",
          "sha256_hash",
          "capture_timestamp_utc",
          "file_size_bytes"
        ],
        "properties": {
          "item_id": { "type": "string" },
          "file_name": { "type": "string" },
          "mime_type": { "type": "string", "example": "image/png" },
          "sha256_hash": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
          "sha512_hash": { "type": "string", "pattern": "^[a-f0-9]{128}$" },
          "capture_timestamp_utc": { "type": "string", "format": "date-time" },
          "file_size_bytes": { "type": "integer" },
          "source_url": { "type": "string" },
          "exif_preserved": { "type": "boolean" },
          "tamper_proof_checksum": { "type": "string" }
        }
      }
    },
    "legal_declaration": {
      "type": "object",
      "required": [
        "sec_65b_certificate_hash",
        "affirmation_truthfulness",
        "statutory_citations"
      ],
      "properties": {
        "sec_65b_certificate_hash": { "type": "string", "pattern": "^[a-f0-9]{64}$" },
        "affirmation_truthfulness": { "type": "boolean" },
        "statutory_citations": {
          "type": "array",
          "items": { "type": "string" },
          "example": [
            "Cyber Protection Act 2026, Section 25",
            "Pornography Control Act 2012, Section 8(3)",
            "Evidence (Amendment) Act 2022, Section 65B"
          ]
        }
      }
    }
  }
}
```

---

## 5. PCSW (Police Cyber Support for Women) Dedicated Escalation

### 5.1 Why PCSW Escalation is Critical
Standard Thana submission can often subject traumatized women to insensitive questioning by junior desk constables. **Police Cyber Support for Women (PCSW)**, established under Bangladesh Police Headquarters, is staffed entirely by trained female police officers, IT forensics specialists, and psycho-legal counselors.

### 5.2 PCSW Multi-Channel Dispatch Protocol:
When a female victim indicates an incident of Non-Consensual Intimate Imagery (NCII), sextortion, or severe cyberstalking:

1.  **Immediate PCSW Hotline Trigger:**
    *   Direct click-to-call link: `tel:01320000888`
    *   24/7 dedicated support desk operated exclusively by female officers.
2.  **Automated Encrypted Email Dispatch (`pcsw@police.gov.bd`):**
    *   The app compiles an official encrypted transmission directly addressed to PCSW Headquarters.
    *   **Email Subject:** `[URGENT-PCSW COMPLAINT] GBCV Incident Report - Ref: PROTITI-[DOSSIER-ID]`
    *   **Body Content:** Official intake statement in Bengali, verified complainant phone number, and suspect digital profile coordinates.
    *   **Attachment:** The cryptographically verified, court-ready PDF dossier containing the SHA-256 evidence manifest.
3.  **PCSW Facebook Ingestion Linkage:**
    *   Automated deep-link redirection to the verified portal: `https://www.facebook.com/pcsw.police.gov.bd`.

---

## 6. Offline & Low-Bandwidth USSD / SMS Fallback Architecture

Addressing the critical challenge highlighted in the Judge's Critique regarding rural women with no internet or exhausted data packages:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Protiti Offline SOS / Fallback Matrix                │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
           ┌────────────────────────┴────────────────────────┐
           ▼                                                 ▼
   1. Active Mobile Internet                       2. Zero-Data / Offline Mode
   • Full JSON Payload to gd.police.gov.bd         • Lightweight Encrypted SMS (140 bytes)
   • PDF Dossier to pcsw@police.gov.bd             • Direct Voice Dispatch to 999
   • Cloud Vault Hash Backup                       • Local Cryptographic Stamping (Offline)
```

### 6.1 Compressed Emergency SMS Payload Structure
If internet is unavailable, Protiti does **not** attempt to transmit heavy image files (which fail on 2G/3G). Instead, it encodes critical forensic and safety coordinates into a **single 140-character SMS** routed to pre-configured trusted contacts and the community legal paralegal:

```
PROTITI!SOS#ID:P-78A4#LOC:23.7508,90.3842#TIME:2609250125#CAT:SEXTORT#HASH:8a7f0d...e1#CALL:999
```
*   **Field 1 (`PROTITI!SOS`):** Header trigger for emergency parsing.
*   **Field 2 (`P-78A4`):** Local device dossier ID.
*   **Field 3 (`LOC`):** Raw GPS coordinates (lat, long) obtained via device satellite fix without internet.
*   **Field 4 (`TIME`):** UTC timestamp.
*   **Field 5 (`CAT`):** Incident classification abbreviation.
*   **Field 6 (`HASH`):** First 8 bytes of evidence SHA-256 hash (verifying that evidence exists and is sealed on-device).

Once data connectivity resumes, the full high-resolution dossier automatically syncs and transmits to the official e-GD endpoints.

---

*Authored by Senior Legal Advisor Agent, Project Protiti.*  
*DKC Fellowship 2026 — Legal & Systems Architecture.*
