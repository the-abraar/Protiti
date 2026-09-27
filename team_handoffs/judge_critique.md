# ⚖️ The DKC Senior Judge & Critical Evaluator Audit: Project Protiti (প্রতীতি)

**Evaluation Date:** September 25, 2026  
**Fellowship Track:** DKC Digital Respect & Cohesion Fellowship 2026 (UNDP PTIB / EU / SURGE)  
**Thematic Area:** Gender-based Online Violence | Cross-Cutting Lens: Gender Equity  
**Audit Stage:** Pre-Submission Gateway Review (Deadline: September 30, 2026 — 5 Days Remaining)  
**Evaluator Stance:** Adversarial, Uncompromising, Grounded in Real-World Bangladesh Realities  

---

## Executive Summary: From Idealistic Hackathon to Contender — But Lethal Traps Remain

In our initial critique, Project Protiti was dismissed as an ivory-tower prototype: legally naive, technically suicidal for survivors facing physical coercion, and blind to Bangladesh's rural and institutional realities.

The team responded with an intense cross-functional sprint across Dev, Legal, Design, and Community desks. The transformation is substantial:
* An actual working Flutter implementation of **Duress PIN** and **Stealth Calculator Disguise** with zero analyzer errors.
* A rigorous statutory mapping to the newly enacted **Cyber Protection Act, 2026** and **Evidence (Amendment) Act, 2022**.
* An authentic, culturally grounded brand identity (**Protiti / প্রতীতি**) backed by a high-fidelity interactive design system and survivor safeguarding protocols.

**However, do not celebrate yet.** A senior fellowship judge or an adversarial defense attorney does not evaluate your intentions; they evaluate where your system will break. Our second-pass audit uncovered **four fatal vulnerabilities**, **critical cross-document synchronization failures**, and a **severe operational contradiction with DKC Fellowship rules** that will result in immediate disqualification or embarrassment during the interview stage if not rectified before September 30.

---

## 📊 The Official DKC Fellowship 3-Stage Scorecard

| Evaluation Dimension | Weight | Initial Score | Current Score | Judicial Verdict |
| :--- | :---: | :---: | :---: | :--- |
| **1. Problem Understanding & Thematic Depth** | 20% | 6.0 / 10 | **9.0 / 10** | **Exceptional.** Unpacks digital blackmail, deepfakes, screenshot evidentiary loss, and societal stigma with nuance. |
| **2. Technical Innovation & Security Architecture** | 25% | 4.0 / 10 | **7.5 / 10** | **Passable with Critical OPSEC Flaws.** Dual-PIN works, but database co-mingling and UI giveaways create physical danger. |
| **3. Ground-Level Feasibility & Community Reach** | 20% | 4.5 / 10 | **7.0 / 10** | **High Ambition, Broken Economics.** 8-division scope on 50k BDT contradicts fellowship structure; must anchor locally. |
| **4. Legal Admissibility & Institutional Grounding** | 15% | 3.5 / 10 | **8.5 / 10** | **Massive Improvement.** Section 65B compliance, e-GD JSON schema, and BLAST/BNWLA framework are jury-ready. |
| **5. Seed Grant (BDT 50,000) Budget Realism** | 10% | 5.0 / 10 | **6.0 / 10** | **Severe Dilution.** Spreading BDT 50K across 8 divisions allocates BDT 1,400 per workshop. Financially impossible. |
| **6. Sustainability & Scalability Beyond Fellowship** | 10% | 5.0 / 10 | **8.5 / 10** | **Strong.** Integration with PCSW, police cyber desks, and pro-bono networks ensures life after grant. |
| **OVERALL COMPOSITE SCORE** | **100%** | **4.7 / 10** | **7.8 / 10** | **Tier 1 Shortlist Contender, Pending Final Must-Fixes** |

---

## 🛑 Forensic Audit: The 6 Must-Fixes vs. Codebase Reality

### 1. Duress PIN & Decoy Vault Subsystem
* **Evaluation:** **PARTIALLY FIXED — WITH A LETHAL OPSEC BUG.**
* **What Works:**
  - `AuthService` (`dkc/lib/data/services/auth_service.dart`) cleanly handles `AuthStatus.authenticatedReal` (PIN `1234`) vs `AuthStatus.authenticatedDuress` (PIN `9999`).
  - Entering `9999` dynamically switches `VaultScreen` to "Personal Notes & Files", loading syllabus, grocery budgets, and biryani recipes.
