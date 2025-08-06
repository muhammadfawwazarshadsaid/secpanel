import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:secpanel/components/import/confirm_import_bottom_sheet.dart';
import 'package:secpanel/components/import/import_progress_dialog.dart';
import 'package:secpanel/helpers/db_helper.dart';
import 'package:secpanel/models/approles.dart';
import 'package:secpanel/models/company.dart';
import 'package:secpanel/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// [PERUBAHAN] Widget baru yang dibuat khusus untuk konfirmasi duplikat, diletakkan di file yang sama.
class _DuplicateConfirmationBottomSheet extends StatelessWidget {
  final String title;
  final String summary;
  final Map<String, List<int>> duplicateData;

  const _DuplicateConfirmationBottomSheet({
    required this.title,
    required this.summary,
    required this.duplicateData,
  });

  @override
  Widget build(BuildContext context) {
    final duplicateEntries = duplicateData.entries.toList();

    return Container(
      height:
          MediaQuery.of(context).size.height *
          0.7, // Batasi tinggi bottom sheet
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 5,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.grayLight,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: const TextStyle(
              color: AppColors.gray,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          // Bagian yang bisa di-scroll
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.grayLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                itemCount: duplicateEntries.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = duplicateEntries[index];
                  final noPp = entry.key;
                  final rows = entry.value.join(', ');
                  return ListTile(
                    dense: true,
                    title: Text(
                      'No. PP: $noPp',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      'Baris: $rows',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.schneiderGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "Batal",
                    style: TextStyle(
                      color: AppColors.schneiderGreen,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.schneiderGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    "Lanjutkan",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValidationResult {
  final List<String> missing;
  final List<String> unrecognized;
  _ValidationResult({required this.missing, required this.unrecognized});
}

class ImportReviewScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> initialData;
  final bool isCustomTemplate;

  const ImportReviewScreen({
    super.key,
    required this.initialData,
    this.isCustomTemplate = false,
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  late Map<String, List<Map<String, dynamic>>> _editableData;
  late Map<String, Set<int>> _duplicateRows;
  late Map<String, Map<int, Set<String>>> _brokenRelationCells;
  late Map<String, Set<int>> _invalidIdentifierRows;
  bool _isLoading = true;

  late Map<String, Set<String>> _existingPrimaryKeys;
  List<Company> _allCompanies = [];

  static const Map<String, Map<String, String>> _columnEquivalents = {
    'panel': {
      'PP Panel': 'no_pp',
      'Panel No': 'no_panel',
      'WBS': 'no_wbs',
      'PROJECT': 'project',
      'Plan Start': 'start_date',
      'Actual Delivery ke SEC': 'target_delivery',
      'Panel': 'vendor_id',
      'Busbar': 'busbar_vendor_id',
    },
    'user': {
      'Username': 'username',
      'Password': 'password',
      'Company': 'company_name',
      'Company Role': 'role',
    },
  };

  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  final ValueNotifier<String> _statusNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _editableData = widget.initialData.map((key, value) {
      return MapEntry(
        key,
        value.map((item) => Map<String, dynamic>.from(item)).toList(),
      );
    });
    _duplicateRows = {};
    _brokenRelationCells = {};
    _invalidIdentifierRows = {};
    _initializeAndValidateData();
  }

  Future<void> _initializeAndValidateData() async {
    if (mounted) setState(() => _isLoading = true);

    await _fetchAllCompanies();
    await _fetchExistingPrimaryKeys();
    _revalidateOnDataChange();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAllCompanies() async {
    _allCompanies = await DatabaseHelper.instance.getAllCompanies();
  }

  Future<void> _fetchExistingPrimaryKeys() async {
    final dbHelper = DatabaseHelper.instance;
    _existingPrimaryKeys = {
      'companies': (await dbHelper.getAllCompanies()).map((c) => c.id).toSet(),
      'company_accounts': (await dbHelper.getAllCompanyAccounts())
          .map((a) => a.username)
          .toSet(),
      'panels': (await dbHelper.getAllPanels()).map((p) => p.noPp).toSet(),
      'busbars': (await dbHelper.getAllBusbars())
          .map((b) => "${b.panelNoPp}_${b.vendor}")
          .toSet(),
      'components': (await dbHelper.getAllComponents())
          .map((c) => "${c.panelNoPp}_${c.vendor}")
          .toSet(),
      'palet': (await dbHelper.getAllPalet())
          .map((c) => "${c.panelNoPp}_${c.vendor}")
          .toSet(),
      'corepart': (await dbHelper.getAllCorepart())
          .map((c) => "${c.panelNoPp}_${c.vendor}")
          .toSet(),
    };
  }

  String? _findPrimaryKeyColumnName(
    String tableName,
    List<String> actualColumns,
  ) {
    const dbPkMap = {
      'companies': 'id',
      'company_accounts': 'username',
      'panels': 'no_pp',
      'user': 'username',
      'panel': 'no_pp',
    };

    final dbPkName = dbPkMap[tableName.toLowerCase()];
    if (dbPkName == null) return null;

    final equivalents = _columnEquivalents[tableName.toLowerCase()];
    String? templatePkName;
    if (equivalents != null) {
      for (var entry in equivalents.entries) {
        if (entry.value.toLowerCase() == dbPkName.toLowerCase()) {
          templatePkName = entry.key;
          break;
        }
      }
    }

    final actualColsLower = actualColumns.map((c) => c.toLowerCase()).toSet();

    if (templatePkName != null &&
        actualColsLower.contains(templatePkName.toLowerCase())) {
      return actualColumns.firstWhere(
        (c) => c.toLowerCase() == templatePkName!.toLowerCase(),
      );
    }

    if (actualColsLower.contains(dbPkName.toLowerCase())) {
      return actualColumns.firstWhere(
        (c) => c.toLowerCase() == dbPkName.toLowerCase(),
      );
    }

    return null;
  }

  void _validateDuplicates() {
    _duplicateRows = {};

    for (final tableName in _editableData.keys) {
      final rows = _editableData[tableName]!;
      if (rows.isEmpty) continue;

      final actualColumns = rows.first.keys.toList();
      final pkColumn = _findPrimaryKeyColumnName(tableName, actualColumns);

      if (pkColumn != null) {
        _duplicateRows.putIfAbsent(tableName, () => <int>{});
        final dbTableName = (tableName.toLowerCase() == 'panel')
            ? 'panels'
            : (tableName.toLowerCase() == 'user')
            ? 'company_accounts'
            : tableName;
        final pksInDb = _existingPrimaryKeys[dbTableName] ?? {};
        final pksInFile = <String>{};
        for (int i = 0; i < rows.length; i++) {
          final pkValue = rows[i][pkColumn]?.toString();
          if (pkValue != null && pkValue.isNotEmpty) {
            if (pksInDb.contains(pkValue) || !pksInFile.add(pkValue)) {
              _duplicateRows[tableName]!.add(i);
            }
          }
        }
      }
    }

    final List<String> compositeKeyTables = [
      'busbars',
      'components',
      'palet',
      'corepart',
    ];
    for (final tableName in compositeKeyTables) {
      if (!_editableData.containsKey(tableName) ||
          _editableData[tableName]!.isEmpty)
        continue;
      _duplicateRows.putIfAbsent(tableName, () => <int>{});
      final rows = _editableData[tableName]!;
      final existingCompositeKeys =
          _existingPrimaryKeys[tableName] ?? <String>{};
      final seenKeysInFile = <String>{};
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final panelNoPp = row['panel_no_pp']?.toString() ?? '';
        final vendor = row['vendor']?.toString() ?? '';
        if (panelNoPp.isNotEmpty && vendor.isNotEmpty) {
          final compositeKey = "${panelNoPp}_${vendor}";
          if (existingCompositeKeys.contains(compositeKey) ||
              !seenKeysInFile.add(compositeKey)) {
            _duplicateRows[tableName]!.add(i);
          }
        }
      }
    }
  }

  void _validateBrokenRelations() {
    _brokenRelationCells = {};
    final allCompanyIDsInFile =
        _editableData['companies']
            ?.map((row) => row['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet() ??
        {};
    final allAvailableCompanyIDs = {
      ..._existingPrimaryKeys['companies'] ?? {},
      ...allCompanyIDsInFile,
    };

    _editableData.forEach((tableName, rows) {
      if (rows.isEmpty) return;
      _brokenRelationCells.putIfAbsent(tableName, () => {});
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        _brokenRelationCells[tableName]!.putIfAbsent(i, () => {});
        final relationsToCheck = <String, Set<String>>{
          'company_id': allAvailableCompanyIDs,
          'vendor_id': allAvailableCompanyIDs,
          'created_by': allAvailableCompanyIDs,
          'vendor': allAvailableCompanyIDs,
        };
        relationsToCheck.forEach((colName, validKeys) {
          if (row.containsKey(colName)) {
            final fk = row[colName]?.toString() ?? '';
            if (fk.isNotEmpty && !validKeys.contains(fk)) {
              _brokenRelationCells[tableName]![i]!.add(colName);
            }
          }
        });
      }
    });
  }

  void _validateMissingIdentifiers() {
    _invalidIdentifierRows = {};
    const String tableName = 'panel';
    if (!_editableData.containsKey(tableName) ||
        _editableData[tableName]!.isEmpty) {
      return;
    }

    _invalidIdentifierRows.putIfAbsent(tableName, () => <int>{});
    final rows = _editableData[tableName]!;

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      String? getVal(List<String> keys) {
        for (final key in keys) {
          final actualKey = row.keys.firstWhere(
            (k) => k.toLowerCase() == key.toLowerCase(),
            orElse: () => '',
          );
          if (actualKey.isNotEmpty) {
            return row[actualKey]?.toString();
          }
        }
        return null;
      }

      final noPp = getVal(['no_pp', 'pp panel']);
      final noPanel = getVal(['no_panel', 'panel no']);
      final noWbs = getVal(['no_wbs', 'wbs']);

      if ((noPp == null || noPp.isEmpty) &&
          (noPanel == null || noPanel.isEmpty) &&
          (noWbs == null || noWbs.isEmpty)) {
        _invalidIdentifierRows[tableName]!.add(i);
      }
    }
  }

  void _revalidateOnDataChange() {
    setState(() {
      _validateDuplicates();
      _validateBrokenRelations();
      _validateMissingIdentifiers();
    });
  }

  void _addRow(String tableName) {
    setState(() {
      final columns = _editableData[tableName]!.isNotEmpty
          ? _editableData[tableName]!.first.keys.toList()
          : (_columnEquivalents[tableName.toLowerCase()]?.keys.toList() ?? []);
      final newRow = {for (var col in columns) col: ''};
      _editableData[tableName]!.add(newRow);
      _revalidateOnDataChange();
    });
  }

  void _deleteRow(String tableName, int index) {
    setState(() {
      _editableData[tableName]!.removeAt(index);
      _revalidateOnDataChange();
    });
  }

  void _deleteColumn(String tableName, String columnName) {
    setState(() {
      for (var row in _editableData[tableName]!) {
        row.remove(columnName);
      }
      _revalidateOnDataChange();
    });
  }

  void _renameColumn(String tableName, String oldName, String newName) {
    if (newName.isNotEmpty && newName != oldName) {
      setState(() {
        for (var row in _editableData[tableName]!) {
          final value = row.remove(oldName);
          row[newName] = value;
        }
        _revalidateOnDataChange();
      });
    }
  }

  void _addNewColumn(String tableName, String newName) {
    if (newName.isNotEmpty) {
      setState(() {
        for (var row in _editableData[tableName]!) {
          row[newName] = '';
        }
        _revalidateOnDataChange();
      });
    }
  }

  List<Map<String, dynamic>> _resolvePanelDuplicates(
    List<Map<String, dynamic>> originalPanels,
  ) {
    if (originalPanels.isEmpty) return [];

    final pkColumn =
        _findPrimaryKeyColumnName(
          'panel',
          originalPanels.first.keys.toList(),
        ) ??
        'no_pp';
    final Map<String, List<Map<String, dynamic>>> groupedByNoPp = {};
    final List<Map<String, dynamic>> nonPanelKeyRows = [];

    for (final row in originalPanels) {
      final noPp = row[pkColumn]?.toString();
      if (noPp != null && noPp.isNotEmpty) {
        groupedByNoPp.putIfAbsent(noPp, () => []).add(row);
      } else {
        nonPanelKeyRows.add(row);
      }
    }

    final List<Map<String, dynamic>> resolvedPanels = [];
    for (final group in groupedByNoPp.values) {
      if (group.length <= 1) {
        resolvedPanels.addAll(group);
      } else {
        Map<String, dynamic>? bestRow;
        int maxScore = -1;

        for (final row in group) {
          int currentScore = row.values
              .where((v) => v != null && v.toString().trim().isNotEmpty)
              .length;
          if (currentScore > maxScore) {
            maxScore = currentScore;
            bestRow = row;
          }
        }
        if (bestRow != null) {
          resolvedPanels.add(bestRow);
        }
      }
    }

    resolvedPanels.addAll(nonPanelKeyRows);

    return resolvedPanels;
  }

  Future<void> _saveToDatabase() async {
    final hasInvalidIdentifiers = _invalidIdentifierRows.values.any(
      (s) => s.isNotEmpty,
    );
    if (hasInvalidIdentifiers) {
      _showErrorSnackBar(
        'Beberapa baris panel tidak memiliki identifier (No PP/Panel/WBS). Harap perbaiki.',
      );
      return;
    }

    final hasBrokenRelations = _brokenRelationCells.values.any(
      (map) => map.values.any((set) => set.isNotEmpty),
    );
    if (hasBrokenRelations && !widget.isCustomTemplate) {
      _showErrorSnackBar(
        'Masih ada relasi data yang belum valid (ditandai merah). Harap perbaiki.',
      );
      return;
    }

    // [PERUBAHAN] Alur konfirmasi duplikat menggunakan widget baru
    final panelDuplicates = _duplicateRows['panel'];
    if (panelDuplicates != null &&
        panelDuplicates.isNotEmpty &&
        _editableData['panel']!.isNotEmpty) {
      final panelRows = _editableData['panel']!;
      final pkColumn =
          _findPrimaryKeyColumnName('panel', panelRows.first.keys.toList()) ??
          'no_pp';

      final Map<String, List<int>> duplicatePpToRows = {};
      for (final index in panelDuplicates) {
        final noPp = panelRows[index][pkColumn]?.toString();
        if (noPp != null && noPp.isNotEmpty) {
          duplicatePpToRows.putIfAbsent(noPp, () => []).add(index + 1);
        }
      }

      if (duplicatePpToRows.isNotEmpty) {
        final totalDuplicateRows = panelDuplicates.length;
        final uniqueDuplicatePpCount = duplicatePpToRows.length;

        final summary =
            'Terdapat $totalDuplicateRows data panel dengan $uniqueDuplicatePpCount No. PP yang sama. Sistem akan memilih data paling lengkap untuk setiap No. PP berikut:';

        final confirm = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => _DuplicateConfirmationBottomSheet(
            title: 'Konfirmasi Data Duplikat',
            summary: summary,
            duplicateData: duplicatePpToRows,
          ),
        );

        if (confirm != true) {
          return;
        }
      }
    }

    final confirmGeneral = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const ConfirmImportBottomSheet(
        title: 'Konfirmasi Impor',
        content:
            'Data akan ditambahkan atau diperbarui di database. Lanjutkan?',
      ),
    );
    if (confirmGeneral != true) return;

    final dataToImport = _editableData.map((key, value) {
      return MapEntry(
        key,
        value.map((item) => Map<String, dynamic>.from(item)).toList(),
      );
    });

    if (dataToImport.containsKey('panel')) {
      dataToImport['panel'] = _resolvePanelDuplicates(dataToImport['panel']!);
    }

    final prefs = await SharedPreferences.getInstance();
    final String? loggedInUsername = prefs.getString('loggedInUsername');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ImportProgressDialog(
        progress: _progressNotifier,
        status: _statusNotifier,
      ),
    );

    try {
      String resultMessage;
      if (widget.isCustomTemplate) {
        resultMessage = await DatabaseHelper.instance.importFromCustomTemplate(
          data: dataToImport,
          onProgress: (p, m) {
            _progressNotifier.value = p;
            _statusNotifier.value = m;
          },
          loggedInUsername: loggedInUsername,
        );
      } else {
        await DatabaseHelper.instance.importData(dataToImport, (p, m) {
          _progressNotifier.value = p;
          _statusNotifier.value = m;
        });
        resultMessage = "Data berhasil diimpor! 🎉";
      }

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultMessage),
            backgroundColor:
                resultMessage.toLowerCase().contains("gagal") ||
                    resultMessage.toLowerCase().contains("error")
                ? AppColors.red
                : AppColors.schneiderGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Gagal menyimpan data: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.schneiderGreen),
              SizedBox(height: 16),
              Text(
                "Memvalidasi data...",
                style: TextStyle(color: AppColors.gray),
              ),
            ],
          ),
        ),
      );
    }
    final tableNames = _editableData.keys.toList();
    return DefaultTabController(
      length: tableNames.length,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          title: const Text(
            'Tinjau Data Impor',
            style: TextStyle(
              color: AppColors.black,
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                labelColor: AppColors.black,
                unselectedLabelColor: AppColors.gray,
                indicatorColor: AppColors.schneiderGreen,
                indicatorWeight: 2,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                indicatorSize: TabBarIndicatorSize.label,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Lexend',
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Lexend',
                  fontSize: 12,
                ),
                tabs: tableNames.map(_buildTabWithIndicator).toList(),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: tableNames
              .map((name) => _buildDataTable(name, _editableData[name]!))
              .toList(),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(color: AppColors.white),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shadowColor: Colors.transparent,
              backgroundColor: AppColors.schneiderGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: _saveToDatabase,
            child: const Text(
              'Simpan ke Database',
              style: TextStyle(
                fontFamily: 'Lexend',
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return '';
    return text
        .split(RegExp(r'[\s_]+'))
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Widget _buildTabWithIndicator(String tableName) {
    final hasDuplicates = (_duplicateRows[tableName]?.isNotEmpty ?? false);
    final hasBrokenRelations =
        (_brokenRelationCells[tableName]?.values.any((s) => s.isNotEmpty) ??
        false);
    final hasInvalidIdentifiers =
        (_invalidIdentifierRows[tableName]?.isNotEmpty ?? false);
    final rowCount = _editableData[tableName]?.length ?? 0;

    Color? indicatorColor;
    if (hasDuplicates) {
      indicatorColor = AppColors.red;
    } else if (hasBrokenRelations || hasInvalidIdentifiers) {
      indicatorColor = Colors.orange;
    }

    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${_toTitleCase(tableName)} ($rowCount)'),
          if (indicatorColor != null) ...[
            const SizedBox(width: 8),
            CircleAvatar(backgroundColor: indicatorColor, radius: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoAlert({
    required IconData icon,
    required Color color,
    required String title,
    required Widget details,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border(left: BorderSide(width: 4, color: color)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                details,
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ValidationResult _validateColumnStructure(
    String tableName,
    List<String> actualColumns,
  ) {
    final equivalents = _columnEquivalents[tableName.toLowerCase()];
    if (equivalents == null) {
      return _ValidationResult(missing: [], unrecognized: []);
    }
    final validTemplateNames = equivalents.keys
        .map((k) => k.toLowerCase())
        .toSet();
    final validDbNames = equivalents.values.map((v) => v.toLowerCase()).toSet();
    final actualColsLower = actualColumns.map((k) => k.toLowerCase()).toSet();
    final unrecognized = actualColumns.where((actualCol) {
      final lower = actualCol.toLowerCase();
      return !validTemplateNames.contains(lower) &&
          !validDbNames.contains(lower);
    }).toList();
    final missing = equivalents.entries
        .where((entry) {
          final templateNameLower = entry.key.toLowerCase();
          final dbNameLower = entry.value.toLowerCase();
          return !actualColsLower.contains(templateNameLower) &&
              !actualColsLower.contains(dbNameLower);
        })
        .map((entry) => entry.key)
        .toList();
    return _ValidationResult(missing: missing, unrecognized: unrecognized);
  }

  Widget _buildColumnValidationInfoBox(String tableName) {
    if (!_editableData.containsKey(tableName)) return const SizedBox.shrink();
    final detailsStyle = TextStyle(
      fontSize: 12,
      color: Colors.black.withOpacity(0.8),
      fontWeight: FontWeight.w300,
    );
    if (_editableData[tableName]!.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildInfoAlert(
          icon: Icons.check_circle_outlined,
          color: AppColors.schneiderGreen,
          title: "Struktur Kolom Sesuai",
          details: Text(
            "Tidak ada data untuk diimpor di tabel ini.",
            style: detailsStyle,
          ),
        ),
      );
    }
    final actualColumns = _editableData[tableName]!.first.keys.toList();
    final validationResult = _validateColumnStructure(tableName, actualColumns);
    final unrecognizedColumns = validationResult.unrecognized;

    if (unrecognizedColumns.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: _buildInfoAlert(
          icon: Icons.check_circle_outlined,
          color: AppColors.schneiderGreen,
          title: "Struktur Kolom Sesuai",
          details: Text(
            "Semua kolom yang ada di file dikenali oleh sistem.",
            style: detailsStyle,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _buildInfoAlert(
        icon: Icons.warning_amber_sharp,
        color: AppColors.orange,
        title: "Struktur Kolom Tidak Sesuai",
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unrecognizedColumns.isNotEmpty) ...[
              const Text(
                "Kolom di file yang tidak dikenali:",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                "  • ${unrecognizedColumns.join('\n  • ')}",
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const Text(
                "Ganti nama kolom ini agar sesuai template/DB, atau hapus jika tidak diperlukan.",
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(String tableName, List<Map<String, dynamic>> rows) {
    final columns = rows.isNotEmpty
        ? rows.first.keys.toList()
        : (_columnEquivalents[tableName.toLowerCase()]?.keys.toList() ?? []);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isCustomTemplate) _buildColumnValidationInfoBox(tableName),
          if (columns.isEmpty && rows.isEmpty)
            Center(child: Text('Tidak ada data untuk tabel "$tableName".'))
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.grayLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      AppColors.grayLight.withOpacity(0.4),
                    ),
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Lexend',
                      color: AppColors.black,
                      fontSize: 12,
                    ),
                    dataTextStyle: const TextStyle(
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Lexend',
                      color: AppColors.black,
                      fontSize: 12,
                    ),
                    columns: [
                      ...columns.map(
                        (col) => DataColumn(
                          label: _buildColumnHeader(tableName, col),
                        ),
                      ),
                      DataColumn(
                        label: IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: AppColors.schneiderGreen,
                          ),
                          tooltip: 'Tambah Kolom',
                          onPressed: () => _showAddColumnBottomSheet(tableName),
                        ),
                      ),
                      const DataColumn(label: Center(child: Text('Aksi'))),
                    ],
                    rows: List.generate(rows.length, (index) {
                      final rowData = rows[index];
                      final isDuplicate =
                          _duplicateRows[tableName]?.contains(index) ?? false;
                      final brokenCells =
                          _brokenRelationCells[tableName]?[index] ?? <String>{};
                      final isInvalidIdentifier =
                          _invalidIdentifierRows[tableName]?.contains(index) ??
                          false;

                      return DataRow(
                        key: ObjectKey(rowData),
                        color: MaterialStateProperty.resolveWith<Color?>((s) {
                          if (isDuplicate)
                            return AppColors.red.withOpacity(0.1);
                          if (isInvalidIdentifier)
                            return AppColors.orange.withOpacity(0.15);
                          return null;
                        }),
                        cells: [
                          ...columns.map(
                            (colName) => DataCell(
                              _buildCellEditor(
                                tableName,
                                index,
                                colName,
                                rowData,
                                isBroken:
                                    brokenCells.contains(colName) &&
                                    !widget.isCustomTemplate,
                              ),
                            ),
                          ),
                          const DataCell(SizedBox()),
                          DataCell(
                            Center(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: AppColors.gray,
                                  size: 18,
                                ),
                                onPressed: () => _showRowActionsBottomSheet(
                                  tableName,
                                  index,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text(
                'Tambah Baris',
                style: TextStyle(
                  fontFamily: 'Lexend',
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              ),
              onPressed: () => _addRow(tableName),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.schneiderGreen,
                side: BorderSide(color: AppColors.gray.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellEditor(
    String tableName,
    int rowIndex,
    String colName,
    Map<String, dynamic> rowData, {
    required bool isBroken,
  }) {
    TextStyle textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w300,
      fontFamily: 'Lexend',
      color: isBroken ? AppColors.red : AppColors.black,
    );
    return SizedBox(
      width: 180,
      child: TextFormField(
        initialValue: rowData[colName]?.toString() ?? '',
        keyboardType:
            (colName.contains('progress') || colName.contains('percent'))
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        cursorColor: AppColors.schneiderGreen,
        style: textStyle,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.schneiderGreen, width: 1.5),
          ),
          enabledBorder: isBroken
              ? const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.red, width: 1.0),
                )
              : const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.transparent),
                ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 2,
          ),
        ),
        onChanged: (value) {
          rowData[colName] = value;
          _revalidateOnDataChange();
        },
      ),
    );
  }

  Widget _buildColumnHeader(String tableName, String columnName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_toTitleCase(columnName)),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.gray),
          onPressed: () => _showColumnActionsBottomSheet(tableName, columnName),
        ),
      ],
    );
  }

  void _showColumnActionsBottomSheet(String tableName, String columnName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.grayLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aksi untuk Kolom "${_toTitleCase(columnName)}"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomSheetAction(
                icon: Icons.edit_outlined,
                title: 'Ganti Nama Kolom',
                onTap: () {
                  Navigator.pop(context);
                  _showRenameColumnBottomSheet(tableName, columnName);
                },
              ),
              const Divider(height: 1),
              _buildBottomSheetAction(
                icon: Icons.delete_outline,
                title: 'Hapus Kolom',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteColumnConfirmationBottomSheet(
                    tableName,
                    columnName,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRowActionsBottomSheet(String tableName, int index) {
    final rowData = _editableData[tableName]![index];
    final isDuplicate = (_duplicateRows[tableName]?.contains(index) ?? false);
    final brokenCells = (_brokenRelationCells[tableName]?[index] ?? <String>{});
    final isInvalidIdentifier =
        (_invalidIdentifierRows[tableName]?.contains(index) ?? false);
    final pkColumn = _getPkColumn(tableName);
    final pkValue = (pkColumn.isNotEmpty && rowData.containsKey(pkColumn))
        ? rowData[pkColumn]
        : 'Baris ${index + 1}';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 5,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.grayLight,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aksi untuk Baris "$pkValue"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              if (widget.isCustomTemplate ||
                  (brokenCells.isEmpty && !isDuplicate && !isInvalidIdentifier))
                const Text(
                  'Tidak ada masalah terdeteksi pada baris ini.',
                  style: TextStyle(color: AppColors.gray),
                ),
              if (isInvalidIdentifier) ...[
                _buildInfoAlert(
                  icon: Icons.error_outline,
                  color: AppColors.orange,
                  title: "Warning: Identifier Wajib Kosong",
                  details: const Text(
                    'Harap isi salah satu dari kolom "No PP", "No Panel", atau "No WBS".',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (brokenCells.isNotEmpty)
                _buildInfoAlert(
                  icon: Icons.error_outline,
                  color: AppColors.red,
                  title: "Error: Relasi Tidak Ditemukan",
                  details: Text(
                    'ID untuk kolom: ${brokenCells.join(', ')} tidak ditemukan.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (isDuplicate) ...[
                if (brokenCells.isNotEmpty) const SizedBox(height: 8),
                _buildInfoAlert(
                  icon: Icons.error_outline,
                  color: AppColors.red,
                  title: "Error: Data Duplikat",
                  details: Text(
                    'Nilai "$pkValue" sudah ada nilai sebelumnya (lihat PP Panel/Username).',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              _buildBottomSheetAction(
                icon: Icons.delete_outline,
                title: 'Hapus Baris',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _deleteRow(tableName, index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameColumnBottomSheet(String tableName, String oldName) {
    final controller = TextEditingController(text: oldName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ganti Nama Kolom',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: 'Masukkan Nama Kolom Baru',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.grayLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.grayLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.schneiderGreen),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildActionButtons(
              context: context,
              onSave: () {
                final newName = controller.text.trim();
                _renameColumn(tableName, oldName, newName);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddColumnBottomSheet(String tableName) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tambah Kolom Baru',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: 'Masukkan Nama Kolom',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.grayLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.grayLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.schneiderGreen),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildActionButtons(
              context: context,
              saveLabel: "Tambah",
              onSave: () {
                final newName = controller.text.trim();
                _addNewColumn(tableName, newName);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteColumnConfirmationBottomSheet(
    String tableName,
    String columnName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hapus Kolom?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda yakin ingin menghapus kolom "${_toTitleCase(columnName)}"? Tindakan ini tidak dapat diurungkan.',
              style: const TextStyle(color: AppColors.gray, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _buildActionButtons(
              context: context,
              saveLabel: "Ya, Hapus",
              isDestructive: true,
              onSave: () {
                _deleteColumn(tableName, columnName);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required BuildContext context,
    required VoidCallback onSave,
    String saveLabel = "Simpan",
    bool isDestructive = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.schneiderGreen),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              "Batal",
              style: TextStyle(color: AppColors.schneiderGreen, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isDestructive
                  ? AppColors.red
                  : AppColors.schneiderGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(saveLabel, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheetAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.red : AppColors.black;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPkColumn(String tableName) {
    const Map<String, String> pkMap = {
      'panels': 'no_pp',
      'companies': 'id',
      'company_accounts': 'username',
      'Panel': 'PP Panel',
      'User': 'Username',
    };
    return pkMap[tableName] ?? '';
  }
}
