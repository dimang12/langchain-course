# Web Coding — Feature Roadmap (Wrap-Up)

**Owner:** Dima
**Status:** In Progress — Final Features Before Wrap-Up

---

## Overview

This roadmap covers the remaining features needed to complete the current phase of the Web Coding tool. The goal is to finalize core functionality around file uploads, model/CSTP integration, action payloads, and conflict handling before shifting focus to the API-driven deployment workflow.

---

## Feature 1: File Upload + Model & CSTP Integration

**Priority:** High

After a user uploads a file, the system should automatically connect to the relevant models and hook into the appropriate CSTPs. Specifically:

- On file upload, detect the data structure and bind it to the corresponding CSTP model.
- By default, call the **STP that updates data** (e.g., `stp.call` for data update operations).
- Also connect to the **CSTP that provides user recommendations** within the chatbot interface.
- Ensure that file upload triggers the correct STP pipeline without requiring manual configuration from the user.

**Acceptance Criteria:**

- Uploaded file is automatically linked to the data-update STP.
- Recommendation CSTP is available in the chatbot after upload.
- No manual model/CSTP selection required for default use cases.

---

## Feature 2: Action Payload — Attach Only User-Selected Data

**Priority:** High

Every time a user performs an action (e.g., clicking a button, submitting a form, triggering an event), the system should attach **only the payload data that the user intends to send** — not the entire dataset or extraneous fields.

- Filter the payload to include only the relevant data fields tied to the specific action.
- Ensure the payload structure matches what the receiving STP or model expects.
- Provide a way for users to confirm or adjust which data is included before submission.

**Acceptance Criteria:**

- Actions send only the selected/relevant payload data.
- No unnecessary or unrelated data is included in the request.
- Payload structure aligns with the target STP's expected input format.

---

## Feature 3: Conflict Handling on File Upload — Save to Server Shared Folder

**Priority:** High

When a user uploads data that has conflicting structures (e.g., mismatched columns, duplicate keys, incompatible schemas), the system should handle the conflict gracefully:

- Detect structural conflicts between the uploaded data and the existing data model.
- Instead of overwriting or failing silently, **save the conflicting file to the server's web-sharing folder** for review.
- Notify the user that a conflict was detected and the file has been saved to the shared folder.
- Allow the user to resolve the conflict manually or choose to merge/overwrite.

**Acceptance Criteria:**

- Structural conflicts are detected automatically on upload.
- Conflicting files are saved to the designated server web-sharing folder.
- User receives a clear notification about the conflict and file location.
- No data is lost or silently overwritten.

---

## Summary

| # | Feature | Priority | Status |
|---|---------|----------|--------|
| 1 | File Upload + Model & CSTP Integration | High | To Do |
| 2 | Action Payload — User-Selected Data Only | High | To Do |
| 3 | Conflict Handling — Save to Shared Folder | High | To Do |

---

*Note: These features represent the wrap-up items for the current Web Coding tool phase. After completion, the team's focus will shift toward the API-driven deployment workflow as discussed in the recent strategy meeting.*