* **The Fatal Bugs & Blindspots:**
  1. **The "DECOY MODE" Banner of Death:** In `dkc/lib/ui/features/vault/vault_screen.dart` (lines 62–76), when `isDecoy` is true, the AppBar renders a container with the literal text **`"DECOY MODE"`**! If an abusive partner or family member forces a survivor to unlock her phone, glances at the screen, and reads "DECOY MODE" in the header, the victim will face immediate, escalated physical violence. **Remove this indicator instantly.** Decoy mode must look 100% uncompromised.
  2. **The Lock Screen Cheat Sheet:** In `dkc/lib/ui/features/auth/lock_screen.dart` (lines 283–302), a prominent card displays: `Demo PIN: 1234 (Real Vault) | 9999 (Duress Decoy)`. If installed on an actual device, this completely defeats the duress mechanism. This banner must be gated behind a hidden debug toggle or removed for production builds.
  3. **Database Co-Mingling (Zero Forensic Isolation):** In `DatabaseService` (`dkc/lib/data/services/database_service.dart`), real evidence and decoy evidence are stored in the **exact same SQLite database table** (`protiti_vault.db`), separated only by an `isDecoy INTEGER DEFAULT 0` column. Worse, both share the same single encryption key from `FlutterSecureStorage`. If a tech-savvy perpetrator or hostile forensics examiner extracts the database, a trivial SQL query (`SELECT * FROM evidence`) unmasks every single victim record. As the Legal Team mandated in `team_handoffs/legal_handoff.md`, true decoy architecture requires a completely separate SQLite file (`decoy_vault.db`) with zero schema pointers to real records.
  4. **PIN Inconsistency:** `design_handoff.md` specifies `1971=` (Real) and `0000=` (Decoy). Dev implemented `1234` and `9999`. Unify the documentation and pitch slides.

---

### 2. e-GD Integration & Police Station Reality
* **Evaluation:** **STRATEGICALLY SOUND — IMPLEMENTATION BACKLOGGED.**
* **What Works:**
  - `legal/e_gd_schema_mapping.md` is world-class. It provides the exact field-by-field JSON payload mapping to `gd.police.gov.bd`, administrative division Thana codes (`DIV-01` to `DIV-08`), and statutory category codes (`CYBER-01` to `CYBER-06`).
  - Realistic escalation protocols for **Police Cyber Support for Women (PCSW)** (`01320000888`) and the CID Cyber Police Centre.
* **The Fatal Bugs & Blindspots:**
  1. **The "Live API" Myth:** In `dev_handoff.md` and pitch discussions, there is talk of "integrating with the e-GD API". Judges who work in Bangladesh civic tech or UNDP know that Bangladesh Police **do not offer a public third-party REST API** for arbitrary apps to submit GDs. Submissions require NID verification via the national *Porichoy* gateway and telecom OTPs. The team must be crystal clear in the interview: Protiti generates a *schema-compliant digital dossier with cryptographic QR verification* that can be uploaded or physically handed to the Duty Officer, backed by direct PCSW escalation, rather than falsely claiming live database writes to government servers.
  2. **Unimplemented PDF Generation:** The client-side PDF renderer with embedded SHA-256 hashes and QR verification remains on the engineering backlog (Item 1 in `dev_handoff.md`). Until this is compiled, the app cannot produce the physical document needed at a rural Thana.

---

### 3. Offline SOS & Panic Mechanism
* **Evaluation:** **ENGINEERED PROPERLY FOR DATA RESILIENCE — OPERATIONAL FRICTION IN DISPATCH.**
* **What Works:**
  - The team listened: heavy media broadcasting over 3G/4G was completely discarded in favor of a zero-data, lightweight SMS coordinate payload (`trigger_panic.dart`).
  - The 3-second hold-to-activate gesture (`panic_screen.dart`) with radial progress animation successfully eliminates accidental pocket triggers.
* **The Fatal Bugs & Blindspots:**
  1. **The Native SMS Intent Trap:** Look at `trigger_panic.dart` (lines 86–94):
     ```dart
     final smsUri = Uri(scheme: 'sms', path: recipientStr, queryParameters: {'body': message});
     await launchUrl(smsUri);
     ```
     On both Android and iOS, `launchUrl(smsUri)` does **not** silently send an SMS in the background! It launches the native messaging app with the text pre-filled. **The user must still tap "Send" in the SMS app.** If a victim is being attacked or cornered, launching an SMS app displaying: `"EMERGENCY SOS [Protiti]: I need urgent help! My location: https://maps.google.com/..."` right on the screen gives the attacker full visibility of the alert before it is even transmitted!
  2. **No Hardware Button Fallback:** The panic trigger still requires opening the app, navigating past the lock screen, and holding a touch target on screen. In a real-world assault, the phone is in a pocket, bag, or under a desk. An Android background service listening for triple-press power button triggers is essential for real-world survival.

---

