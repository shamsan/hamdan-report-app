/**
 * ══════════════════════════════════════════════════════════════
 *  Pending Request Glassmorphism Banner
 *  ReportCraft Enterprise Mobile UI
 * ══════════════════════════════════════════════════════════════
 *  شريط حالة شفاف يوضح للعميل أن طلبه قيد مراجعة الإدارة مع إمكانية الفحص والتفعيل الفوري
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/licensing/network/license_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../state/licensing_provider.dart';

class PendingRequestBanner extends ConsumerStatefulWidget {
  final bool isDark;
  const PendingRequestBanner({super.key, this.isDark = false});

  @override
  ConsumerState<PendingRequestBanner> createState() => _PendingRequestBannerState();
}

class _PendingRequestBannerState extends ConsumerState<PendingRequestBanner> {
  Map<String, dynamic>? _pendingRequest;
  bool _isChecking = false;
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final req = await LicenseSyncService.fetchLatestPendingRequest();
    if (mounted) {
      setState(() {
        _pendingRequest = req;
        _hasFetched = true;
      });
    }
  }

  Future<void> _handleCheckNow() async {
    setState(() => _isChecking = true);
    final restored = await LicenseSyncService.checkLicenseRestore();
    if (restored) {
      await ref.read(licensingProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _pendingRequest = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('تهانينا! تمت الموافقة وتفعيل الترخيص بنجاح!')),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
      return;
    }

    // إعادة جلب حالة الطلب
    await _fetchStatus();
    if (mounted) {
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الطلب لا يزال قيد مراجعة الإدارة. سيتم تفعيله فور الاعتماد.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasFetched || _pendingRequest == null) {
      return const SizedBox.shrink();
    }

    final id = _pendingRequest!['id']?.toString() ?? '';
    final shortId = id.length > 8 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
    final type = _pendingRequest!['type']?.toString() ?? 'طلب ترخيص';

    String typeLabel = 'طلب ترخيص جديد';
    if (type == 'UPGRADE' || type == 'TIER_UPGRADE') typeLabel = 'طلب ترقية الباقة';
    if (type == 'RENEWAL') typeLabel = 'طلب تجديد اشتراك';
    if (type == 'SERVICE_REQUEST' || type == 'TECHNICAL_ISSUE') typeLabel = 'طلب نقل ترخيص';

    final Color bgColor = widget.isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.85)
        : const Color(0xFFFFFBEB);
    final Color borderColor = widget.isDark
        ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
        : const Color(0xFFFCD34D);
    final Color textColor = widget.isDark ? Colors.white : AppTheme.textDark;
    final Color subTextColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$typeLabel (#$shortId)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'الطلب قيد مراجعة الإدارة • سيتم التفعيل تلقائياً فور الموافقة',
                      style: TextStyle(fontSize: 11, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _isChecking ? null : _handleCheckNow,
                icon: _isChecking
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('تحقق الآن', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
