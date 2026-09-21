import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../state/templates_provider.dart';
import '../session/dialogs/create_session_dialog.dart';
import 'template_editor_screen.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قوالب التقارير المعتمدة'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.solarGold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('قالب جديد', style: TextStyle(fontSize: 12)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TemplateEditorScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: AdaptiveContentContainer(
          padding: const EdgeInsets.all(16),
          child: templates.isEmpty
              ? const Center(child: Text('لا توجد قوالب متاحة'))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) {
                    final tmpl = templates[idx];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.solar_power_outlined, color: AppTheme.primaryNavy, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tmpl.title,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppTheme.textDark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tmpl.category} • ${tmpl.pages.length} صفحات معتمدة • المقاول: ${tmpl.contractorName}',
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              if (tmpl.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusGoodBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.statusGood.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'النموذج المعتمد رسمياً',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.statusGood),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            tmpl.description,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppTheme.borderSubtle),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: const BorderSide(color: AppTheme.borderSubtle),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('نسخ القالب', style: TextStyle(fontSize: 12)),
                                onPressed: () async {
                                  final cloned = await ref.read(templatesProvider.notifier).cloneTemplate(tmpl);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('تم نسخ القالب: ${cloned.title}')),
                                    );
                                  }
                                },
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.post_add_rounded, size: 16),
                                label: const Text('إنشاء تقرير من هذا القالب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  CreateSessionDialog.show(context, initialTemplate: tmpl);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
