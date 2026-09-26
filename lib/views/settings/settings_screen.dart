import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../services/storage_service.dart';
import '../../services/backup_service.dart';
import '../../services/default_templates.dart';
import '../../state/reports_provider.dart';
import '../../state/templates_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../session/preset_notes_manager_screen.dart';

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
              const Text('تم حفظ نسخة احتياطية كاملة لكافة التقارير والقوالب في ذاكرة الجهاز:', style: TextStyle(fontSize: 12.5)),
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تم'),
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

  Future<void> _exportAndShareBackup(BuildContext context) async {
    try {
      await BackupService.exportAndShare();
      await _loadLastBackupTime();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل مشاركة النسخة: $e'), backgroundColor: Colors.red),
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
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
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
                    _buildInfoRow('تاريخ إنشاء النسخة:', inspection.exportedAt),
                    const Divider(height: 12),
                    _buildInfoRow('عدد التقارير المحفوظة:', '${inspection.reportCount} تقرير'),
                    const Divider(height: 12),
                    _buildInfoRow('عدد النماذج والقوالب:', '${inspection.templateCount} قالب'),
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mergeMode ? AppTheme.primaryNavy : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cloud_download_rounded, size: 18),
                      label: Text(mergeMode ? 'تأكيد الدمج والاستعادة' : 'تأكيد الاستبدال الكامل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final success = await BackupService.executeRestore(
                          inspection.rawJson,
                          mergeMode: mergeMode,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        if (success) {
                          await ref.read(reportsProvider.notifier).load();
                          await ref.read(templatesProvider.notifier).load();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('تمت استعادة النسخة الاحتياطية بنجاح!'),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryNavy),
            child: const Text('تأكيد الاستعادة'),
            onPressed: () async {
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
                            color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.save_alt_rounded, color: AppTheme.primaryNavy, size: 22),
                        ),
                        title: const Text('حفظ نسخة احتياطية محلياً (JSON)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('حفظ ملف النسخة الكاملة مباشرة في ذاكرة تخزين الهاتف', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _exportLocalBackup(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.borderSubtle),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.share_rounded, color: AppTheme.brandCyan, size: 22),
                        ),
                        title: const Text('مشاركة النسخة الاحتياطية (Cloud / Apps)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('إرسال فوري إلى WhatsApp، Google Drive، أو البريد الإلكتروني', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _exportAndShareBackup(context),
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
                        title: const Text('استيراد واستعادة من ملف احتياطي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.textDark)),
                        subtitle: const Text('اختيار ملف وفحصه ومعاينته مع خياري الدمج الذكي أو الاستبدال', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.textMuted),
                        onTap: () => _importBackup(context),
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
}
