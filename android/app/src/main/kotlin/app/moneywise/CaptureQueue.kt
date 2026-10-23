package app.moneywise

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Keystore encrypted, bounded queue. Never log notification text or candidates. */
object CaptureQueue {
    private const val ALIAS = "moneywise.capture.v1"
    private fun prefs(c: Context) = c.getSharedPreferences("capture", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun read(c: Context): JSONObject {
        val value = prefs(c).getString("queue", null) ?: return JSONObject().put("items", JSONArray()).put("seen", JSONArray())
        val parts = value.split(":")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)))
        return JSONObject(String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8))
    }
    private fun write(c: Context, data: JSONObject) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val value = Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(cipher.doFinal(data.toString().toByteArray()), Base64.NO_WRAP)
        check(prefs(c).edit().putString("queue", value).commit()) { "Capture persistence failed" }
    }
    @Synchronized fun add(c: Context, v: Candidate) {
        if (prefs(c).getBoolean("paused", false)) return
        val data = read(c)
        val seen = data.getJSONArray("seen")
        if ((0 until seen.length()).any { seen.getString(it) == v.id }) return
        val items = data.getJSONArray("items")
        if (items.length() >= 250) return // Retain existing candidates; never silently evict unreviewed data.
        items.put(JSONObject().put("id", v.id).put("merchant", v.merchant).put("paise", v.paise).put("kind", v.kind).put("timestamp", v.timestamp))
        seen.put(v.id)
        while (seen.length() > 2000) seen.remove(0)
        write(c, data)
    }
    @Synchronized fun pending(c: Context): String = read(c).getJSONArray("items").toString()
    @Synchronized fun ack(c: Context, id: String) {
        val data = read(c); val items = data.getJSONArray("items")
        for (i in items.length() - 1 downTo 0) if (items.getJSONObject(i).getString("id") == id) items.remove(i)
        write(c, data)
    }
    @Synchronized fun clear(c: Context) { check(prefs(c).edit().clear().putBoolean("paused", true).commit()) }
    @Synchronized fun resume(c: Context) { check(prefs(c).edit().putBoolean("paused", false).commit()) }
}
