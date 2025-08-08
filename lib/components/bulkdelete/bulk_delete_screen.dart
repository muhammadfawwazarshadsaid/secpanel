// filename: lib/components/bulkdelete/bulk_delete_screen.dart
import 'package:flutter/material.dart';
import 'package:secpanel/helpers/db_helper.dart';
import 'package:secpanel/models/paneldisplaydata.dart';
import 'package:secpanel/theme/colors.dart';

// Class untuk membawa hasil kembali ke halaman utama
class BulkDeleteResult {
  final bool success;
  final String message;
  final bool dataHasChanged;

  BulkDeleteResult({
    required this.success,
    required this.message,
    this.dataHasChanged = false,
  });
}

class BulkDeleteBottomSheet extends StatefulWidget {
  const BulkDeleteBottomSheet({super.key});

  @override
  State<BulkDeleteBottomSheet> createState() => _BulkDeleteBottomSheetState();
}

class _BulkDeleteBottomSheetState extends State<BulkDeleteBottomSheet> {
  List<PanelDisplayData> _panels = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  final Set<String> _selectedPanelPks = {};
  bool _dataHasChanged = false;

  @override
  void initState() {
    super.initState();
    _loadPanels();
  }

  Future<void> _loadPanels() async {
    setState(() => _isLoading = true);
    try {
      final panelsData = await DatabaseHelper.instance.getAllPanelsForDisplay(
        currentUser: null, // Tetap null untuk mengambil semua data
        rawIds: true, // Ini akan meminta No. PP yang asli (TEMP_PP_...)
      );
      if (mounted) {
        setState(() {
          _panels = panelsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // [PERBAIKAN] Langsung tutup bottom sheet dengan hasil error
        Navigator.of(context).pop(
          BulkDeleteResult(
            success: false,
            message: 'Gagal memuat data panel: $e',
            dataHasChanged: false,
          ),
        );
      }
    }
  }

  void _onSelectAll(bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedPanelPks.addAll(_panels.map((p) => p.panel.noPp));
      } else {
        _selectedPanelPks.clear();
      }
    });
  }

  Future<bool> _showConfirmationBottomSheet({
    required String title,
    required String content,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext innerContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.grayLight,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.red,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.gray),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(innerContext, false),
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
                      onPressed: () => Navigator.pop(innerContext, true),
                      style: ElevatedButton.styleFrom(
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        "Ya, Hapus",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _deleteSinglePanel(String noPp, String? noPanel) async {
    final confirm = await _showConfirmationBottomSheet(
      title: 'Hapus Panel?',
      content:
          'Anda yakin ingin menghapus panel "$noPanel"? Tindakan ini tidak dapat dibatalkan.',
    );

    if (confirm && mounted) {
      try {
        await DatabaseHelper.instance.deletePanel(noPp);
        _dataHasChanged = true;
        _selectedPanelPks.remove(noPp);
        // Refresh list secara lokal tanpa menutup bottom sheet
        await _loadPanels();
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(
            BulkDeleteResult(
              success: false,
              message: 'Gagal menghapus panel "$noPanel": $e',
              dataHasChanged: _dataHasChanged,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSelectedPanels() async {
    final count = _selectedPanelPks.length;
    final confirm = await _showConfirmationBottomSheet(
      title: 'Konfirmasi Hapus Massal',
      content:
          'Anda yakin ingin menghapus $count panel yang dipilih? Tindakan ini tidak dapat dibatalkan.',
    );

    if (confirm && mounted) {
      setState(() => _isDeleting = true);
      try {
        await DatabaseHelper.instance.deletePanels(_selectedPanelPks.toList());

        // [PERBAIKAN] Sekarang API request berhasil, tutup bottom sheet dengan hasil sukses.
        Navigator.of(context).pop(
          BulkDeleteResult(
            success: true,
            message: '$count panel berhasil dihapus.',
            dataHasChanged: true,
          ),
        );
      } catch (e) {
        // [PERBAIKAN] Jika API request (yang sudah diperbaiki) tetap gagal,
        // tutup bottom sheet dengan hasil error.
        Navigator.of(context).pop(
          BulkDeleteResult(
            success: false,
            message: 'Gagal menghapus panel: $e',
            // _dataHasChanged bisa jadi true jika beberapa operasi single delete berhasil sebelumnya
            dataHasChanged: _dataHasChanged,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isDeleting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionEmpty = _selectedPanelPks.isEmpty;

    // [PERBAIKAN] Menyederhanakan PopScope.
    // onPopInvoked tidak perlu memanggil Navigator.pop() lagi karena itu menyebabkan error.
    // Cukup kembalikan result saat tombol 'Tutup' ditekan.
    return PopScope(
      canPop: !_isDeleting,
      onPopInvoked: (didPop) {
        if (!didPop) return;
        // Ketika pop terjadi (misal via gesture), kita perlu mengembalikan hasil.
        // Navigator.pop(context) yang dipanggil oleh framework tidak membawa nilai.
        // Solusinya adalah membiarkan `then` di main_screen menangani nilai null dan
        // menganggapnya sebagai penutupan manual.
      },
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  Container(
                    height: 5,
                    width: 40,
                    decoration: BoxDecoration(
                      color: AppColors.grayLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Bulk Delete Panel',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.schneiderGreen,
                      ),
                    )
                  : _panels.isEmpty
                  ? const Center(
                      child: Text(
                        "Tidak ada data panel.",
                        style: TextStyle(color: AppColors.gray),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          checkboxTheme: CheckboxThemeData(
                            fillColor:
                                MaterialStateProperty.resolveWith<Color?>((
                                  Set<MaterialState> states,
                                ) {
                                  if (states.contains(MaterialState.selected)) {
                                    return AppColors.schneiderGreen;
                                  }
                                  return null;
                                }),
                            checkColor: MaterialStateProperty.all(Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            onSelectAll: _onSelectAll,
                            headingRowColor: MaterialStateProperty.all(
                              AppColors.grayLight.withOpacity(0.4),
                            ),
                            columns: const [
                              DataColumn(label: Text('No. Panel')),
                              DataColumn(label: Text('No. PP')),
                              DataColumn(label: Text('Project')),
                              DataColumn(label: Text('Vendor Panel')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: _panels.map((data) {
                              final panel = data.panel;
                              final isSelected = _selectedPanelPks.contains(
                                panel.noPp,
                              );
                              return DataRow(
                                selected: isSelected,
                                onSelectChanged: _isDeleting
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _selectedPanelPks.add(panel.noPp);
                                          } else {
                                            _selectedPanelPks.remove(
                                              panel.noPp,
                                            );
                                          }
                                        });
                                      },
                                cells: [
                                  DataCell(Text(panel.noPanel ?? '-')),
                                  DataCell(
                                    Text(
                                      panel.noPp.startsWith("TEMP_PP_")
                                          ? ''
                                          : panel.noPp,
                                    ),
                                  ),
                                  DataCell(Text(panel.project ?? '-')),
                                  DataCell(Text(data.panelVendorName)),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.red,
                                      ),
                                      onPressed: _isDeleting
                                          ? null
                                          : () => _deleteSinglePanel(
                                              panel.noPp,
                                              panel.noPanel,
                                            ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      // [PERBAIKAN] Tombol tutup sekarang mengirimkan hasil yang benar.
                      onPressed: _isDeleting
                          ? null
                          : () => Navigator.of(context).pop(
                              BulkDeleteResult(
                                success:
                                    true, // Dianggap sukses karena tidak ada error
                                message: '', // Tidak ada pesan
                                dataHasChanged: _dataHasChanged,
                              ),
                            ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.schneiderGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text(
                        "Tutup",
                        style: TextStyle(
                          color: AppColors.schneiderGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isDeleting
                          ? Container()
                          : const Icon(Icons.delete_forever_outlined),
                      label: _isDeleting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              'Hapus (${_selectedPanelPks.length})',
                              style: const TextStyle(fontSize: 12),
                            ),
                      onPressed: isSelectionEmpty || _isDeleting
                          ? null
                          : _deleteSelectedPanels,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.grayLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
