/**
 * ══════════════════════════════════════════════════════════════
 *  Licensing Configuration & Constants
 *  ReportCraft Enterprise Mobile Client Integration
 * ══════════════════════════════════════════════════════════════
 *  المتغيرات الثابتة ونقاط النهاية المتوافقة مع licenses_project
 */

class LicensingConstants {
  // ─── رابط سيرفر التراخيص المركزي القائم ───
  // يمكن تغييره في بيئة التطوير أو الإنتاج
  static const String defaultServerUrl = 'https://mikrofixye.cloud';
  
  // ─── مفتاح API الخاص بالمنتج (X-API-Key) ───
  // يطابق apiKey لمنتج ReportCraft في خادم التراخيص
  static const String defaultApiKey = 'b4a5eb196cc8abf389e906464298795c7428cb3a28cf788ca718309fb5bfa650';

  // ─── المفتاح العام المعتمد للمنتج (RSA-2048 Public Key) ───
  static const String embeddedPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoXyWpEaZBKxekdSR2YxU
M9oyczcMiAY5aYWetCvGTKJK7BWmTqVuV3ApsJm3xXgaxWqN6P2FOZ/Ma1CZmG10
Nn0tYYAO/3yu8CyGrcDH4vTcfHztPZ8jX23YyAkQSDBr9b6tvp936AqF0lI0VF7H
JWDDG8UQ3XJ2dreFXGlh6ho84N3Mx4vE/d8r2tHb6BowgeutS24HY1LS5BiAg54N
zmbATMCMMesy+UVooa9ULIfJbEF4KLLw1nv95hWJx6rYyTbhSdmcGECWXEDUNIZd
wad5tvzKdvBK5FHH8428Ahd5rurwn9Q/t9rmPzrgMnpGwTcHmK2V2/dU5rdewEmh
TwIDAQAB
-----END PUBLIC KEY-----''';

  // ─── قواعد النسخة التجريبية (TRIAL) المعتمدة ───
  static const int trialMaxReports = 15;        // سقف الـ 15 تقريراً
  static const int trialDurationDays = 60;      // مهلة الـ 60 يوماً

  // ─── نقاط النهاية القياسية القائمة في licenses_project ───
  static const String endpointActivate    = '/api/v1/license/activate';
  static const String endpointTrial       = '/api/v1/license/trial';
  static const String endpointPing        = '/api/v1/ping';
  static const String endpointSync        = '/api/sync-license';
  static const String endpointStatus      = '/api/v1/license/status';
  static const String endpointTime        = '/api/v1/time';
  static const String endpointRequests    = '/api/v1/requests';

  // ─── مفاتيح التخزين العتادي الآمن (KeyStore / Keychain) ───
  static const String keyJwtToken         = 'rc_jwt_license_token_v1';
  static const String keyPublicKey        = 'rc_jwt_public_key_v1';
  static const String keyHwid             = 'rc_hardware_id_composite_v1';
  static const String keyLifetimeCount    = 'rc_lifetime_created_reports_count';
  static const String keyExportHashes     = 'rc_exported_reports_hashes_v1';
  static const String keyHighWatermark    = 'rc_high_watermark_timestamp';
  static const String keySuspensionReason = 'rc_suspension_reason_v1';
  static const String keyExecutedCmdIds   = 'rc_executed_command_ids_v1';
  static const String keyPendingCmdAcks   = 'rc_pending_command_results_v1';
  static const String keyLastPingTime     = 'rc_last_ping_timestamp_ms';
  static const String keyLastRequestId    = 'rc_last_submitted_request_id_v1';
  static const String keyLastRequestDate  = 'rc_last_submitted_request_date_v1';

  // ─── جهة الاتصال بالدعم الفني والمبيعات (واتساب) ───
  static const String supportWhatsAppNumber = ''; // يترك فارغاً ليفتح محادثة واتساب عامة أو يُحدد برقم المنشأة

  // ─── المؤقتات والفترات الزمنية ───
  static const Duration pingInterval         = Duration(seconds: 45);    // Tier-1 Ping تلقائي خفيف وسريع
  static const Duration restorePollInterval  = Duration(seconds: 45);    // Restore Poller
  static const Duration networkTimeout       = Duration(seconds: 10);    // مهلة الطلب
}
