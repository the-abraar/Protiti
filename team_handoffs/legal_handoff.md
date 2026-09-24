# Legal Handoff: Anti-Harassment App (Bangladesh)

**Date:** September 25, 2026
**To:** Product, Engineering, and Design Teams
**From:** Legal Advisor

## 1. Current Legal Landscape (As of 2026)
It is crucial for the team to understand that the **Cyber Security Act, 2023** (which replaced the Digital Security Act, 2018) has been **repealed**. 
The prevailing law in Bangladesh is now the **Cyber Protection Act, 2026**.
*   **Key Provisions:** The 2026 Act specifically addresses and criminalizes digital blackmail, sexual harassment, revenge pornography, sextortion, and the distribution of obscene content, including altered or **AI-generated (deepfake)** imagery.
*   **Pornography Control Act, 2012:** This act may also apply concurrently in cases of non-consensual distribution of explicit images.

## 2. Legal Logic and Features Needed in the App
To effectively support victims in Bangladesh, the app must incorporate the following legal workflows and features:

*   **Evidence Preservation (Crucial):**
    *   *Feature:* The app must guide users to securely capture and store evidence (screenshots, URLs, raw media) *before* they block the abuser or report the content to the platform. 
    *   *Reasoning:* Law enforcement requires unaltered digital evidence. If a user deletes the chat or the platform removes it before capture, the legal case is severely weakened.
    *   *Metadata:* If possible, capture timestamps, URLs, and platform metadata automatically.
*   **Automated GD Generation:**
    *   *Feature:* A tool to automatically populate the standard General Diary (GD) format in both English and Bengali based on a questionnaire the user fills out. 
    *   *Reasoning:* Many victims do not know how to write a GD. Providing a ready-to-print or ready-to-upload PDF significantly lowers the barrier to seeking police help.
*   **Online Police Integration:**
    *   *Feature:* Direct links or API integration (if possible) to the Bangladesh Police's Online GD portal (`gd.police.gov.bd`).
    *   *Reasoning:* Filing online is safer and less intimidating for many victims, especially women.
*   **Triage and Emergency Protocols:**
    *   *Feature:* In-app emergency buttons linking directly to **999** (National Emergency Service) and the **Police Cyber Support for Women (PCSW)** hotline (**01320000888**).
*   **Information Security & Privacy:**
    *   *Feature:* End-to-end encryption for the user's stored evidence and complete anonymity options within the app.
    *   *Reasoning:* The app will handle highly sensitive personal data. A data breach could re-victimize users and expose the company to legal liability.

## 3. Potential Legal Risks for the App

*   **Data Privacy & Security Liability:** If the app stores sensitive user data (like revenge porn images as evidence), a breach would have catastrophic legal and reputational consequences. *Recommendation:* Minimize cloud storage of sensitive evidence; heavily encrypt any data stored; encourage local (on-device) secure storage.
*   **Providing "Legal Advice":** The app must clearly state that it provides legal *information* and *tools*, not legal *advice*. 
    *   *Mitigation:* Implement mandatory disclaimers and terms of service stating that the company does not guarantee legal outcomes and users should consult qualified attorneys for specific cases.
*   **Defamation Risks:** If the app allows users to publicly "name and shame" abusers, the platform could be held liable for defamation under the Cyber Protection Act if the claims are false.
    *   *Mitigation:* The app should focus on reporting to authorities and platforms, *not* public broadcasting of accusations.

## 4. Recommendations for Next Steps
1.  **Review the Cyber Protection Act, 2026:** Product managers need to read a translated summary of Section 25 and Section 40 to understand the exact definitions of the crimes we are combatting.
2.  **UX Review of GD Feature:** Design a seamless flow that takes a stressed, traumatized user from "incident" to "generated GD document" in under 5 minutes.
3.  **Data Localization:** Ensure compliance with any data localization requirements in Bangladesh regarding the storage of citizen data.
