// lib/models/paneldisplaydata.dart

import 'package:secpanel/models/panels.dart';

class PanelDisplayData {
  final Panel panel;
  final String panelVendorName;
  final String busbarVendorNames;
  final List<String> busbarVendorIds;
  final String componentVendorNames;
  final List<String> componentVendorIds;
  final String paletVendorNames;
  final List<String> paletVendorIds;
  final String corepartVendorNames;
  final List<String> corepartVendorIds;
  final String? busbarRemarks;

  PanelDisplayData({
    required this.panel,
    required this.panelVendorName,
    required this.busbarVendorNames,
    required this.busbarVendorIds,
    required this.componentVendorNames,
    required this.componentVendorIds,
    required this.paletVendorNames,
    required this.paletVendorIds,
    required this.corepartVendorNames,
    required this.corepartVendorIds,
    this.busbarRemarks,
  });

  // [TAMBAHAN] Factory constructor untuk membuat objek dari JSON response API
  factory PanelDisplayData.fromJson(Map<String, dynamic> json) {
    return PanelDisplayData(
      // API mengirim object panel secara nested
      panel: Panel.fromMap(json['panel']),
      panelVendorName: json['panel_vendor_name'] ?? '',
      busbarVendorNames: json['busbar_vendor_names'] ?? '',
      // API mengirim list of string
      busbarVendorIds: List<String>.from(json['busbar_vendor_ids'] ?? []),
      componentVendorNames: json['component_vendor_names'] ?? '',
      componentVendorIds: List<String>.from(json['component_vendor_ids'] ?? []),
      paletVendorNames: json['palet_vendor_names'] ?? '',
      paletVendorIds: List<String>.from(json['palet_vendor_ids'] ?? []),
      corepartVendorNames: json['corepart_vendor_names'] ?? '',
      corepartVendorIds: List<String>.from(json['corepart_vendor_ids'] ?? []),
      busbarRemarks: json['busbar_remarks'],
    );
  }
}