### 4. Local Legal Admissibility (Evidence Act 2022 & Cyber Protection Act 2026)
* **Evaluation:** **EXCEPTIONAL LEGAL RESEARCH — DISCONNECTED FROM PITCH DECK.**
* **What Works:**
  - `legal/cyber_protection_act_2026_guide.md` and `legal/legal_aid_partnership_framework.md` correctly navigate the legislative shift from CSA 2023 to the **Cyber Protection Act, 2026** and **Pornography Control Act, 2012**.
  - Perfect mastery of the **Evidence (Amendment) Act, 2022** (Section 65B Certificates of Authenticity, Section 22A oral testimony bar, and Section 45A expert attestation).
* **The Fatal Bugs & Blindspots:**
  1. **Pitch Deck Out-of-Sync (Embarrassing Oversight):** While the Legal and Community teams updated all references to the *Cyber Protection Act, 2026*, the actual pitch deck (`pitch_materials/pitch_deck.md`) in **Slide 2 and Slide 5 still references the "Cyber Security Act" (the old, repealed 2023 law)**! If a judge reads "Cyber Security Act" on Slide 5, they will assume your team is living in 2024.
  2. **Unfinished Slides:** `pitch_deck.md` still contains literal draft placeholders:
     - Slide 6: `[Placeholder for Quote]`
     - Slide 7: `Budget: [Budget Breakdown Placeholder - e.g., Dev: 40%, Outreach: 40%, Legal: 20%]`
     Submitting a deck with bracketed placeholders will disqualify you at Stage 1.
  3. **Partnership Representation:** The deck must frame BLAST and BNWLA as an *institutional engagement framework under the UNDP PTIB umbrella*, not misrepresent them as signed corporate contracts before fellowship onboarding.

---

### 5. Shared-Device Dynamics & Stealth Disguise
* **Evaluation:** **INNOVATIVE CALCULATOR WORKAROUND — DEVICE-LEVEL HOLES.**
* **What Works:**
  - Functional calculator disguise with working arithmetic evaluator (`lock_screen.dart` and `protiti_mockup.html`). Entering `<PIN>=` silently triggers authentication.
* **The Fatal Bugs & Blindspots:**
  1. **Disguise is Manual, Not Default:** The Flutter app opens by default to the prominent **"Protiti (প্রতীতি) Forensic Vault Authentication"** lock screen! A user must manually tap the calculator icon in the top right to disguise it. If a spouse or parent grabs the phone unexpectedly, the app opens as a purple forensic vault. It should have a persistent setting: *"Always Launch as Calculator"*.
  2. **Home Screen Icon & App Name:** On Android, the app is installed under the label `protiti` or `Protiti`. If an abuser browses the home screen, an app called "Protiti" or an icon resembling a purple shield invites immediate interrogation. Dynamic activity-alias icon swapping (to disguise the app as "Calculator" or "System Notes" on the OS launcher) must be implemented.

---

### 6. Full Bengali Localization & Rural Accessibility
* **Evaluation:** **FLAWED EXECUTION — HIGH DESIGN STANDARDS, ENGLISH-ONLY CODEBASE.**
* **What Works:**
  - `pitch_materials/protiti_mockup.html` and `design_handoff.md` feature excellent bilingual typography pairing Poppins/Inter with Hind Siliguri and deep cultural resonance.
  - Trauma-informed Bengali microcopy standards are well-documented.
* **The Fatal Bugs & Blindspots:**
  1. **Codebase is 100% English Hardcoded:** In `dkc/lib/`, every button, header, and error message is hardcoded in English: `"Enter security PIN"`, `"Incorrect PIN. Please re-enter"`, `"Secure New Evidence"`, `"Hold for 3 seconds to activate"`. There is no `intl` or `.arb` localization file. A semi-literate victim in rural Barishal or Rangpur will not understand why an authentication attempt failed or how to file a complaint.
  2. **Voice Navigation Missing:** Audio-guided intake was promised in the pitch documents to address literacy barriers across the 8 divisions, but there is zero audio playback or TTS infrastructure in the code.

---

## 🚨 The Fellowship Disqualification Risk: The "8 Divisions with BDT 50K" Hallucination

This is the single most dangerous strategic flaw in the current proposal.

In `pitch_materials/eight_divisions_rollout.md` and `pitch_materials/budget_50k.md`, the Community team proposed:
* **64 Campus Ambassadors** across all 8 administrative divisions (8 per division).
* **8 Regional Campus Hubs** (DU, CU, SUST, RU, KU, BU, BRUR, BAU).
* **8 Separate Workshops**, 8 Dedicated SIMs, 10,000 printed survivor cards, and regional courier logistics—all funded by the **BDT 50,000 seed grant**.

### Why This Will Destroy You in Front of the UNDP DKC Judges:
1. **Direct Violation of DKC Fellowship Rules:**
   - Refer to `DKC.md` (lines 64–65, 195–196):
     > *"Your team should represent, and plan to implement its initiative in, **one of Bangladesh's eight divisions**... Only 8 teams are chosen nationally — **one per division**."*
   - DKC funds **8 separate teams nationally**, assigning **one team per division** with **BDT 50,000 each** to address their specific local divisional community.
   - If Protiti applies as a single team claiming to execute an 8-division nationwide campaign on BDT 50,000, the selection committee will see that you have not even read the fellowship guidelines. You are an applicant team, not UNDP headquarters.
