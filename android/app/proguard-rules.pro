# Flutter Local Notifications & Gson R8 / ProGuard Rules

# 1. Preserve Generic Signatures for Gson TypeToken deserialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# 2. Gson Serialization & Deserialization
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 3. Flutter Local Notifications Plugin & Receivers
-dontwarn com.dexterous.flutterlocalnotifications.**
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep public class com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver { *; }
-keep public class com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver { *; }
-keep public class com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver { *; }

# 4. AndroidX Notification Compat
-dontwarn androidx.core.app.**
-keep class androidx.core.app.NotificationCompat** { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }
