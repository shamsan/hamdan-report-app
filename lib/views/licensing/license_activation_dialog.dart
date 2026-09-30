/**
 * ══════════════════════════════════════════════════════════════
 *  License Activation & Management Dialog
 *  ReportCraft Enterprise Mobile UI
 * ══════════════════════════════════════════════════════════════
 *  نافذة تفعيل وإدارة الترخيص مع دعم اللصق السريع ومسح QR والمشاركة عبر واتساب
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/licensing/security/hardware_fingerprint.dart';
import '../../core/licensing/utils/license_whatsapp_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';
import 'license_request_sheet.dart';
import 'qr_license_scanner_sheet.dart';

class LicenseActivationDialog extends ConsumerStatefulWidget {
  const LicenseActivationDialog({super.key});

  @override
  ConsumerState<LicenseActivationDialog> createState() => _LicenseActivationDialogState();
}

class _LicenseActivationDialogState extends ConsumerState<LicenseActivationDialog> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _hwid;

  @override
  void initState() {
    super.initState();
    _loadHwid();
  }

  Future<void> _loadHwid() async {
    final id = await HardwareFingerprint.getCompositeHwid();
    if (mounted) setState(() => _hwid = id);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _keyController.text = text;
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم لصق المفتاح من الحافظة'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  Future<void> _handleScanQr() async {
    final scannedKey = await QrLicenseScannerSheet.scan(context);
    if (scannedKey != null && scannedKey.trim().isNotEmpty) {
      setState(() {
        _keyController.text = scannedKey.trim();
        _errorMessage = null;
      });
      // تفعيل فوري ومباشر بعد المسح
      await _handleActivate();
    }
  }

  Future<void> _handleActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال مفتاح الترخيص أو مسح رمز QR.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ref.read(licensingProvider.notifier).activate(key);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res.success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(res.message ?? 'تم تفعيل الترخيص بنجاح!')),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message ?? 'فشل تفعيل الترخيص.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licensingProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryNavy, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تفعيل وإدارة الترخيص',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'ReportCraft Enterprise Licensing',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── بطاقة بصمة العتاد (HWID) وأزرار النسخ والمشاركة ───
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fingerprint, color: AppTheme.primaryNavy, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'بصمة هذا الهاتف (HWID):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const Spacer(),
                        // زر نسخ البصمة
                        InkWell(
                          onTap: _hwid != null
                              ? () {
                                  Clipboard.setData(ClipboardData(text: _hwid!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ بصمة الجهاز'), duration: Duration(seconds: 1)),
                                  );
                                }
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 13, color: AppTheme.brandCyan),
                                SizedBox(width: 4),
                                Text('نسخ', style: TextStyle(fontSize: 11, color: AppTheme.brandCyan, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // زر مشاركة عبر واتساب
                        InkWell(
                          onTap: _hwid != null
                              ? () => LicenseWhatsAppHelper.shareViaWhatsApp(
                                    context,
                                    hwid: _hwid!,
                                    currentTier: license.tier,
                                    currentKey: license.licenseKey,
                                  )
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.chat_bubble_rounded, size: 12, color: Color(0xFF16A34A)),
                                SizedBox(width: 4),
                                Text(
                                  'واتساب',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _hwid ?? 'جاري قراءة المعالج الأمني...',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── حقل إدخال المفتاح مع زري اللصق ومسح الـ QR ───
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  labelText: 'مفتاح الترخيص',
                  hintText: 'RC-XXXX-XXXX-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.primaryNavy),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // زر اللصق السريع
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, color: AppTheme.brandCyan, size: 20),
                        tooltip: 'لصق من الحافظة',
                        onPressed: _handlePaste,
                      ),
                      // زر مسح رمز QR
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryNavy, size: 22),
                        tooltip: 'مسح رمز QR',
                        onPressed: _handleScanQr,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _errorMessage,
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // ─── زر التفعيل ───
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleActivate,
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  _isLoading ? 'جاري التفعيل والتحقق...' : 'تفعيل الترخيص الآن',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // ─── زر طلب ترخيص جديد أو نقل ترخيص ───
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (ctx) => const LicenseRequestSheet(),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('طلب ترخيص جديد أو نقل ترخيص لهذا الهاتف'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.primaryNavy),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),

              // ─── مزامنة يدوية وفحص السيرفر أونلاين ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context);
                            setState(() => _isLoading = true);
                            final res = await ref.read(licensingProvider.notifier).checkOnlineStatus();
                            if (mounted) {
                              setState(() => _isLoading = false);
                              if (res.success) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(res.message ?? 'تم تحديث الترخيص بنجاح'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              } else {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(res.message ?? 'لا يوجد ترخيص معتمد جديد لهذا الهاتف.')),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('فحص الخادم أونلاين', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
