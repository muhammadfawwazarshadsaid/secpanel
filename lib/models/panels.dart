// lib/models/panels.dart

import 'dart:convert';

class Panel {
  String noPp;
  String? noPanel;
  String? noWbs;
  String? project;
  double? percentProgress;
  DateTime? startDate;
  DateTime? targetDelivery;
  String? statusBusbarPcc;
  String? statusBusbarMcc;
  String? statusComponent;
  String? statusPalet;
  String? statusCorepart;
  DateTime? aoBusbarPcc;
  DateTime? aoBusbarMcc;
  String? createdBy;
  String? vendorId;
  bool isClosed;
  DateTime? closedDate;

  Panel({
    required this.noPp,
    this.noPanel,
    this.noWbs,
    this.project,
    this.percentProgress,
    this.startDate,
    this.targetDelivery,
    this.statusBusbarPcc,
    this.statusBusbarMcc,
    this.statusComponent,
    this.statusPalet,
    this.statusCorepart,
    this.aoBusbarPcc,
    this.aoBusbarMcc,
    this.createdBy,
    this.vendorId,
    this.isClosed = false,
    this.closedDate,
  });

  // Method ini untuk database lokal (sqflite)
  Map<String, dynamic> toMap() {
    return {
      'no_pp': noPp,
      'no_panel': noPanel,
      'no_wbs': noWbs,
      'project': project,
      'percent_progress': percentProgress,
      'start_date': startDate?.toUtc().toIso8601String(),
      'target_delivery': targetDelivery?.toUtc().toIso8601String(),
      'status_busbar_pcc': statusBusbarPcc,
      'status_busbar_mcc': statusBusbarMcc,
      'status_component': statusComponent,
      'status_palet': statusPalet,
      'status_corepart': statusCorepart,
      'ao_busbar_pcc': aoBusbarPcc?.toUtc().toIso8601String(),
      'ao_busbar_mcc': aoBusbarMcc?.toUtc().toIso8601String(),
      'created_by': createdBy,
      'vendor_id': vendorId,
      'is_closed': isClosed ? 1 : 0, // sqflite pakai integer 1/0
      'closed_date': closedDate?.toUtc().toIso8601String(),
    };
  }

  // [TAMBAHAN] Method ini khusus untuk mengirim data ke API Go (backend)
  Map<String, dynamic> toMapForApi() {
    return {
      'no_pp': noPp,
      'no_panel': noPanel,
      'no_wbs': noWbs,
      'project': project,
      'percent_progress': percentProgress,
      'start_date': startDate?.toUtc().toIso8601String(),
      'target_delivery': targetDelivery?.toUtc().toIso8601String(),
      'status_busbar_pcc': statusBusbarPcc,
      'status_busbar_mcc': statusBusbarMcc,
      'status_component': statusComponent,
      'status_palet': statusPalet,
      'status_corepart': statusCorepart,
      'ao_busbar_pcc': aoBusbarPcc?.toUtc().toIso8601String(),
      'ao_busbar_mcc': aoBusbarMcc?.toUtc().toIso8601String(),
      'created_by': createdBy,
      'vendor_id': vendorId,
      'is_closed': isClosed, // API (JSON) pakai boolean true/false
      'closed_date': closedDate?.toUtc().toIso8601String(),
    };
  }

  // Factory ini untuk membuat objek dari data database lokal (sqflite)
  factory Panel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      // DateTime.parse otomatis handle string ISO 8601 (UTC)
      // .toLocal() mengubahnya ke zona waktu perangkat
      return DateTime.tryParse(dateStr)?.toLocal();
    }

    bool isClosedValue;
    if (map['is_closed'] is bool) {
      isClosedValue = map['is_closed'];
    } else {
      isClosedValue = map['is_closed'] == 1;
    }

    return Panel(
      noPp: map['no_pp'] ?? '',
      noPanel: map['no_panel'],
      noWbs: map['no_wbs'],
      project: map['project'],
      percentProgress: (map['percent_progress'] as num?)?.toDouble(),
      startDate: parseDate(map['start_date']),
      targetDelivery: parseDate(map['target_delivery']),
      statusBusbarPcc: map['status_busbar_pcc'],
      statusBusbarMcc: map['status_busbar_mcc'],
      statusComponent: map['status_component'],
      statusPalet: map['status_palet'],
      statusCorepart: map['status_corepart'],
      aoBusbarPcc: parseDate(map['ao_busbar_pcc']),
      aoBusbarMcc: parseDate(map['ao_busbar_mcc']),
      createdBy: map['created_by'],
      vendorId: map['vendor_id'],
      isClosed: isClosedValue,
      closedDate: parseDate(map['closed_date']),
    );
  }
}
