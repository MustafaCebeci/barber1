// services/notification.service.js
const crypto = require("crypto");
const { pool } = require("./models");
const { getMailer, env } = require("./config");

// SMS Provider (MesajPaneli)
const {
    CredentialsUsernamePassword,
    MesajPaneliApi,
    TopluMesaj,
} = require("./MesajPaneliApi.js");

// --- OTP yardımcıları ---
function generateOtpCode() {
    return String(Math.floor(100000 + Math.random() * 900000));
}

function sha256(input) {
    return crypto.createHash("sha256").update(String(input)).digest("hex");
}

function otpMessage(code) {
    return `Giriş kodun: ${code}. Bu kod 1 dakika geçerlidir.`;
}

/**
 * DB: otp_codes kaydı oluştur
 * user_type: 'staff_account' | 'customer'
 * channel: 'email' | 'sms'
 * otp_ttl_seconds: Ayarlardan çekilecek veya varsayılan 60 saniye
 */
async function createOtpRecord({
    user_type,
    user_id,
    channel,
    destination,
    code,
    ttlSeconds = null, // Varsayılan artık null, ayarlardan çekilecek
}) {
    // Settings'den OTP TTL çek
    let otpTtl = 60;
    try {
        const [rows] = await pool.execute(
            `SELECT settings_json FROM app_settings LIMIT 1`
        );
        if (rows.length > 0) {
            const settings = JSON.parse(rows[0].settings_json || "{}");
            otpTtl = settings.otp_ttl_seconds ?? 60;
        }
    } catch (err) {
        console.error("[OTP] Settings okuma hatası, varsayılan kullanılıyor:", err.message);
    }

    const effectiveTtl = ttlSeconds ?? otpTtl;
    const code_hash = sha256(code);

    await pool.execute(
        `INSERT INTO otp_codes (user_type, user_id, channel, destination, code_hash, expires_at)
     VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))`,
        [user_type, user_id, channel, destination, code_hash, effectiveTtl]
    );

    return { code_hash };
}

/**
 * DB: sms_messages logla (OTP)
 * - scheduled_at zorunlu
 * - type enum: 'otp'
 */
async function logSmsToDb({
    appointment_id = null,
    to_phone,
    body,
    type = "otp",
    provider = "mesajpaneli",
    status = "sent",
    provider_msg_id = null,
    error_message = null,
}) {
    await pool.execute(
        `INSERT INTO sms_messages
      (appointment_id, to_phone, type, body, provider, status, provider_msg_id, error_message, scheduled_at, sent_at)
     VALUES
      (?, ?, ?, ?, ?, ?, ?, ?, NOW(), CASE WHEN ? = 'sent' THEN NOW() ELSE NULL END)`,
        [appointment_id, to_phone, type, body, provider, status, provider_msg_id, error_message, status ]
    );
}

/**
 * MAIL gönder
 */
async function sendMail({ to, subject, text }) {
    console.log("[GÖNDERİLEN MAIL]", { to, subject, text });
    const transporter = await getMailer();
    await transporter.sendMail({
        from: `"Berberler" <${env("GMAIL_USER")}>`,
        to,
        subject,
        text,
    });
}

/**
 * SMS API instance (paket kullanım stiliyle)
 */
function createSmsApi() {
    const user = env("SMS_USER", "");
    const pass = env("SMS_PASS", "");
    const endpoint = env("SMS_ENDPOINT", "https://api.mesajpaneli.com/json_api/api");

    // Sertifika hatası alırsan env: SMS_VERIFY_SSL=false
    const verifySSL = String(env("SMS_VERIFY_SSL", "true")).toLowerCase() !== "false";

    const credentials = new CredentialsUsernamePassword(user, pass);

    return new MesajPaneliApi(credentials, {
        endpoint,
        verifySSL,
        timeout: 50_000,
    });
}

/**
 * SMS gönder (GERÇEK)
 * - MesajPaneliApi + TopluMesaj kullanım stili
 * - sms_messages loglar
 */
async function sendSms({ appointment_id = null, phone, message, type = "otp" }) {
    const smsApi = createSmsApi();

    const baslik = env("SMS_BASLIK", "TBS AV.ORT.");

    // "05xxxxxxxxx" veya "5xxxxxxxxx" formatı sende nasıl ise onu gönder.
    // Senin örnek: 5467473915 (başında 0 yok) -> aynen geçiyoruz.
    const mesaj = new TopluMesaj(message, phone);

    try {
        const resp = await smsApi.topluMesajGonder(baslik, mesaj);

        // provider id alanı API'de farklı isimde olabilir. Yine de loglayalım:
        const providerMsgId =
            resp?.msg_id ?? resp?.message_id ?? resp?.id ?? resp?.data?.id ?? null;

        await logSmsToDb({
            appointment_id,
            to_phone: phone,
            body: message,
            type,
            provider: "mesajpaneli",
            status: "sent",
            provider_msg_id: providerMsgId,
            error_message: null,
        });

        return resp;
    } catch (e) {
        const errText = e?.message || String(e);

        await logSmsToDb({
            appointment_id,
            to_phone: phone,
            body: message,
            type,
            provider: "mesajpaneli",
            status: "failed",
            provider_msg_id: null,
            error_message: errText,
        });

        throw new Error(errText);
    }
}

/**
 * Tek fonksiyon: OTP üret + DB kaydet + uygun kanaldan gönder
 *
 * Branch account => email
 * Customer => sms
 *
 * DÖNÜŞ: { ok, channel, codeSent }
 */
async function sendOtp({ user_type, user_id, destinationOverride = null }) {
    if (user_type !== "staff_account" && user_type !== "customer") {
        throw new Error("user_type sadece 'staff_account' veya 'customer' olabilir.");
    }

    const destination = destinationOverride;
    if (!destination) throw new Error("destinationOverride zorunlu (email veya phone).");

    // Tüm user_type'lar için SMS kanalı (destination phone ise)
    const channel = destination.includes("@") ? "email" : "sms";

    const code = generateOtpCode();

    await createOtpRecord({
        user_type,
        user_id,
        channel,
        destination,
        code,
        ttlSeconds: 60,
    });

    const message = otpMessage(code);

    if (channel === "email") {
        await sendMail({ to: destination, subject: "Giriş Kodu", text: message });
    } else {
        await sendSms({ phone: destination, message, type: "otp" });
    }

    return { ok: true, channel, codeSent: code };
}

/**
 * OTP doğrula
 */
async function verifyOtp({ user_type, user_id, code, maxTries = 5 }) {
    const code_hash = sha256(code);

    const [rows] = await pool.execute(
        `SELECT id, code_hash, expires_at, used, try_count
     FROM otp_codes
     WHERE user_type = ? AND user_id = ?
     ORDER BY id DESC
     LIMIT 1`,
        [user_type, user_id]
    );

    const rec = rows[0];
    if (!rec) return { ok: false, reason: "no_code" };
    if (rec.used) return { ok: false, reason: "used" };

    const now = new Date();
    const exp = new Date(rec.expires_at);
    if (exp <= now) return { ok: false, reason: "expired" };

    if (rec.try_count >= maxTries) return { ok: false, reason: "too_many_tries" };

    await pool.execute(`UPDATE otp_codes SET try_count = try_count + 1 WHERE id = ?`, [rec.id]);

    if (rec.code_hash !== code_hash) return { ok: false, reason: "invalid" };

    await pool.execute(`UPDATE otp_codes SET used = 1, used_at = NOW() WHERE id = ?`, [rec.id]);

    return { ok: true };
}

module.exports = {
    // OTP
    sendOtp,
    verifyOtp,

    // dışarı aç
    createOtpRecord,
    generateOtpCode,
    sha256,

    // sms/email
    sendSms,
    sendMail,
};
