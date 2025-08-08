import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:secpanel/components/import/confirm_import_bottom_sheet.dart';
import 'package:secpanel/components/import/import_progress_dialog.dart';
import 'package:secpanel/helpers/db_helper.dart';
import 'package:secpanel/models/approles.dart';
import 'package:secpanel/models/company.dart';
import 'package:secpanel/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late List<Map<String, dynamic>> _existingPanelKeys;
  late Map<String, Set<int>> _updateRows;
  late Map<String, Set<String>> _existingPrimaryKeys;
  List<Company> _allCompanies = [];
  Map<String, String> _companyIdToName = {};

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
    _existingPanelKeys = [];
    _updateRows = {};
    _initializeAndValidateData();
  }

  Future<void> _fetchExistingNaturalKeys() async {
    _existingPanelKeys = await DatabaseHelper.instance.getPanelKeys();
  }

  Future<void> _initializeAndValidateData() async {
    if (mounted) setState(() => _isLoading = true);

    _cleanNumericPrimaryKeys();
    await _fetchAllCompanies();
    await _fetchExistingPrimaryKeys();
    await _fetchExistingNaturalKeys(); // <-- PANGGIL FUNGSI BARU DI SINI

    await _resolveVendorNamesToIds();
    _revalidateOnDataChange(); // <-- Ganti ini menjadi _revalidateAll()
    if (mounted) setState(() => _isLoading = false);
  }

  // Ganti nama _revalidateOnDataChange menjadi _revalidateAll
  void _revalidateAll() {
    setState(() {
      _validateUpdatesAndDuplicates(); // <-- Ganti ini
      _validateBrokenRelations();
      _validateMissingIdentifiers();
    });
  }

  Future<void> _fetchAllCompanies() async {
    _allCompanies = await DatabaseHelper.instance.getAllCompanies();
    _companyIdToName = {for (var c in _allCompanies) c.id: c.name};
    if (mounted) setState(() {});
  }

  Future<void> _fetchExistingPrimaryKeys() async {
    final dbHelper = DatabaseHelper.instance;
    _existingPrimaryKeys = {
      'companies': (await dbHelper.getAllCompanies()).map((c) => c.id).toSet(),
      'company_accounts': (await dbHelper.getAllCompanyAccounts())
          .map((a) => a.username)
          .toSet(),
      'panels': (await dbHelper.getAllPanels())
          .map((p) => p.noPp.trim().toLowerCase())
          .toSet(),
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

  void _validateUpdatesAndDuplicates() {
    _duplicateRows = {};
    _updateRows = {};
    final String tableName = 'panel';

    if (!_editableData.containsKey(tableName)) return;

    final rows = _editableData[tableName]!;
    if (rows.isEmpty) return;

    _duplicateRows.putIfAbsent(tableName, () => {});
    _updateRows.putIfAbsent(tableName, () => {});

    // Buat lookup map dari kunci alami untuk pencarian cepat
    final naturalKeyToDbRow = <String, Map<String, dynamic>>{};
    for (final keyInfo in _existingPanelKeys) {
      final panelNo = keyInfo['no_panel']?.toString().toLowerCase() ?? '';
      final project = keyInfo['project']?.toString().toLowerCase() ?? '';
      final wbs = keyInfo['no_wbs']?.toString().toLowerCase() ?? '';
      if (panelNo.isNotEmpty || project.isNotEmpty || wbs.isNotEmpty) {
        naturalKeyToDbRow["${panelNo}_${project}_${wbs}"] = keyInfo;
      }
    }

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final newNoPp =
          row[_findPrimaryKeyColumnName(tableName, row.keys.toList()) ?? '']
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      final noPanel = row['Panel No']?.toString().toLowerCase() ?? '';
      final project = row['PROJECT']?.toString().toLowerCase() ?? '';
      final wbs = row['WBS']?.toString().toLowerCase() ?? '';

      final naturalKey = "${noPanel}_${project}_${wbs}";

      // Cek duplikasi berdasarkan No PP asli
      if (newNoPp.isNotEmpty &&
          _existingPrimaryKeys['panels']!.contains(newNoPp)) {
        _duplicateRows[tableName]!.add(i);
        continue;
      }

      // Cek berdasarkan kunci alami
      if (naturalKeyToDbRow.containsKey(naturalKey)) {
        final dbRow = naturalKeyToDbRow[naturalKey]!;
        final existingNoPp = dbRow['no_pp']?.toString().toLowerCase() ?? '';

        // KASUS UPDATE (HIJAU)
        if (existingNoPp.startsWith('temp_pp_') &&
            newNoPp.isNotEmpty &&
            !newNoPp.startsWith('temp_pp_')) {
          _updateRows[tableName]!.add(i);
        }
        // KASUS DUPLIKAT (MERAH)
        else {
          _duplicateRows[tableName]!.add(i);
        }
      }
    }
  }

  void _cleanNumericPrimaryKeys() {
    // Kita hanya menargetkan sheet/tabel 'panel'
    final String tableName = 'panel';
    if (!_editableData.containsKey(tableName) ||
        _editableData[tableName]!.isEmpty) {
      return;
    }

    final rows = _editableData[tableName]!;
    // Cari nama kolom Primary Key secara dinamis ('PP Panel' atau 'no_pp')
    final pkColumn = _findPrimaryKeyColumnName(
      tableName,
      rows.first.keys.toList(),
    );

    if (pkColumn == null) {
      return; // Jika kolom PK tidak ditemukan, hentikan proses
    }

    // Iterasi setiap baris dan bersihkan nilai PK
    for (final row in rows) {
      final pkValue = row[pkColumn];

      // Cek jika nilainya sudah berupa angka (hasil parse Excel)
      if (pkValue is num) {
        row[pkColumn] = pkValue.toInt().toString();
      }
      // Cek jika nilainya berupa string yang terlihat seperti angka desimal
      else if (pkValue is String) {
        final numValue = double.tryParse(pkValue);
        // Cek ini memastikan kita hanya mengubah angka seperti "123.0" menjadi "123"
        if (numValue != null && numValue == numValue.truncate()) {
          row[pkColumn] = numValue.toInt().toString();
        }
      }
    }
  }

  /// [PERBAIKAN TOTAL] Logika validasi relasi diperbaiki agar lebih ketat dan akurat.
  void _validateBrokenRelations() {
    _brokenRelationCells = {};

    // Kunci yang valid HANYA yang dari database.
    final validCompanyIDs = Set<String>.from(
      _existingPrimaryKeys['companies'] ?? {},
    );

    // Daftar nama kolom DB yang merupakan foreign key ke tabel companies
    const companyForeignKeyDbNames = {
      'vendor_id',
      'busbar_vendor_id',
      'vendor',
      'company_id',
    };

    _editableData.forEach((tableName, rows) {
      if (rows.isEmpty) return;
      _brokenRelationCells.putIfAbsent(tableName, () => {});

      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        _brokenRelationCells[tableName]!.putIfAbsent(i, () => {});

        for (final actualColName in row.keys) {
          // Cari nama kolom versi database-nya

          final equivalents = _columnEquivalents[tableName.toLowerCase()];
          String dbColName = actualColName; // Default value

          if (equivalents != null) {
            for (var entry in equivalents.entries) {
              // Bandingkan setelah keduanya diubah ke huruf kecil
              if (entry.key.toLowerCase() == actualColName.toLowerCase()) {
                dbColName = entry.value; // Jika cocok, gunakan nama kolom DB
                break; // Hentikan pencarian
              }
            }
          }
          if (companyForeignKeyDbNames.contains(dbColName)) {
            final fkValue = row[actualColName]?.toString() ?? '';

            if (fkValue.isNotEmpty && !validCompanyIDs.contains(fkValue)) {
              _brokenRelationCells[tableName]![i]!.add(actualColName);
            }
          }
          // Periksa apakah ini kolom yang perlu divalidasi relasinya ke tabel company
          if (companyForeignKeyDbNames.contains(dbColName)) {
            final fkValue = row[actualColName]?.toString() ?? '';

            // Tandai error HANYA JIKA kolom terisi tapi isinya tidak ada di daftar ID valid
            // Setelah _resolveVendorNamesToIds berjalan, sel yang valid berisi ID,
            // yang tidak valid tetap berisi nama asli dari file.
            // Pengecekan ini akan secara otomatis menandai merah sel yang berisi nama tak dikenal.
            if (fkValue.isNotEmpty && !validCompanyIDs.contains(fkValue)) {
              _brokenRelationCells[tableName]![i]!.add(actualColName);
            }
          }
        }
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
      _validateUpdatesAndDuplicates();
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
    // Bagian ini memeriksa validasi di sisi klien (aplikasi) terlebih dahulu
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
    if (hasBrokenRelations) {
      _showErrorSnackBar(
        'Masih ada relasi data yang belum valid (ditandai merah). Harap perbaiki.',
      );
      return;
    }

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

    // --- [PERBAIKAN UTAMA DI BLOK TRY-CATCH] ---
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

      // Jika sukses
      if (mounted) {
        Navigator.of(context).pop(); // Tutup progress dialog
        Navigator.of(context).pop(true); // Tutup ImportReviewScreen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultMessage),
            backgroundColor: AppColors.schneiderGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Jika GAGAL (termasuk error validasi dari server)
      if (mounted) {
        Navigator.of(context).pop(); // Tutup progress dialog

        final message = e.toString().replaceFirst("Exception: ", "");

        // Tampilkan bottom sheet dengan daftar error
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ImportErrorBottomSheet(errorMessage: message),
        );
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

  String _normalizeSimple(String name) {
    return name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
  }

  String _normalizeAcronym(String name) {
    const prefixes = ['PT', 'CV', 'UD'];
    String cleanedName = name.toUpperCase();
    for (var prefix in prefixes) {
      final regex = RegExp(r'^' + prefix + r'\.?\s+', caseSensitive: false);
      cleanedName = cleanedName.replaceAll(regex, '');
    }

    if (!cleanedName.contains(' ')) return '';

    return cleanedName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }

  Future<int> _resolveVendorNamesToIds() async {
    int corrections = 0;
    if (_allCompanies.isEmpty) return 0;

    final Map<String, Company> simpleNormalizedMap = {
      for (var company in _allCompanies)
        _normalizeSimple(company.name): company,
    };

    final columnsToResolve = {
      'vendor_id',
      'panel',
      'busbar_vendor_id',
      'busbar',
      'vendor',
    };

    _editableData.forEach((tableName, rows) {
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        for (final colName in row.keys) {
          if (columnsToResolve.contains(colName.toLowerCase())) {
            final value = (row[colName]?.toString() ?? '').trim();
            if (value.isEmpty ||
                (_existingPrimaryKeys['companies']?.contains(value) ?? false)) {
              continue;
            }

            Company? matchedCompany;

            final simpleNormalizedValue = _normalizeSimple(value);
            if (simpleNormalizedMap.containsKey(simpleNormalizedValue)) {
              matchedCompany = simpleNormalizedMap[simpleNormalizedValue];
            }

            if (matchedCompany == null) {
              final acronymNormalizedValue = _normalizeAcronym(value);
              if (acronymNormalizedValue.isNotEmpty &&
                  simpleNormalizedMap.containsKey(acronymNormalizedValue)) {
                matchedCompany = simpleNormalizedMap[acronymNormalizedValue];
              }
            }

            if (matchedCompany != null) {
              _editableData[tableName]![i][colName] = matchedCompany.id;
              corrections++;
            }
          }
        }
      }
    });
    return corrections;
  }

  Future<void> _runAutocorrect() async {
    final corrections = await _resolveVendorNamesToIds();

    if (!mounted) return;

    if (corrections > 0) {
      _revalidateOnDataChange();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$corrections relasi data berhasil diperbaiki secara otomatis.',
          ),
          backgroundColor: AppColors.schneiderGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada relasi data yang dapat diperbaiki secara otomatis.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_fix_high_outlined),
              tooltip: 'Perbaiki Relasi Otomatis',
              onPressed: _runAutocorrect,
            ),
            const SizedBox(width: 8),
          ],
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

    bool hasError =
        hasDuplicates || hasInvalidIdentifiers || (hasBrokenRelations);
    bool hasWarning = hasBrokenRelations && widget.isCustomTemplate;

    Color? indicatorColor;
    if (hasError) {
      indicatorColor = AppColors.red;
    } else if (hasWarning) {
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
                " • ${unrecognizedColumns.join('\n • ')}",
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
                      final isUpdate =
                          _updateRows[tableName]?.contains(index) ?? false;
                      final brokenCells =
                          _brokenRelationCells[tableName]?[index] ?? <String>{};
                      final isInvalidIdentifier =
                          _invalidIdentifierRows[tableName]?.contains(index) ??
                          false;

                      // Cek apakah ada kolom 'panel' atau 'busbar' yang bermasalah.
                      final isPanelBusbarProblematic = brokenCells.any((col) {
                        final normalizedCol = col.toLowerCase();
                        return (normalizedCol == 'panel' ||
                                normalizedCol == 'busbar_vendor_id') &&
                            (rowData[col] as String?)?.isNotEmpty == true;
                      });

                      return DataRow(
                        key: ObjectKey(rowData),
                        color: MaterialStateProperty.resolveWith<Color?>((s) {
                          // [PERBAIKAN] Tambahkan kondisi untuk warna hijau
                          if (isUpdate) {
                            return Colors.green.withOpacity(0.15);
                          }

                          bool hasError =
                              isDuplicate ||
                              isInvalidIdentifier ||
                              (brokenCells.isNotEmpty);
                          if (hasError) {
                            return AppColors.red.withOpacity(0.15);
                          }
                          if (isPanelBusbarProblematic) {
                            // Cek tambahan untuk kondisi yang diminta
                            return AppColors.red.withOpacity(0.15);
                          }
                          if (brokenCells.isNotEmpty &&
                              widget.isCustomTemplate) {
                            return AppColors.orange.withOpacity(0.15);
                          }
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
                                isBroken: brokenCells.contains(colName),
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

  Future<void> _showCompanySelectorForCell(
    String tableName,
    int rowIndex,
    String colName,
  ) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CompanySelectorBottomSheet(
          allCompanies: _allCompanies,
          initialCompanyId: _editableData[tableName]![rowIndex][colName],
          onCompanyAdded: () async {
            await _fetchAllCompanies();
            await _fetchExistingPrimaryKeys();
          },
        );
      },
    );

    if (selectedId != null && mounted) {
      setState(() {
        _editableData[tableName]![rowIndex][colName] = selectedId;
        _revalidateOnDataChange();
      });
    }
  }

  Widget _buildCompanySelectorCell(
    String tableName,
    int rowIndex,
    String colName,
    Map<String, dynamic> rowData, {
    required bool isBroken,
  }) {
    final companyId = rowData[colName]?.toString() ?? '';
    final companyName = _companyIdToName[companyId] ?? companyId;

    // Periksa apakah kolom 'panel' atau 'busbar' tidak terpilih (companyId kosong)
    // dan bukan bagian dari template kustom.
    final bool isNotSelected = companyId.isEmpty;
    final bool isProblematic =
        isBroken || (isNotSelected && !widget.isCustomTemplate);

    TextStyle textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w300,
      fontFamily: 'Lexend',
      color: isProblematic ? AppColors.red : AppColors.black,
    );

    return InkWell(
      onTap: () => _showCompanySelectorForCell(tableName, rowIndex, colName),
      child: Container(
        width: 180,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isProblematic ? AppColors.red : Colors.transparent,
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                companyName.isEmpty ? 'Pilih...' : companyName,
                style: companyName.isEmpty
                    ? textStyle.copyWith(color: AppColors.gray)
                    : textStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.gray, size: 20),
          ],
        ),
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
    final normalizedColName = colName.toLowerCase();
    final isVendorColumn =
        (normalizedColName == 'panel' || normalizedColName == 'vendor_id') ||
        (normalizedColName == 'busbar' ||
            normalizedColName == 'busbar_vendor_id');

    if (tableName.toLowerCase() == 'panel' && isVendorColumn) {
      return _buildCompanySelectorCell(
        tableName,
        rowIndex,
        colName,
        rowData,
        isBroken: isBroken,
      );
    }

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
                  color: AppColors.red,
                  title: "Error: Identifier Wajib Kosong",
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

class _CompanySelectorBottomSheet extends StatefulWidget {
  final List<Company> allCompanies;
  final String? initialCompanyId;
  final Future<void> Function() onCompanyAdded;

  const _CompanySelectorBottomSheet({
    required this.allCompanies,
    this.initialCompanyId,
    required this.onCompanyAdded,
  });

  @override
  State<_CompanySelectorBottomSheet> createState() =>
      _CompanySelectorBottomSheetState();
}

class _CompanySelectorBottomSheetState
    extends State<_CompanySelectorBottomSheet> {
  late List<Company> _companies;
  String? _selectedCompanyId;

  @override
  void initState() {
    super.initState();
    _companies = List.from(widget.allCompanies);
    _companies.sort((a, b) => a.name.compareTo(b.name));
    _selectedCompanyId = widget.initialCompanyId;
  }

  Future<void> _showAddNewCompanySheet() async {
    final newCompanyData = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AddNewCompanyRoleSheet(),
    );

    if (newCompanyData != null && mounted) {
      final String newName = newCompanyData['name'];
      final AppRole newRole = newCompanyData['role'];
      final String companyId = newName.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '_',
      );

      try {
        final newCompany = Company(id: companyId, name: newName, role: newRole);
        await DatabaseHelper.instance.insertCompany(newCompany);
        await widget.onCompanyAdded();
        if (mounted) {
          setState(() {
            _companies.add(newCompany);
            _companies.sort((a, b) => a.name.compareTo(b.name));
            _selectedCompanyId = newCompany.id;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal menambahkan perusahaan: ${e.toString().replaceFirst("Exception: ", "")}',
              ),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          const Text(
            'Pilih Perusahaan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  ..._companies.map((company) {
                    return _buildCompanyOptionButton(
                      name: company.name,
                      role: company.role.name,
                      selected: _selectedCompanyId == company.id,
                      onTap: () {
                        setState(() => _selectedCompanyId = company.id);
                      },
                    );
                  }),
                  _buildOtherButton(onTap: _showAddNewCompanySheet),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
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
                  onPressed: () => Navigator.pop(context, _selectedCompanyId),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.schneiderGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text("Pilih", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyOptionButton({
    required String name,
    required String role,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color borderColor = selected
        ? AppColors.schneiderGreen
        : AppColors.grayLight;
    final Color color = selected
        ? AppColors.schneiderGreen.withOpacity(0.08)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                role[0].toUpperCase() + role.substring(1),
                style: const TextStyle(fontSize: 10, color: AppColors.gray),
              ),
              backgroundColor: AppColors.grayLight,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.grayLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "Lainnya...",
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: AppColors.gray,
          ),
        ),
      ),
    );
  }
}

class _AddNewCompanyRoleSheet extends StatefulWidget {
  const _AddNewCompanyRoleSheet();
  @override
  State<_AddNewCompanyRoleSheet> createState() =>
      _AddNewCompanyRoleSheetState();
}

class _AddNewCompanyRoleSheetState extends State<_AddNewCompanyRoleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  AppRole _selectedRole = AppRole.k3;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'role': _selectedRole,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
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
              "Tambah Perusahaan Baru",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Company',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  cursorColor: AppColors.schneiderGreen,
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: AppColors.black,
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Nama tidak boleh kosong'
                      : null,
                  decoration: InputDecoration(
                    fillColor: AppColors.white,
                    filled: true,
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
                      borderSide: const BorderSide(
                        color: AppColors.schneiderGreen,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRoleSelector(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: AppRole.values.map((role) {
            if (role == AppRole.admin) return const SizedBox.shrink();
            return _buildOptionButton(
              label: role.name[0].toUpperCase() + role.name.substring(1),
              selected: _selectedRole == role,
              onTap: () => setState(() => _selectedRole = role),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color borderColor = selected
        ? AppColors.schneiderGreen
        : AppColors.grayLight;
    final Color color = selected
        ? AppColors.schneiderGreen.withOpacity(0.08)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.schneiderGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text("Simpan", style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
// Lokasi: lib/import_review_screen.dart
// Tambahkan class ini di paling bawah file

class _ImportErrorBottomSheet extends StatelessWidget {
  final String errorMessage;

  const _ImportErrorBottomSheet({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    // Memisahkan judul dari daftar error
    final parts = errorMessage.split('\n- ');
    final title = parts.first.replaceAll(
      'Impor dibatalkan karena error berikut:',
      'Validasi Gagal',
    );
    final errors = parts.length > 1 ? parts.sublist(1) : <String>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Harap perbaiki masalah berikut di dalam tabel sebelum menyimpan kembali:',
            style: TextStyle(
              color: AppColors.gray,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.05),
                border: Border.all(color: AppColors.red.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                itemCount: errors.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 12, color: Colors.transparent),
                itemBuilder: (context, index) {
                  return Text(
                    '• ${errors[index]}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.red,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
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
                "Perbaiki Sekarang",
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
