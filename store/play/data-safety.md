# Google Play: Data safety form answers

Answer the Play Console form (App content > Data safety) as below. The app has no
network code at runtime, no analytics, no crash reporting and no ads. The only network
use is the optional one-time download of the full speech model from GitHub Releases;
that request carries no user data.

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not applicable (nothing collected) |
| Do you provide a way for users to request that their data is deleted? | Not applicable; Settings > Delete my data erases everything on the phone, and uninstalling removes it |
| Data types (all 14 categories: location, personal info, financial, health, messages, photos/videos, audio files, files and docs, calendar, contacts, app activity, web browsing, app info and performance, device or other IDs) | **None collected, none shared** |

Notes for the reviewer field, if asked:

- Voice recordings are processed on the device and never leave it. Google treats data
  that is only processed on-device and never sent off the device as not collected.
- "Send feedback" opens the user's own email app with a draft. The user chooses whether
  to attach an exported progress file and presses send themselves. The app uploads nothing.
- The model download (full tier only, optional) is a plain file download.

Other Play forms

- Permissions declared: `RECORD_AUDIO` (read aloud and score), `POST_NOTIFICATIONS`
  (optional daily practice reminder), `RECEIVE_BOOT_COMPLETED` (re-schedule that reminder after a restart), `INTERNET` and `ACCESS_NETWORK_STATE` (model download only). Check the merged
  manifest before submitting and declare exactly what it lists.
- Content rating: IARC questionnaire, no user-generated content, no violence, no
  purchases. Expected: Everyone / PEGI 3.
- Target audience: 13 and over (general learners). Not designed for children, so no Families policy.
- Ads: No. Government app: No. Financial features: None. Health features: None.
- Privacy policy URL: required by Play for apps that use the microphone. Use https://idawud.github.io/UK-Pronunciation-Coach/privacy/
  (built from `store/privacy-policy.md` by `.github/workflows/pages.yml`; works once Pages is on, see `docs/release.md`).
