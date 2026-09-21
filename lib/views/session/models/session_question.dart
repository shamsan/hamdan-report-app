import '../../../models/inspection_item.dart';
import '../../../models/report.dart';

class SessionQuestion {
  final int globalIndex;
  final int groupIndex;
  final int itemIndex;
  final InspectionGroup group;
  final InspectionItem item;
  final bool isSkipped;

  const SessionQuestion({
    required this.globalIndex,
    required this.groupIndex,
    required this.itemIndex,
    required this.group,
    required this.item,
    this.isSkipped = false,
  });

  bool get isInspected => item.status != InspectionStatus.uninspected && !isSkipped;
  String? get subcategory => item.subcategory;

  static List<SessionQuestion> buildList(Report report, Set<int> skippedIndices) {
    final list = <SessionQuestion>[];
    int globalIdx = 0;

    for (int gIdx = 0; gIdx < report.inspectionGroups.length; gIdx++) {
      final group = report.inspectionGroups[gIdx];
      for (int iIdx = 0; iIdx < group.items.length; iIdx++) {
        final item = group.items[iIdx];
        list.add(SessionQuestion(
          globalIndex: globalIdx,
          groupIndex: gIdx,
          itemIndex: iIdx,
          group: group,
          item: item,
          isSkipped: skippedIndices.contains(globalIdx),
        ));
        globalIdx++;
      }
    }
    return list;
  }
}
