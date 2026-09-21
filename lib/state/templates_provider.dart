import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/report_template.dart';
import '../services/storage_service.dart';
import 'clients_provider.dart';

class TemplatesNotifier extends StateNotifier<List<ReportTemplate>> {
  final StorageService _storage;

  TemplatesNotifier(this._storage) : super([]) {
    load();
  }

  Future<void> load() async {
    final list = await _storage.loadTemplates();
    state = list;
  }

  Future<void> saveTemplate(ReportTemplate template) async {
    await _storage.saveSingleTemplate(template);
    await load();
  }

  Future<ReportTemplate> cloneTemplate(ReportTemplate original) async {
    const uuid = Uuid();
    final cloned = original.copyWith(
      title: '${original.title} (نسخة)',
      description: 'نسخة مخصصة من: ${original.title}',
      updatedAt: DateTime.now(),
    );
    final newTemplate = ReportTemplate(
      id: 'tmpl_${uuid.v4().substring(0, 8)}',
      title: cloned.title,
      description: cloned.description,
      category: original.category,
      isDefault: false,
      isLocked: false,
      pages: original.pages,
      updatedAt: DateTime.now(),
    );
    await saveTemplate(newTemplate);
    return newTemplate;
  }

  Future<void> deleteTemplate(String id) async {
    await _storage.deleteTemplate(id);
    await load();
  }
}

final templatesProvider = StateNotifierProvider<TemplatesNotifier, List<ReportTemplate>>((ref) {
  return TemplatesNotifier(ref.watch(storageServiceProvider));
});
