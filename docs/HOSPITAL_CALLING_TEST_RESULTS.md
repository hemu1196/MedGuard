# MEDGUARD — Nearby Hospitals & Maps Calling Test Results

## 1. Scope of Verification
Verification of Features 4 and 5 regarding telephone number discovery, validation, and calling integration:
- OpenStreetMap Overpass live querying (`amenity=hospital`, `amenity=clinic`).
- Phone extraction from OSM metadata tags (`phone`, `contact:phone`).
- UI state handling for missing numbers ("Phone Unavailable" label, disabled button).
- Sanitization of real numbers and handoff to native dialer (`tel:`) via `url_launcher`.
- Complete absence of mock/fabricated phone numbers.

---

## 2. Test Cases & Execution Results

| Test ID | Location / Facility | Phone Returned by OSM | UI State | Dialer Handoff | Result |
|---|---|---|---|---|---|
| **CALL-01** | KG Hospital (Coimbatore) | `+91 422 221 2121` | "CALL HOSPITAL" button active; displays phone number | Opens Android dialer with `tel:+914222212121` | **PASS** |
| **CALL-02** | PSG Hospitals (Coimbatore) | `+91 422 434 5353` | "CALL HOSPITAL" button active; displays phone number | Opens Android dialer with `tel:+914224345353` | **PASS** |
| **CALL-03** | Rural Primary Health Center | `null` / empty | Displays "Phone unavailable"; button disabled | Button disabled; prevents unhandled launcher exceptions | **PASS** |
| **CALL-04** | Map Marker Bottom Sheet | Real hospital tapped on map | Phone displayed if available; "CALL HOSPITAL" button active | Launches system dialer immediately | **PASS** |
| **CALL-05** | Doctor / Clinic Appointment | Doctor phone entered by user | Phone icon on appointment card active | Dialing confirmed via `tel:$cleanPhone` | **PASS** |
| **CALL-06** | Browser / Web Environment | Click on Call Hospital on Web | Opens system telephony handler (`tel:`) without crashing | Handled gracefully by browser protocol handler | **PASS** |
