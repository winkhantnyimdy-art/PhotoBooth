## Clean install results
Performed on isolated AVD Medium_Phone_RC (android-37.2 google_apis_playstore x86_64). Fresh data partition.

| Step | Result |
| --- | --- |
| Install | Success (streamed) |
| First launch | Cold launch, cream splash -> Home, no crash |
| Permission request | Camera permission dialog appeared; granted; camera initialized on "Try again" |
| Camera startup | Viewfinder live |
| Capture | 4-shot sequence at 3s countdown |
| Review | Review grid + "Photo 4 of 4 selected" |
| Decorate | Editor opened; effects/frames/stickers/text/adjust reachable |
| Export | Ready! screen rendered |
| Save | Save to Photos + Save to album both succeeded |
| Album | Grid populated with new session |
| App restart | Covered by upgrade test |

Screenshots: docs/v3/screenshots/checkpoint-7/01..11 (from the release APK).
