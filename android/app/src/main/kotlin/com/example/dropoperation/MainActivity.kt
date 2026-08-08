package com.example.dropoperation

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "drop/notifications"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                getString(R.string.default_notification_channel_id),
                "DROP notifications",
                NotificationManager.IMPORTANCE_HIGH,
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    // Bridge for clearing delivered chat notifications (WhatsApp-style) when a
    // conversation is opened + read. FCM posts each chat message with
    // tag = conversationId (see the backend chat-push subscriber), so a
    // conversation's notifications are dismissible as a group by that tag.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "clearConversation" -> {
                        val conversationId = call.argument<String>("conversationId")
                        if (conversationId.isNullOrEmpty()) {
                            result.error("bad_args", "conversationId required", null)
                        } else {
                            clearConversation(conversationId)
                            result.success(null)
                        }
                    }
                    "clearAll" -> {
                        notificationManager().cancelAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun clearConversation(conversationId: String) {
        // getActiveNotifications is API 23+; below that we can't match a tag, so
        // there is nothing to clear precisely (rare on supported devices).
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val manager = notificationManager()
        for (sbn in manager.activeNotifications) {
            if (sbn.tag == conversationId) {
                manager.cancel(sbn.tag, sbn.id)
            }
        }
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
