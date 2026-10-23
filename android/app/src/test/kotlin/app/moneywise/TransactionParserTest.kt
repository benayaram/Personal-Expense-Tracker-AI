package app.moneywise
import org.junit.Assert.*
import org.junit.Test
class TransactionParserTest {
    private fun parse(text: String) = TransactionParser.parse("com.phonepe.app", text, 1L, "key")
    @Test fun debitParsesExactPaise() {
        val value = parse("INR 1,250.05 debited at Zomato")!!
        assertEquals(125005L, value.paise); assertEquals("expense", value.kind); assertEquals("Zomato", value.merchant)
    }
    @Test fun creditParses() { assertEquals("income", parse("Rs. 60000 credited from Employer")!!.kind) }
    @Test fun rejectsFailuresAndRequests() {
        listOf("INR 500 payment failed", "INR 500 paid failed", "INR 500 requested", "OTP for INR 500 paid", "INR 500 debited and reversed").forEach { assertNull(parse(it)) }
    }
    @Test fun rejectsAmbiguousAndMissingAmounts() {
        assertNull(parse("INR 500 credited and debited")); assertNull(parse("Payment successful")); assertNull(parse("INR 0 paid")); assertNull(parse("INR 2.999 paid"))
    }
    @Test fun redeliveredNotificationHasStableId() {
        assertEquals(parse("INR 500 paid to Cafe")!!.id, parse("INR 500 paid to Cafe")!!.id)
        assertNotEquals(parse("INR 500 paid to Cafe")!!.id, parse("INR 600 paid to Cafe")!!.id)
    }
}
