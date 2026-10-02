/**
 * ══════════════════════════════════════════════════════════════
 *  Command Event Bus
 *  ReportCraft Enterprise Mobile Security
 * ══════════════════════════════════════════════════════════════
 *  قناة بث أحداث الأوامر الفورية إلى واجهات المستخدم ومكونات التطبيق
 */

import 'dart:async';

abstract class LicensingUIEvent {}

class ShowMessageUIEvent extends LicensingUIEvent {
  final String title;
  final String message;
  final String? type; // 'info', 'warning', 'critical'
  final bool isDismissible;

  ShowMessageUIEvent({
    required this.title,
    required this.message,
    this.type,
    this.isDismissible = true,
  });
}

class MaintenanceModeUIEvent extends LicensingUIEvent {
  final bool isEnabled;
  final String message;

  MaintenanceModeUIEvent({
    required this.isEnabled,
    required this.message,
  });
}

class ForceUpdateUIEvent extends LicensingUIEvent {
  final String version;
  final String? downloadUrl;
  final bool isMandatory;
  final String? releaseNotes;
  final String? checksum;
  final int? fileSize;

  ForceUpdateUIEvent({
    required this.version,
    this.downloadUrl,
    this.isMandatory = false,
    this.releaseNotes,
    this.checksum,
    this.fileSize,
  });
}

class CommandEventBus {
  static final CommandEventBus _instance = CommandEventBus._internal();
  factory CommandEventBus() => _instance;
  CommandEventBus._internal();

  final _controller = StreamController<LicensingUIEvent>.broadcast();

  Stream<LicensingUIEvent> get stream => _controller.stream;

  void emit(LicensingUIEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}
