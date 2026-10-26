# R8 keep rules for release builds (R1-release). The default Android rules and each
# plug-in's consumer rules (flutter_local_notifications brings Gson's) apply as well.

# ONNX Runtime (com.microsoft.onnxruntime:onnxruntime-android, pulled in by
# onnxruntime_v2). The app calls the C API through Dart FFI, but the AAR's JNI library
# looks Java classes up by name, so keep them as ONNX Runtime's docs advise.
-keep class ai.onnxruntime.** { *; }
-keep class com.gtbluesky.onnxruntime.** { *; }

# flutter_local_notifications: the scheduled reminder is stored as JSON (Gson) and
# rebuilt after a reboot by the receivers declared in AndroidManifest.xml.
-keep class com.dexterous.** { *; }

# Flutter's deferred components reference Play Core classes the app does not use.
-dontwarn com.google.android.play.core.**
