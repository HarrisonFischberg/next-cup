package app.rarecreatures.nextcup.ai

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import app.rarecreatures.nextcup.data.AIProvider
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The user's Anthropic and OpenAI keys, encrypted with an AES-GCM key that lives in the Android Keystore and
 * never leaves it (the stand-in for iOS's Keychain). The ciphertext sits in `secrets.xml`, which backups exclude.
 */
class Secrets(context: Context) {
    private val prefs = context.getSharedPreferences("secrets", Context.MODE_PRIVATE)

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
        }.generateKey()
    }

    fun key(provider: AIProvider): String? {
        val stored = prefs.getString(provider.raw, null) ?: return null
        return runCatching {
            val bytes = Base64.getDecoder().decode(stored)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes, 0, IV_SIZE))
            String(cipher.doFinal(bytes, IV_SIZE, bytes.size - IV_SIZE))
        }.getOrNull()
    }

    fun hasKey(provider: AIProvider) = provider == AIProvider.ON_DEVICE || key(provider) != null

    fun setKey(provider: AIProvider, value: String) {
        val trimmed = value.trim()
        if (trimmed.isEmpty()) return removeKey(provider)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val sealed = cipher.iv + cipher.doFinal(trimmed.toByteArray())
        prefs.edit().putString(provider.raw, Base64.getEncoder().encodeToString(sealed)).apply()
    }

    fun removeKey(provider: AIProvider) = prefs.edit().remove(provider.raw).apply()

    fun clearAll() = prefs.edit().clear().apply()

    companion object {
        private const val ALIAS = "nextcup.ai.keys"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_SIZE = 12
    }
}
