/**
 * ══════════════════════════════════════════════════════════════
 *  License Request Bottom Sheet (Comprehensive & Device Transfer)
 *  ReportCraft Enterprise Mobile UI
 * ══════════════════════════════════════════════════════════════
 *  نموذج تقديم طلب ترخيص جديد، ترقية، أو نقل ترخيص لهاتف جديد للإدارة المركزية
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/licensing/security/hardware_fingerprint.dart';
import '../../core/licensing/utils/license_whatsapp_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';

class LicenseRequestSheet extends ConsumerStatefulWidget {
  final String? initialType;
  final String? initialKey;

  const LicenseRequestSheet({super.key, this.initialType, this.initialKey});

  @override
  ConsumerState<LicenseRequestSheet> createState() => _LicenseRequestSheetState();
}

class _LicenseRequestSheetState extends ConsumerState<LicenseRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _oldKeyController = TextEditingController();
  final _messageController = TextEditingController();

  late String _requestType;
  final String _requestedTier = 'PRO';
  bool _isLoading = false;
  String? _errorMessage;
  String? _hwid;

  @override
  void initState() {
    super.initState();
    _requestType = widget.initialType ?? 'NEW_LICENSE';
    if (widget.initialKey != null) {
      _oldKeyController.text = widget.initialKey!;
    }
    _loadHwid();
  }

  Future<void> _loadHwid() async {
    final id = await HardwareFingerprint.getCompositeHwid();
    if (mounted) setState(() => _hwid = id);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _oldKeyController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String detailsMessage = _messageController.text.trim();
    if (_requestType == 'SERVICE_REQUEST') {
      final key = _oldKeyController.text.trim();
      detailsMessage = 'طلب نقل الترخيص ($key) إلى الهاتف الجديد ذو البصمة العتادية ($_hwid). $detailsMessage';
    } else if (detailsMessage.isEmpty) {
      detailsMessage = 'طلب ترخيص جديد لتطبيق ReportCraft للتقارير الهندسية الميدانية';
    }

    final res = await ref.read(licensingProvider.notifier).submitRequest(
      type: _requestType,
      companyName: _companyController.text,
      contactName: _contactPersonController.text,
      contactPhone: _phoneController.text.isNotEmpty ? _phoneController.text : null,
      contactEmail: _emailController.text.isNotEmpty ? _emailController.text : null,
      message: detailsMessage,
      requestedTier: _requestedTier,
    );

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
                Expanded(child: Text(res.message ?? 'تم إرسال الطلب للإدارة بنجاح!')),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        setState(() => _errorMessage = res.message ?? 'فشل إرسال الطلب.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = _requestType == 'SERVICE_REQUEST';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header ───
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.brandCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isTransfer ? Icons.phonelink_setup_rounded : Icons.send_rounded,
                      color: AppTheme.brandCyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTransfer ? 'طلب نقل ترخيص إلى هذا الهاتف' : 'تقديم طلب ترخيص للإدارة',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const Text(
                          'سيتم تفعيل الترخيص آلياً على هذا الهاتف فور اعتماد الإدارة',
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

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── نوع الطلب ───
              DropdownButtonFormField<String>(
                initialValue: _requestType,
                decoration: InputDecoration(
                  labelText: 'نوع الطلب',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'NEW_LICENSE', child: Text('طلب ترخيص جديد')),
                  DropdownMenuItem(value: 'SERVICE_REQUEST', child: Text('طلب نقل ترخيص سابق (تغيير هاتف)')),
                  DropdownMenuItem(value: 'UPGRADE', child: Text('ترقية فئة الترخيص إلى PRO')),
                  DropdownMenuItem(value: 'RENEWAL', child: Text('تجديد ترخيص منتهي')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _requestType = val);
                },
              ),
              const SizedBox(height: 12),

              // ─── في حال طلب النقل: حقل المفتاح السابق ───
              if (isTransfer) ...[
                TextFormField(
                  controller: _oldKeyController,
                  decoration: InputDecoration(
                    labelText: 'مفتاح الترخيص السابق المراد نقله *',
                    hintText: 'RC-XXXX-XXXX-XXXX-XXXX',
                    prefixIcon: const Icon(Icons.vpn_key_rounded, color: AppTheme.primaryNavy),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال مفتاح الترخيص السابق';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // ─── اسم المؤسسة أو المنشأة ───
              TextFormField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: 'اسم المنشأة / المكتب الهندسي *',
                  hintText: 'مثال: شركة الطاقة المتقدمة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'اسم المنشأة مطلوب';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ─── اسم الشخص المسؤول ───
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(
                  labelText: 'اسم المهندس / المسؤول *',
                  hintText: 'مثال: م. أحمد الحمدان',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'اسم المسؤول مطلوب';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ─── رقم الهاتف ───
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'رقم هاتف التواصل (واتساب)',
                  hintText: 'مثال: 967770000000',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // ─── ملاحظات إضافية ───
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية (اختياري)',
                  hintText: 'أي تفاصيل خاصة ترغب بإبلاغ الإدارة بها',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // ─── زر الإرسال ───
              FilledButton.icon(
                onPressed: _isLoading ? null : () {
                  HapticFeedback.mediumImpact();
                  _handleSubmit();
                },
                icon: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isLoading ? 'جاري إرسال الطلب...' : 'إرسال الطلب للإدارة الآن',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // ─── زر بديل: إرسال الطلب السريع عبر واتساب ───
              OutlinedButton.icon(
                onPressed: _hwid != null
                    ? () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                        LicenseWhatsAppHelper.shareViaWhatsApp(
                          context,
                          hwid: _hwid!,
                          currentTier: isTransfer ? 'طلب نقل ترخيص' : 'طلب ترخيص جديد',
                          currentKey: _oldKeyController.text.isNotEmpty ? _oldKeyController.text : null,
                          customNote: _companyController.text.isNotEmpty
                              ? 'المنشأة: ${_companyController.text} - المسؤول: ${_contactPersonController.text}'
                              : null,
                        );
                      }
                    : null,
                icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF16A34A), size: 18),
                label: const Text(
                  'أو إرسال الطلب مباشرة عبر واتساب الإدارة',
                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
