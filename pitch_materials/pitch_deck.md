# Slide 1: Title & Hook
**Project Protiti (প্রতীতি)**
*"সন্দেহহীন সত্য, অকাট্য প্রমাণের অধিকার" / "From Doubt to Certitude: Structure for Digital Justice"*

**Team:** Team Protiti  
**Core Fellows (Bootcamp & Leadership):**  
- **Farzana Reza** — Team Lead, Operations, Pitching, Marketing, Research & Outreach (Acting UI/UX Lead)  
- **Abrar Masud** — AI & Systems Engineer (Acting Full-Stack / Flutter Dev Lead)  
- **Mithila Khan** — Legal Advisor & Statutory Compliance (cyber law / Evidence Act)  
**Reserve Fellows (Campaign Rollout):**  
- **Slot 4** — Dedicated UI/UX Designer (Interim: Farzana Reza)  
- **Slot 5** — Dedicated Flutter Developer (Interim: Abrar Masud)  

**DKC Fellowship Application — UNDP Bangladesh**  
**Theme 04:** Gender-based Online Violence | **Cross-cutting Lens:** Gender Equity  

**The Reality:** About 64% of the 359 women who completed a 2022 ActionAid Bangladesh online survey said they had faced online violence (not a national sample; [Prothom Alo, 28 Nov 2022](https://en.prothomalo.com/bangladesh/15il1p6qqq)).

**Status:** Research prototype. Not for real use: unsafe for survivors until reviewed by a security expert and a field partner.

*Visual Suggestion:* A stark, powerful visual of a fragmented digital screen assembling into a solid, protective frame. Deep Amethyst (#4A154B) background with sharp, glowing Teal (#008080) and Warm Gold (#FFC107) accents highlighting the statistics.

---

# Slide 2: The Problem (Chaos)
*Online violence creates chaos. Victims are left vulnerable without structure.*

- **Evidence Loss:** Victims delete messages/accounts out of fear, destroying crucial proof.
- **Legal Complexity:** General Diary (GD) filing and working out which cyber law applies are intimidating and confusing.
- **Metadata Gap:** Simple screenshots without dates, links and account names are easy to doubt.
- **Isolation:** Victims often don't know where to find trusted legal or mental health support.
- **Context:** In Bangladesh, social stigma and the digital divide amplify these issues, silencing victims before they can seek help.

*Visual Suggestion:* A collage of blurred, overlapping chat bubbles, legal documents, and red exclamation marks representing the overwhelming chaos and confusion faced by victims.

---

# Slide 3: The Solution — Protiti (Certitude)
*Providing a frame of safety to structure the path to justice.*

- **Secure Evidence Vault:** On-device encrypted SQLCipher storage with Duress PIN (Decoy Vault) for physical coercion scenarios.
- **GD draft:** A simple Q&A form that produces a General Diary draft PDF to file in person. No AI, no automatic law mapping, no e-GD integration.
- **Panic Frame:** One SMS SOS with your location, plus one-tap dialing for 999, 109 and the PCSW hotline.
- **Support Directory:** A list of hotlines, legal aid and counselling services. Partnerships with legal aid groups such as BLAST and BNWLA are proposed, not agreed.

*Visual Suggestion:* A clean, organized dashboard UI mockup showing the four main features neatly aligned within a structural "frame," emphasizing clarity and control.

---

# Slide 4: How It Works (User Journey)
*From Chaos to Clarity.*

1. **Capture:** Victim captures evidence (screenshot, link, text).
2. **Structure:** Protiti records the date, time and a SHA-256 file hash.
3. **Analyze:** User answers guided questions about the incident in a safe, trauma-informed interface.
4. **Formulate:** App generates a structured legal complaint (GD format).
5. **Action:** Share the PDF draft with police or a lawyer, or file it in person.

*Visual Suggestion:* A flowchart or a "Before & After" graphic. Left side: "Messy Chat" with erratic lines. Right side: Protiti processing it into a "Clean Legal Complaint" with straight, organized lines.

---

# Slide 5: Technology & Innovation
*Built for security. Designed for survival.*

- **On-device encryption:** Local SQLCipher storage on the phone. Nothing is uploaded.
- **Disguise Mode & Duress PIN:** Dual-PIN authentication opening a benign Decoy Vault under coercion, plus stealth calculator mask.
- **Hotline dialer:** One-tap calls to 999, 109 and the Police Cyber Support for Women (PCSW) hotline (`01320000888`).
- **Resilience:** Offline-first architecture ensures the vault, GD drafting, and SMS SOS dispatch work without active mobile internet.

*Visual Suggestion:* An isometric view of a smartphone. A padlock icon locking the screen, with binary code or a schematic overlay demonstrating the underlying robust architecture.

---

# Slide 6: Target Community & Impact
*Empowering those most at risk.*

- **Primary Users:** Female university and college students (18-30) facing digital harassment, blackmail, and deepfakes.
- **Secondary Stakeholders:** Police Cyber Support for Women (PCSW), Thana cyber desks, and legal aid clinics such as BLAST and BNWLA (proposed partners; none has agreed yet).
- **Goals** (aims, not measured results; no pilot has run):
  - Fewer survivors lose evidence by deleting it in panic.
  - More complete GD drafts that a duty officer can act on.
  - Faster contact with PCSW in extortion and deepfake cases.

> *The Evidence (Amendment) Act 2022 lets courts in Bangladesh consider digital records. Protiti aims to help survivors keep those records safe and organised. No lawyer has yet reviewed whether its output would be accepted in court.*

*Visual Suggestion:* A map of Bangladesh highlighting the 8 divisions with connecting nodes, alongside icons representing students, police, and legal clinics working together.

---

# Slide 7: Implementation Roadmap (8 Months)
*Structuring the rollout.*

- **Phase 1 (Months 1-3): Foundation & Legal Vetting**
  - Finalize on-device SQLCipher vault, Duress PIN, and GD draft template.
  - Proposed: ask a legal aid group (for example BLAST or BNWLA; nothing agreed) to review the evidence format, and run trauma-informed usability testing.
- **Phase 2 (Months 4-6): Dhaka Division Pilot & Campus Outreach**
  - "Train the Trainer" workshops across 5 Dhaka Division university dorms and student unions (DU, JU, Eden Mohila College, BRACU, NSU).
  - Distribute 5,000 discrete survivor toolkits and pocket safety guides.
- **Phase 3 (Months 7-8): National Roadmap & Showcase**
  - Pilot evaluation, policy showcase with Cyber Police Centre, and open-sourcing the GD draft template.
  - Present the audited Dhaka Pilot results alongside the (unfunded) National 8-Division Expansion Roadmap.
- **BDT 50,000 Seed Grant Allocation (Dhaka Division Pilot Only):**
  - Survivor Toolkits & Handbooks (16% | BDT 8,000)
  - Campus Workshop Logistics — 10 Activations (40% | BDT 20,000)
  - Ambassador Ground Logistics & Travel (24% | BDT 12,000)
  - Hotline Triage Connectivity (12% | BDT 6,000)
  - Audit & National Roadmap Prep (8% | BDT 4,000)
  - *Strictly BDT 0 spent on stipends or personal honoraria.*

*Visual Suggestion:* A clear, structured timeline or Gantt chart moving from left to right, transitioning from dark (development) to light (launch/impact).

---

# Slide 8: Sustainability & Call to Action
*A lasting frame for digital safety.*

- **Adaptability:** Open-source legal templates that the community can update as laws evolve.
- **Scalability:** The Protiti architecture can expand to cover financial fraud, hate speech, and minority protection.
- **Proposed partnerships:** PCSW, legal aid NGOs and the ICT Division's "Cyber Help" initiatives. None has agreed yet.

**Call to Action:**
**"Every woman deserves a frame of safety. Help us build the structure for justice."**

*Visual Suggestion:* A strong, empowering photograph of a woman looking forward confidently, overlaid with the Protiti logo and the final call to action in bold typography.
