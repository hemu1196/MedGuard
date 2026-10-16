package com.example.med_ai

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        // Compile-time reference to ensure AAPT/R8 keeps the notification drawable
        val notificationIconRes = R.drawable.ic_notification
    }
}
