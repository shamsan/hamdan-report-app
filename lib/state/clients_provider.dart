import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../services/storage_service.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  final StorageService _storage;

  ClientsNotifier(this._storage) : super([]) {
    load();
  }

  Future<void> load() async {
    final list = await _storage.loadClients();
    if (mounted) state = list;
  }

  Future<Client> addClient({
    required String nameAr,
    String nameEn = '',
    String clientType = 'جهة حكومية / وزارة',
    String? logoBase64,
    String contactPerson = '',
    String phone = '',
    String email = '',
    String address = '',
    String notes = '',
  }) async {
    const uuid = Uuid();
    final newClient = Client(
      id: 'client_${uuid.v4().substring(0, 8)}',
      nameAr: nameAr.trim(),
      nameEn: nameEn.trim(),
      clientType: clientType,
      logoBase64: logoBase64,
      contactPerson: contactPerson.trim(),
      phone: phone.trim(),
      email: email.trim(),
      address: address.trim(),
      notes: notes.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _storage.saveSingleClient(newClient);
    state = [...state, newClient]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return newClient;
  }

  Future<void> updateClient(Client updated) async {
    final clientWithTime = updated.copyWith(updatedAt: DateTime.now());
    await _storage.saveSingleClient(clientWithTime);
    state = [
      for (final c in state)
        if (c.id == updated.id) clientWithTime else c
    ]..sort((a, b) => a.nameAr.compareTo(b.nameAr));
  }

  Future<void> deleteClient(String id) async {
    await _storage.deleteClient(id);
    state = state.where((c) => c.id != id).toList();
  }

  List<Client> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return state;
    return state.where((c) {
      return c.nameAr.toLowerCase().contains(q) ||
          c.nameEn.toLowerCase().contains(q) ||
          c.contactPerson.toLowerCase().contains(q) ||
          c.clientType.toLowerCase().contains(q);
    }).toList();
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ClientsNotifier(storage);
});
