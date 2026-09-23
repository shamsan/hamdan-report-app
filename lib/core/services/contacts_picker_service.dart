import 'package:flutter/services.dart';

class ContactPicked {
  final String phone;
  final String? name;

  const ContactPicked({required this.phone, this.name});
}

class ContactsPickerService {
  static const _channel = MethodChannel('com.reportcraft/contacts');

  static Future<ContactPicked?> pickContact() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('pickContact');
      if (res != null) {
        final phone = res['phone']?.toString().trim() ?? '';
        final name = res['name']?.toString().trim();
        if (phone.isNotEmpty) {
          return ContactPicked(
            phone: phone,
            name: (name != null && name.isNotEmpty) ? name : null,
          );
        }
      }
    } catch (_) {
      // Platform not supported or permission/intent cancelled
    }
    return null;
  }
}