2. **Financial Absurdity:**
   - BDT 50,000 is approximately **$415 USD**.
   - Spreading BDT 50,000 across 8 divisions allocates **BDT 6,250 ($52 USD) per division** for an 8-month programme!
   - Look at the budget lines:
     - *Workshop refreshments for 8 hubs:* BDT 11,200 = **BDT 1,400 per workshop**. You cannot provide tea and biscuits for 20 people in a university hall for BDT 1,400.
     - *Ambassador local travel for 8 hubs:* BDT 12,000 = **BDT 1,500 per division over 8 months** (BDT 187/month)! That does not cover two rickshaw rides in Chittagong or Rajshahi.
   - Any seasoned evaluator will dismiss this as financial fantasy.

### The Winning Strategic Pivot:
* **The Architecture is National; the Pilot is Division-Anchored:**
  - Clearly state that the **Protiti software architecture, legal schema, and e-GD taxonomy are built to scale nationally across all 8 divisions** (which showcases technical depth and long-term UNDP alignment).
  - But explicitly state that the **BDT 50,000 Fellowship Seed Grant is 100% concentrated on a deep, high-impact pilot in ONE Home Division** (e.g., **Dhaka Division** covering DU, JU, Eden College, or **Rajshahi Division** targeting the off-campus "mess" dormitory crisis).
  - Re-allocate the BDT 50,000 to deliver **10 genuine, high-density campus activations**, 8 deeply supported ambassadors, and 5,000 wallet cards in your home division, with the remaining 7 divisions forming the **Phase 2 Expansion Roadmap** to be pitched at the February 2027 National Showcase!

---

## 🎯 Prioritized Action Plan: What the Team Must Do Next to Win

With **5 days remaining** until the September 30 deadline, the team must execute these surgical fixes:

### Immediate / Day 1 (Critical Pitch Deck & OPSEC Remediation):
1. **Eradicate Lethal UI Bugs in Flutter:**
   - Delete lines 62–76 in `dkc/lib/ui/features/vault/vault_screen.dart` (the `'DECOY MODE'` banner). Decoy mode must display identical stealth chrome.
   - Remove or guard the demo PIN informational banner in `dkc/lib/ui/features/auth/lock_screen.dart`.
2. **Synchronize & Finalize `pitch_materials/pitch_deck.md`:**
   - Purge all references to "Cyber Security Act" and replace with **"Cyber Protection Act, 2026"**.
   - Fill all bracketed placeholders in Slide 6 (Quote) and Slide 7 (Budget).
   - Align Slide 3 and Slide 5 with the offline-first architecture (remove "Cloud-based" claims).
   - Embed the finalized BDT 50,000 budget and the Home Division Pilot focus directly into Slide 7.

### Day 2–3 (Strategy & Budget Realignment):
3. **Restructure the BDT 50,000 Budget & GTM Strategy:**
   - Update `pitch_materials/budget_50k.md` and `pitch_materials/eight_divisions_rollout.md` to reflect the **"Home Division Pilot (BDT 50K) + National 8-Division Architectural Scale"** framework.
   - Ensure the budget provides realistic workshop catering and ambassador travel for your primary divisional anchors.
4. **Clarify e-GD & SMS Mechanics in Pitch Messaging:**
   - Prepare the pitch speaker for the inevitable judge questions: *"How does e-GD work without an open API?"* (Answer: Pre-formatted digital dossier with QR hash verification for physical Thana handover + direct PCSW escalation).
   - Address the SMS sending limitation transparently (or add a native background SMS plugin note for Android).

### Day 4–5 (Polishing & Submission Readiness):
5. **Add Basic Bengali String Assets in Flutter:**
   - At minimum, add a bilingual toggle or Bengali text strings for key error messages, buttons, and the 4-step GD wizard to prove accessibility.
6. **Package Submission Assets:**
   - Ensure the 8-slide pitch deck adheres strictly to the 8-slide limit specified in `DKC.md`.
   - Prepare the Google Form application narrative highlighting team diversity, gender balance, and divisional commitment.

---

## Final Evaluator Verdict

Project Protiti has the intellectual firepower, technical foundation, and legal sophistication to win the DKC Fellowship 2026. The move from an abstract concept to working Flutter code, statutory alignment, and trauma-informed design puts you in the top 5% of national applicants.

**Now eliminate the amateur mistakes.** Strip the "DECOY MODE" banner, fix your pitch deck placeholders, align with the fellowship's single-division grant rules, and present a bulletproof, street-smart defense. The fellowship is yours to lose.
