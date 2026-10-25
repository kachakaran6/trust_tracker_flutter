package com.trusttracker.trust_tracker_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class SmsReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_FLUTTER = "FlutterSharedPreferences"
        const val PREF_KEY_FLUTTER = "flutter.sms_detection_enabled"
        const val PREF_KEY_DEFAULT = "sms_detection_enabled"
        const val PENDING_SMS_FILE = "sms_pending_queue.json"

        fun isDetectionEnabled(context: Context): Boolean {
            val prefs = context.getSharedPreferences(PREFS_FLUTTER, Context.MODE_PRIVATE)
            val flutterPref = prefs.getBoolean(PREF_KEY_FLUTTER, false)
            if (flutterPref) return true

            val defaultPrefs = context.getSharedPreferences(PREF_KEY_DEFAULT, Context.MODE_PRIVATE)
            return defaultPrefs.getBoolean(PREF_KEY_DEFAULT, false)
        }

        @Synchronized
        fun savePendingSms(context: Context, sender: String, body: String, timestamp: Long) {
            try {
                val file = File(context.filesDir, PENDING_SMS_FILE)
                val jsonArray = if (file.exists()) {
                    val content = file.readText()
                    if (content.isNotBlank()) JSONArray(content) else JSONArray()
                } else {
                    JSONArray()
                }

                val item = JSONObject().apply {
                    put("sender", sender)
                    put("body", body)
                    put("timestamp", timestamp)
                }
                jsonArray.put(item)
                file.writeText(jsonArray.toString())
            } catch (_: Exception) {
                // Fail-safe: privacy preservation prevents verbose logging
            }
        }

        @Synchronized
        fun readAndClearPendingSms(context: Context): List<Map<String, Any>> {
            val list = mutableListOf<Map<String, Any>>()
            try {
                val file = File(context.filesDir, PENDING_SMS_FILE)
                if (file.exists()) {
                    val content = file.readText()
                    if (content.isNotBlank()) {
                        val jsonArray = JSONArray(content)
                        for (i in 0 until jsonArray.length()) {
                            val obj = jsonArray.getJSONObject(i)
                            list.add(
                                mapOf(
                                    "sender" to obj.optString("sender"),
                                    "body" to obj.optString("body"),
                                    "timestamp" to obj.optLong("timestamp")
                                )
                            )
                        }
                    }
                    file.delete()
                }
            } catch (_: Exception) {
                // Fail-safe
            }
            return list
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        // Strict guard: verify user has explicitly enabled SMS detection
        if (!isDetectionEnabled(context)) {
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) {
            return
        }

        val sender = messages[0].displayOriginatingAddress ?: messages[0].originatingAddress ?: "UNKNOWN"
        val timestamp = messages[0].timestampMillis

        // Combine multipart messages safely
        val fullBodyBuilder = StringBuilder()
        for (msg in messages) {
            val part = msg.displayMessageBody ?: msg.messageBody
            if (!part.isNullOrEmpty()) {
                fullBodyBuilder.append(part)
            }
        }
        val fullBody = fullBodyBuilder.toString()

        // Quick filter: If it doesn't look like a potential transaction message, skip
        val lower = fullBody.lowercase()
        val hasFinancialKeywords = lower.contains("debit") ||
                lower.contains("credit") ||
                lower.contains("paid") ||
                lower.contains("spent") ||
                lower.contains("withdrawn") ||
                lower.contains("transferred") ||
                lower.contains("refund") ||
                lower.contains("revers") ||
                lower.contains("inr") ||
                lower.contains("rs.") ||
                lower.contains("upi")

        if (!hasFinancialKeywords) {
            return
        }

        // If Flutter engine is actively running, invoke method channel
        val channel = MainActivity.smsMethodChannel
        if (channel != null) {
            try {
                channel.invokeMethod(
                    "onSmsReceived",
                    mapOf(
                        "sender" to sender,
                        "body" to fullBody,
                        "timestamp" to timestamp
                    )
                )
                return
            } catch (_: Exception) {
                // Fallback to queue if channel invocation failed
            }
        }

        // App is not in foreground or engine not attached: store safely in local queue
        savePendingSms(context, sender, fullBody, timestamp)
    }
}
