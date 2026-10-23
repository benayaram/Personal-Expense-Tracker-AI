package app.moneywise

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class TransactionNotificationService : NotificationListenerService() {
    private val supported = setOf("com.google.android.apps.nbu.paisa.user", "com.phonepe.app", "net.one97.paytm",
        "com.sbi.lotusintouch", "com.axis.mobile", "com.snapwork.hdfc", "com.csam.icici.bank.imobile")
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in supported || (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val candidate = TransactionParser.parse(sbn.packageName, "$title $body", sbn.postTime, sbn.key) ?: return
        try { CaptureQueue.add(this, candidate) } catch (_: Exception) {
            // Fail closed: no plaintext fallback, no notification content in logs.
        }
    }
}
