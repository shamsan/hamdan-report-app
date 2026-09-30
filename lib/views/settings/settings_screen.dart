import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../services/storage_service.dart';
import '../../services/backup_service.dart';
import '../../services/default_templates.dart';
import '../../state/reports_provider.dart';
import '../../state/templates_provider.dart';
import '../../state/clients_provider.dart';
import '../../state/sites_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../session/preset_notes_manager_screen.dart';
import '../../state/licensing_provider.dart';
import '../licensing/license_activation_dialog.dart';
import '../licensing/license_request_sheet.dart';
import '../licensing/pending_request_banner.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadLastBackupTime();
  }

  Future<void> _loadLastBackupTime() async {
    final formatted = await BackupService.getLastBackupFormatted();
    if (mounted) {
      setState(() {
        _lastBackupTime = formatted;
      });
    }
  }

  Future<void> _exportArchiveLocalBackup(BuildContext context) async {
    try {
      final filePath = await BackupService.exportArchiveLocalFile();
      await _loadLastBackupTime();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: AppTheme.statusGood, size: 22),
              SizedBox(width: 8),
              Text('تم حفظ الأرشيف الشامل بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم تصدير حزمة الأرشيف الكاملة (.rcbackup) متضمنة قاعدة البيانات وكافة الصور المرفقة في ذاكرة الجهاز:', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SelectableText(
                  filePath,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.primaryNavy),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
              },
              child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ حزمة الأرشيف: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportAndShareArchiveBackup(BuildContext context) async {
    try {
      await BackupService.exportAndShareArchive();
      await _loadLastBackupTime();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل مشاركة حزمة الأرشيف: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportLocalBackup(BuildContext context) async {
    try {
      final filePath = await BackupService.exportLocalFile();
      await _loadLastBackupTime();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.statusGood, size: 22),
              SizedBox(width: 8),
              Text('تم حفظ النسخة بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تم حفظ نسخة احتياطية خفيفة (JSON) في ذاكرة الجهاز:', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: SelectableText(
                  filePath,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.primaryNavy),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
              },
              child: const Text('تم', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ النسخة الاحتياطية: $e'), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> _importBackup(BuildContext context) async {
    final inspection = await BackupService.pickAndInspectBackup();
    if (!context.mounted) return;

    if (!inspection.isValid) {
      if (inspection.errorMessage.isNotEmpty && inspection.errorMessage != 'لم يتم اختيار أي ملف') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(inspection.errorMessage), backgroundColor: Colors.red),
        );
      }
      return;
    }

    bool mergeMode = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(modalContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('معاينة واستعادة النسخة الاحتياطية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.primaryNavy)),
                        Text('تم فحص الملف والتحقق من سلامة البيانات', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('نوع الحزمة:', inspection.isArchive ? 'حزمة أرشيف شاملة (.rcbackup) 📦' : 'ملف بيانات JSON 📄'),
                    const Divider(height: 12),
                    if (inspection.isArchive) ...[
                      _buildInfoRow('الصور المرفقة:', '${inspection.photosCount} صورة فيزيائية 🖼️'),
                      const Divider(height: 12),
                    ],
                    _buildInfoRow('عدد التقارير المحفوظة:', '${inspection.reportCount} تقرير'),
                    const Divider(height: 12),
                    _buildInfoRow('العملاء والمواقع:', '${inspection.clientCount} عميل • ${inspection.siteCount} موقع'),
                    const Divider(height: 12),
                    _buildInfoRow('عدد النماذج والقوالب:', '${inspection.templateCount} قالب'),
                    const Divider(height: 12),
                    _buildInfoRow('تاريخ إنشاء النسخة:', inspection.exportedAt),
                    const Divider(height: 12),
                    _buildInfoRow('إصدار حزمة النسخ:', inspection.version),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('حدد طريقة الاستعادة المفضلة:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              _buildRestoreOptionTile(
                title: 'دمج ذكي مع التقارير الحالية (موصى به)',
                subtitle: 'إضافة التقارير الجديدة وتحديث المعدلة دون مسح أي تقارير أخرى على هاتفك.',
                isSelected: mergeMode,
                accentColor: AppTheme.primaryNavy,
                icon: Icons.merge_type_rounded,
                onTap: () => setModalState(() => mergeMode = true),
              ),
              const SizedBox(height: 8),
              _buildRestoreOptionTile(
                title: 'استبدال كامل (Full Overwrite)',
                subtitle: 'مسح البيانات الحالية واستبدالها بالكامل ببيانات ملف النسخة.',
                isSelected: !mergeMode,
                accentColor: Colors.red,
                icon: Icons.warning_amber_rounded,
                onTap: () => setModalState(() => mergeMode = false),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: mergeMode ? AppTheme.primaryNavy : AppTheme.statusRejected,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_download_rounded, size: 18),
                      label: Text(mergeMode ? 'تأكيد الدمج والاستعادة' : 'تأكيد الاستبدال الكامل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final navigator = Navigator.of(ctx);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final success = await BackupService.executeRestore(
                          inspection,
                          mergeMode: mergeMode,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        if (success) {
                          await ref.read(reportsProvider.notifier).load();
                          await ref.read(templatesProvider.notifier).load();
                          await ref.read(clientsProvider.notifier).load();
                          await ref.read(sitesProvider.notifier).load();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(inspection.isArchive
                                  ? 'تمت استعادة حزمة الأرشيف (${inspection.reportCount} تقرير و ${inspection.photosCount} صورة) بنجاح!'
                                  : 'تمت استعادة النسخة الاحتياطية بنجاح!'),
                              backgroundColor: AppTheme.statusGood,
                            ),
                          );
                        } else {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('حدث خطأ أثناء الاستعادة'), backgroundColor: Colors.red),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
      ],
    );
  }

  Widget _buildRestoreOptionTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : AppTheme.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? accentColor : AppTheme.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? accentColor : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetData(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('استعادة البيانات الافتراضية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('هل ترغب في إعادة تحميل تقرير مركز الكلى عبس والقالب المعتمد المكون من 11 صفحة؟'),
        actions: [
          TextButton(child: const Text('إلغاء'), onPressed: () => Navigator.pop(ctx)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(110, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('تأكيد الاستعادة', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await StorageService().saveReports([DefaultTemplates.sampleDialysisReport]);
              await ref.read(reportsProvider.notifier).load();
              await ref.read(templatesProvider.notifier).load();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت استعادة البيانات الافتراضية بنجاح')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والنسخ الاحتياطي'),
      ),
      body: SingleChildScrollView(
        child: AdaptiveContentContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Licensing Card
              _buildLicensingCard(context),

              // Header Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryNavy.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppTheme.primaryNavy, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('حالة النسخ الاحتياطي للبيانات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                          const SizedBox(height: 2),
                          Text(
                            _lastBackupTime != null
                                ? 'آخر عملية نسخ: $_lastBackupTime'
                                : 'لم يتم تسجيل نسخة احتياطية بعد',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),


              // Multi-Method Backup Card
              const Text('خيارات النسخ الاحتياطي المتعدد', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryNavy.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryNavy, size: 22),
                        ),
                        title: const Text('حفظ حزمة الأرشيف الشاملة (مع الصور)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('تصدير حزمة مضغوطة (.rcbackup) تحتوي على كافة التقارير والعملاء والمواقع مع الصور المرفقة', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _exportArchiveLocalBackup(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.share_rounded, color: AppTheme.brandCyan, size: 22),
                        ),
                        title: const Text('مشاركة حزمة الأرشيف الشاملة (مع الصور)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('إرسال الحزمة المضغوطة كاملة إلى واتساب، جوجل درايف، أو البريد لنقلها لمهندس آخر', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _exportAndShareArchiveBackup(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_open_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                        title: const Text('استيراد واستعادة من حزمة أرشيف أو ملف نسخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('فحص واستعادة حزم .rcbackup (مع الصور) أو ملفات JSON مع خياري الدمج أو الاستبدال', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _importBackup(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.code_rounded, color: Colors.blueGrey, size: 22),
                        ),
                        title: const Text('تصدير نسخة بيانات خفيفة (JSON فقط)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('حفظ ملف نصوص خفيف يتضمن بيانات التقارير والقوالب بدون الصور الفيزيائية', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _exportLocalBackup(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.solarGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.restart_alt_rounded, color: AppTheme.solarGold, size: 22),
                        ),
                        title: const Text('استعادة تقرير وقالب مركز الكلى عبس الافتراضي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('إعادة تحميل النموذج المعتمد الكامل المكون من 11 صفحة', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _resetData(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Preset Notes Management Section
              const Text('إدارة الملاحظات المسبقة', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bookmark_outline_rounded, color: AppTheme.brandCyan, size: 22),
                    ),
                    title: const Text('إدارة الملاحظات الفنية المسبقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                    subtitle: const Text('إضافة وتعديل العبارات المجهزة لتقييم بنود الفحص الميداني', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PresetNotesManagerScreen()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tour & Help Section
              const Text('دليل الاستخدام والتعليمات', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryNavy, size: 22),
                    ),
                    title: const Text('معالج التهيئة والإعداد الأولي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                    subtitle: const Text('إعادة تشغيل معالج إعداد هوية الشركة والعملاء والمواقع خطوة بخطوة', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OnboardingScreen(isFromSettings: true)),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // App Info Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCyan.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_outlined, color: AppTheme.brandCyan, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('نظام ReportCraft Enterprise', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark)),
                              Text('إصدار مهندسي الطاقة المعتمد 2.0.0', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'نظام مؤسسي متكامل لإنشاء وتعبئة وتصدير تقارير الصيانة الدورية الميدانية لمنظومات الطاقة الشمسية بصيغة PDF الرسمية المعتمدة (11 صفحة مطابقة للأصل 100%).',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.6),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.textMuted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يعمل بالكامل محلياً بدون إنترنت (Offline 100%) لحماية وسرية البيانات.',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicensingCard(BuildContext context) {
    final license = ref.watch(licensingProvider);
    final isTrial = license.tier == 'TRIAL';
    final isPro = license.isUnlimitedReports;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PendingRequestBanner(isDark: false),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPro ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPro ? const Color(0xFFBBF7D0) : AppTheme.borderSubtle,
              width: 1.2,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 360;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPro ? const Color(0xFFDCFCE7) : AppTheme.primaryNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPro ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                          color: isPro ? const Color(0xFF16A34A) : AppTheme.primaryNavy,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'حالة الترخيص: ${isPro ? "نسخة احترافية (PRO)" : isTrial ? "نسخة تجريبية (TRIAL)" : "غير مفعل"}',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPro
                                  ? 'تقارير غير محدودة (∞) • صالح حتى ${_formatEndDate(license.endDate)}'
                                  : isTrial
                                      ? 'متبقي ${license.daysLeft} يوماً • مستهلك ${license.reportsUsed}/${license.maxReports} تقريراً'
                                      : 'التطبيق يطلب تفعيل ترخيص صالح',
                              style: TextStyle(
                                fontSize: 11,
                                color: isPro ? const Color(0xFF15803D) : AppTheme.textMuted,
                                fontWeight: isPro ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isSmall) ...[
                    // الأزرار فوق بعض للشاشات الصغيرة
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          showDialog(
                            context: context,
                            builder: (ctx) => const LicenseActivationDialog(),
                          );
                        },
                        icon: const Icon(Icons.vpn_key_rounded, size: 16),
                        label: Text(isPro ? 'إدارة الترخيص' : 'تفعيل / ترقية'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryNavy,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
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
                        label: const Text('طلب رخصة جديدة أو نقل'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryNavy,
                          side: const BorderSide(color: AppTheme.primaryNavy),
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ] else ...[
                    // الأزرار جنباً إلى جنب للشاشات العريضة
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              showDialog(
                                context: context,
                                builder: (ctx) => const LicenseActivationDialog(),
                              );
                            },
                            icon: const Icon(Icons.vpn_key_rounded, size: 16),
                            label: Text(isPro ? 'إدارة الترخيص' : 'تفعيل / ترقية'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
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
                          label: const Text('طلب رخصة'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryNavy,
                            side: const BorderSide(color: AppTheme.primaryNavy),
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatEndDate(DateTime? dt) {
    if (dt == null) return 'غير محدد';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}
