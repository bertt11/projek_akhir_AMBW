import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_tugas_page.dart';

class DaftarTugasPage extends StatefulWidget {
  const DaftarTugasPage({super.key});

  @override
  State<DaftarTugasPage> createState() => _DaftarTugasPageState();
}

class _DaftarTugasPageState extends State<DaftarTugasPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tugas = [];
  bool _isLoading = true;
  String _selectedFilter = 'Semua';

  final List<String> _filterOptions = [
    'Semua', 'Belum Mulai', 'Sedang Dikerjakan', 'Selesai', 'Terlambat'
  ];

  @override
  void initState() {
    super.initState();
    _loadTugas();
  }

  Future<void> _loadTugas() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('tugas')
          .select('*, matakuliah(nama_matkul, kode_matkul)')
          .eq('user_id', user.id)
          .order('deadline_date')
          .order('deadline_time');

      setState(() {
        _tugas = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tugas: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTugas {
    if (_selectedFilter == 'Semua') {
      return _tugas;
    }
    return _tugas.where((tugas) => tugas['status'] == _selectedFilter).toList();
  }

  Future<void> _updateStatus(String tugasId, String newStatus) async {
    try {
      await _supabase
          .from('tugas')
          .update({'status': newStatus})
          .eq('id', tugasId);
      
      await _loadTugas();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status berhasil diupdate ke: $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    final difference = taskDate.difference(today).inDays;
    
    if (difference == 0) return 'Hari ini';
    if (difference == 1) return 'Besok';
    if (difference == -1) return 'Kemarin';
    if (difference > 1) return '${difference} hari lagi';
    if (difference < -1) return '${difference.abs()} hari lalu';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getPriorityColor(String prioritas) {
    switch (prioritas) {
      case 'Rendah': return Colors.green;
      case 'Sedang': return Colors.orange;
      case 'Tinggi': return Colors.red;
      case 'Urgent': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Belum Mulai': return Colors.grey;
      case 'Sedang Dikerjakan': return Colors.blue;
      case 'Selesai': return Colors.green;
      case 'Terlambat': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter dan Add Button
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _filterOptions.map((filter) {
                      return DropdownMenuItem(
                        value: filter,
                        child: Text(filter),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedFilter = value!);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TambahTugasPage(),
                      ),
                    ).then((_) => _loadTugas());
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah'),
                ),
              ],
            ),
          ),
          
          // List Tugas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTugas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'Semua' 
                                  ? 'Belum ada tugas'
                                  : 'Tidak ada tugas dengan status $_selectedFilter',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTugas,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTugas.length,
                          itemBuilder: (context, index) {
                            final tugas = _filteredTugas[index];
                            final isOverdue = DateTime.parse(tugas['deadline_date'])
                                .isBefore(DateTime.now()) && tugas['status'] != 'Selesai';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _showTugasDetail(tugas),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getPriorityColor(tugas['prioritas']),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tugas['nama_tugas'],
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: _getPriorityColor(tugas['prioritas']),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        tugas['prioritas'],
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      tugas['jenis_tugas'],
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(tugas['status']),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              tugas['status'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Deadline Info
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isOverdue ? Colors.red[50] : Colors.blue[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 16,
                                              color: isOverdue ? Colors.red : Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Deadline: ${_formatDate(tugas['deadline_date'])} ${tugas['deadline_time'].substring(0, 5)}',
                                              style: TextStyle(
                                                color: isOverdue ? Colors.red[700] : Colors.blue[700],
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                            if (tugas['matakuliah'] != null) ...[
                                              const Spacer(),
                                              Icon(
                                                Icons.book,
                                                size: 14,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                tugas['matakuliah']['kode_matkul'],
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showTugasDetail(Map<String, dynamic> tugas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tugas['nama_tugas'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Status Update
              const Text(
                'Update Status:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Belum Mulai', 'Sedang Dikerjakan', 'Selesai'].map((status) {
                  final isSelected = tugas['status'] == status;
                  return FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _updateStatus(tugas['id'], status);
                        Navigator.pop(context);
                      }
                    },
                    selectedColor: _getStatusColor(status).withOpacity(0.3),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              
              // Detail Info
              if (tugas['deskripsi'] != null && tugas['deskripsi'].isNotEmpty) ...[
                const Text(
                  'Deskripsi:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(tugas['deskripsi']),
                const SizedBox(height: 16),
              ],
              
              if (tugas['catatan'] != null && tugas['catatan'].isNotEmpty) ...[
                const Text(
                  'Catatan:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(tugas['catatan']),
              ],
            ],
          ),
        ),
      ),
    );
  }
}