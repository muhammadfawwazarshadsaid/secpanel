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
      'start_date': startDate?.toIso8601String(),
      'target_delivery': targetDelivery?.toIso8601String(),
      'status_busbar_pcc': statusBusbarPcc,
      'status_busbar_mcc': statusBusbarMcc,
      'status_component': statusComponent,
      'status_palet': statusPalet,
      'status_corepart': statusCorepart,
      'ao_busbar_pcc': aoBusbarPcc?.toIso8601String(),
      'ao_busbar_mcc': aoBusbarMcc?.toIso8601String(),
      'created_by': createdBy,
      'vendor_id': vendorId,
      'is_closed': isClosed ? 1 : 0, // sqflite pakai integer 1/0
      'closed_date': closedDate?.toIso8601String(),
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
      'start_date': startDate?.toIso8601String(),
      'target_delivery': targetDelivery?.toIso8601String(),
      'status_busbar_pcc': statusBusbarPcc,
      'status_busbar_mcc': statusBusbarMcc,
      'status_component': statusComponent,
      'status_palet': statusPalet,
      'status_corepart': statusCorepart,
      'ao_busbar_pcc': aoBusbarPcc?.toIso8601String(),
      'ao_busbar_mcc': aoBusbarMcc?.toIso8601String(),
      'created_by': createdBy,
      'vendor_id': vendorId,
      'is_closed': isClosed, // API (JSON) pakai boolean true/false
      'closed_date': closedDate?.toIso8601String(),
    };
  }

  // Factory ini untuk membuat objek dari data database lokal (sqflite)
  factory Panel.fromMap(Map<String, dynamic> map) {
    // Cek tipe data is_closed, karena API akan mengirim boolean
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
      // Pastikan konversi dari 'int' ke 'double' jika perlu
      percentProgress: (map['percent_progress'] as num?)?.toDouble(),
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'])
          : null,
      targetDelivery: map['target_delivery'] != null
          ? DateTime.tryParse(map['target_delivery'])
          : null,
      statusBusbarPcc: map['status_busbar_pcc'],
      statusBusbarMcc: map['status_busbar_mcc'],
      statusComponent: map['status_component'],
      statusPalet: map['status_palet'],
      statusCorepart: map['status_corepart'],
      aoBusbarPcc: map['ao_busbar_pcc'] != null
          ? DateTime.tryParse(map['ao_busbar_pcc'])
          : null,
      aoBusbarMcc: map['ao_busbar_mcc'] != null
          ? DateTime.tryParse(map['ao_busbar_mcc'])
          : null,
      createdBy: map['created_by'],
      vendorId: map['vendor_id'],
      isClosed: isClosedValue,
      closedDate: map['closed_date'] != null
          ? DateTime.tryParse(map['closed_date'])
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Panel.fromJson(String source) => Panel.fromMap(json.decode(source));

  Panel copyWith({
    String? noPp,
    String? noPanel,
    String? noWbs,
    String? project,
    double? percentProgress,
    DateTime? startDate,
    DateTime? targetDelivery,
    String? statusBusbarPcc,
    String? statusBusbarMcc,
    String? statusComponent,
    String? statusPalet,
    String? statusCorepart,
    DateTime? aoBusbarPcc,
    DateTime? aoBusbarMcc,
    String? createdBy,
    String? vendorId,
    bool? isClosed,
    DateTime? closedDate,
  }) {
    return Panel(
      noPp: noPp ?? this.noPp,
      noPanel: noPanel ?? this.noPanel,
      noWbs: noWbs ?? this.noWbs,
      project: project ?? this.project,
      percentProgress: percentProgress ?? this.percentProgress,
      startDate: startDate ?? this.startDate,
      targetDelivery: targetDelivery ?? this.targetDelivery,
      statusBusbarPcc: statusBusbarPcc ?? this.statusBusbarPcc,
      statusBusbarMcc: statusBusbarMcc ?? this.statusBusbarMcc,
      statusComponent: statusComponent ?? this.statusComponent,
      statusPalet: statusPalet ?? this.statusPalet,
      statusCorepart: statusCorepart ?? this.statusCorepart,
      aoBusbarPcc: aoBusbarPcc ?? this.aoBusbarPcc,
      aoBusbarMcc: aoBusbarMcc ?? this.aoBusbarMcc,
      createdBy: createdBy ?? this.createdBy,
      vendorId: vendorId ?? this.vendorId,
      isClosed: isClosed ?? this.isClosed,
      closedDate: closedDate ?? this.closedDate,
    );
  }
}
