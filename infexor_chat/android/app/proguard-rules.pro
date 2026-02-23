# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep annotations
-keepattributes *Annotation*

# Socket.io
-keep class io.socket.** { *; }

# OkHttp (used by some plugins)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Gson (if used by any plugin)
-keep class com.google.gson.** { *; }
-keepattributes Signature

# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }
-keep class id.flutter.flutter_background_service.BackgroundService { *; }

# Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Keep background entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
