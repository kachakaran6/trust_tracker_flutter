package com.trusttracker.trust_tracker_flutter

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val QUICK_ACTION_CHANNEL = "com.trusttracker/quick_action"
    private val SMS_CHANNEL = "com.trusttracker/sms_detection"
    private val SMS_PERMISSION_REQUEST_CODE = 4101
    private val READ_SMS_PERMISSION_REQUEST_CODE = 4102

    private var quickActionChannel: MethodChannel? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingReadPermissionResult: MethodChannel.Result? = null

    companion object {
        var smsMethodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Quick action channel
        quickActionChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QUICK_ACTION_CHANNEL)

        // SMS detection channel
        val smsChan = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
        smsMethodChannel = smsChan

        smsChan.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "isSmsDetectionSupported" -> {
                    result.success(true)
                }
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECEIVE_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECEIVE_SMS),
                            SMS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "checkReadSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestReadSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    if (granted) {
                        result.success(true)
                    } else {
                        pendingReadPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            READ_SMS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "readHistoricalSms" -> {
                    try {
                        val hasPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!hasPermission) {
                            result.error("PERMISSION_DENIED", "READ_SMS permission is not granted", null)
                            return@setMethodCallHandler
                        }

                        val days = call.argument<Int>("days") ?: 30
                        val uri = Telephony.Sms.Inbox.CONTENT_URI
                        val projection = arrayOf(
                            Telephony.Sms.ADDRESS,
                            Telephony.Sms.BODY,
                            Telephony.Sms.DATE
                        )

                        val selection: String?
                        val selectionArgs: Array<String>?
                        if (days > 0) {
                            val cutoffTime = System.currentTimeMillis() - (days.toLong() * 24L * 60L * 60L * 1000L)
                            selection = "${Telephony.Sms.DATE} >= ?"
                            selectionArgs = arrayOf(cutoffTime.toString())
                        } else {
                            selection = null
                            selectionArgs = null
                        }

                        val messages = mutableListOf<Map<String, Any?>>()
                        val cursor = contentResolver.query(
                            uri,
                            projection,
                            selection,
                            selectionArgs,
                            "${Telephony.Sms.DATE} DESC"
                        )

                        cursor?.use {
                            val addressIndex = it.getColumnIndex(Telephony.Sms.ADDRESS)
                            val bodyIndex = it.getColumnIndex(Telephony.Sms.BODY)
                            val dateIndex = it.getColumnIndex(Telephony.Sms.DATE)

                            var count = 0
                            val maxLimit = 1000 // bounded to avoid memory exhaustion
                            while (it.moveToNext() && count < maxLimit) {
                                val address = if (addressIndex != -1) it.getString(addressIndex) else ""
                                val body = if (bodyIndex != -1) it.getString(bodyIndex) else ""
                                val date = if (dateIndex != -1) it.getLong(dateIndex) else System.currentTimeMillis()

                                if (!body.isNullOrBlank()) {
                                    messages.add(
                                        mapOf(
                                            "sender" to (address ?: ""),
                                            "body" to body,
                                            "timestamp" to date
                                        )
                                    )
                                    count++
                                }
                            }
                        }

                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("READ_SMS_ERROR", e.message, null)
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("APP_SETTINGS_ERROR", e.message, null)
                    }
                }
                "setSmsDetectionEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val flutterPrefs = getSharedPreferences(SmsReceiver.PREFS_FLUTTER, Context.MODE_PRIVATE)
                    flutterPrefs.edit().putBoolean(SmsReceiver.PREF_KEY_FLUTTER, enabled).apply()

                    val defaultPrefs = getSharedPreferences(SmsReceiver.PREF_KEY_DEFAULT, Context.MODE_PRIVATE)
                    defaultPrefs.edit().putBoolean(SmsReceiver.PREF_KEY_DEFAULT, enabled).apply()

                    result.success(true)
                }
                "pollPendingNativeSms" -> {
                    val list = SmsReceiver.readAndClearPendingSms(this)
                    result.success(list)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Check initial intent
        handleIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(isGranted)
            pendingPermissionResult = null
        } else if (requestCode == READ_SMS_PERMISSION_REQUEST_CODE) {
            val isGranted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingReadPermissionResult?.success(isGranted)
            pendingReadPermissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("quick_add", false) == true) {
            quickActionChannel?.invokeMethod("quickAddExpense", null)
            intent.removeExtra("quick_add")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        smsMethodChannel = null
    }
}
