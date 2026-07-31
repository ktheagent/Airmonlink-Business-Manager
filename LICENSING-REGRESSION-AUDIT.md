# Licensing regression audit

Build 8 retains the Build 6 `LicenseController`, licence service, licence screen and status badge implementation. Commercial database migrations do not alter licence secure-storage keys or the server contract.

Existing source tests cover:

- explicit first trial
- repeated trial non-extension
- restart persistence
- expired-trial persistence
- paid activation replacing trial
- revocation persistence offline
- real response-field aliases

Source preservation scan: **PASS**  
Flutter execution: **MISSING**  
Live licence-server validation: **MISSING**
