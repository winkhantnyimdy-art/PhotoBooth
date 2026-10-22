## Permission audit (release APK, aapt2 dump badging)
| Permission | Why | Runtime? |
| --- | --- | --- |
| CAMERA | Taking photos | Yes (platform dialog) |
| WRITE_EXTERNAL_STORAGE (maxSdkVersion=28) | Legacy storage on Android 7-9 | No on API 29+ (MediaStore) |
| READ_EXTERNAL_STORAGE (maxSdkVersion=28) | Transitive, inert on modern Android | No |
| ACCESS_NETWORK_STATE | Transitive from media deps; app makes no network calls | No |
| com.photobooth.photo_booth.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | App-internal, AndroidX component isolation | No |

Deliberately removed: RECORD_AUDIO (enableAudio: false), unscoped READ_EXTERNAL_STORAGE (tools:node=remove). No analytics/ads/tracking/cloud. Offline-first preserved.
