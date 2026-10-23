package app.moneywise

import java.math.BigDecimal
import java.security.MessageDigest

/** Conservative INR parser: ambiguous notifications remain manual entries. */
data class Candidate(val id: String, val merchant: String, val paise: Long, val kind: String, val timestamp: Long)
object TransactionParser {
    private val amountPattern = Regex("(?:₹|INR|Rs\\.?)\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)(?![0-9.])", RegexOption.IGNORE_CASE)
    private val income = Regex("\\b(credited|received|deposited)\\b", RegexOption.IGNORE_CASE)
    private val expense = Regex("\\b(debited|paid|spent|withdrawn)\\b", RegexOption.IGNORE_CASE)
    private val rejection = Regex("\\b(failed|declined|unsuccessful|reversed|reversal|request|requested|OTP|verification|reminder|due)\\b", RegexOption.IGNORE_CASE)
    private val merchantPattern = Regex("\\b(?:at|to|from)\\s+([\\p{L}0-9 &._-]{2,60})", RegexOption.IGNORE_CASE)
    fun parse(packageName: String, text: String, timestamp: Long, notificationKey: String): Candidate? {
        if (text.length > 8000 || rejection.containsMatchIn(text)) return null
        val isIncome = income.containsMatchIn(text)
        val isExpense = expense.containsMatchIn(text)
        if (isIncome == isExpense) return null
        val amount = amountPattern.find(text)?.groupValues?.get(1) ?: return null
        val numeric = amount.replace(",", "")
        val paise = try { BigDecimal(numeric).movePointRight(2).longValueExact() } catch (_: Exception) { return null }
        if (paise <= 0 || paise > 99999999999L) return null
        val merchant = merchantPattern.find(text)?.groupValues?.get(1)?.trim()?.take(60) ?: "Payment alert"
        // Include event text so a reused notification slot can represent a new transaction.
        val digest = MessageDigest.getInstance("SHA-256").digest("$packageName|$notificationKey|$text".toByteArray())
        val id = digest.joinToString("") { "%02x".format(it) }
        return Candidate(id, merchant, paise, if (isIncome) "income" else "expense", timestamp)
    }
}
