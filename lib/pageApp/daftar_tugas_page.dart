import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

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

  // Untuk mencegah kirim email berkali-kali dalam 1 sesi
  final Set<dynamic> _remindedTaskIds = {};
  Timer? _reminderTimer;

  final List<String> _filterOptions = [
    'Semua', 'Belum Mulai', 'Sedang Dikerjakan', 'Selesai', 'Terlambat'
  ];

  @override
  void initState() {
    super.initState();
    _loadTugas(checkReminder: true);
    _startReminderTimer();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  /// Timer untuk cek reminder secara berkala (setiap 1 menit)
  void _startReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadTugas(checkReminder: true),
    );
  }

  /// Gabung deadline_date (yyyy-MM-dd) + deadline_time (HH:mm / HH:mm:ss)
  DateTime _combineDateAndTime(String dateStr, String timeStr) {
    final date = DateTime.parse(dateStr);
    final safeTime = timeStr.length >= 5 ? timeStr.substring(0, 5) : '23:59';
    final parts = safeTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _loadTugas({bool checkReminder = false}) async {
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await _supabase
          .from('tugas')
          .select('*, matakuliah(nama_matkul, kode_matkul)')
          .eq('user_id', user.id)
          .order('deadline_date')
          .order('deadline_time');

      final now = DateTime.now();

      final List<Map<String, dynamic>> loaded = List<Map<String, dynamic>>.from(
        response,
      ).map((t) {
        final deadline = _combineDateAndTime(
          t['deadline_date'] as String,
          t['deadline_time'] as String,
        );

        final reminderMinutes = (t['reminder_minutes_before'] ?? 0) as int;
        final reminderTime = deadline.subtract(Duration(minutes: reminderMinutes));

        final isReminderActive = reminderMinutes > 0 &&
            now.isAfter(reminderTime) &&
            now.isBefore(deadline) &&
            t['status'] != 'Selesai';

        return {
          ...t,
          'deadlineDateTime': deadline,
          'isReminderActive': isReminderActive,
        };
      }).toList();

      setState(() {
        _tugas = loaded;
        _isLoading = false;
      });

      if (checkReminder) {
        _processReminders();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tugas: $e')),
        );
      }
    }
  }

  /// Cari tugas yang sudah masuk waktu reminder dan kirim email (sekali per sesi)
  Future<void> _processReminders() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) return;

    for (final tugas in _tugas) {
      final isReminderActive = tugas['isReminderActive'] == true;
      final id = tugas['id'];

      if (isReminderActive && !_remindedTaskIds.contains(id)) {
        await _sendEmailReminder(user.email!, tugas);
        _remindedTaskIds.add(id);
      }
    }
  }

  /// Kirim email reminder via EmailJS (demo only)
  Future<void> _sendEmailReminder(String toEmail, Map<String, dynamic> tugas) async {

    const serviceId = 'service_fnz4rb8';
    const templateId = 'template_x50dax9';
    const publicKey = 'slzHNXp4uaAde0FgA';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final deadlineStr =
        '${tugas['deadline_date']} ${tugas['deadline_time'].toString().substring(0, 5)}';

    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost', // atau origin web kamu
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            // sesuaikan dengan template EmailJS kamu
            'to_email': toEmail,
            'task_name': tugas['nama_tugas'],
            'task_deadline': deadlineStr,
            'task_priority': tugas['prioritas'] ?? '-',
          },
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Email reminder dikirim untuk "${tugas['nama_tugas']}"'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal kirim email reminder (${response.statusCode})',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error kirim email reminder: $e'),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTugas {
    List<Map<String, dynamic>> list;

    if (_selectedFilter == 'Semua') {
      list = List<Map<String, dynamic>>.from(_tugas);
    } else {
      list = _tugas.where((tugas) => tugas['status'] == _selectedFilter).toList();
    }

    // Urutkan:
    // 1) yang isReminderActive = true di atas
    // 2) berdasarkan deadline paling cepat
    list.sort((a, b) {
      final aReminder = (a['isReminderActive'] ?? false) ? 1 : 0;
      final bReminder = (b['isReminderActive'] ?? false) ? 1 : 0;

      if (aReminder != bReminder) {
        return bReminder - aReminder;
      }

      final aDeadline = (a['deadlineDateTime'] as DateTime?) ??
          _combineDateAndTime(a['deadline_date'], a['deadline_time']);
      final bDeadline = (b['deadlineDateTime'] as DateTime?) ??
          _combineDateAndTime(b['deadline_date'], b['deadline_time']);

      return aDeadline.compareTo(bDeadline);
    });

    return list;
  }

  Future<void> _updateStatus(dynamic tugasId, String newStatus) async {
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
                    ).then((_) => _loadTugas(checkReminder: true));
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
                        onRefresh: () => _loadTugas(checkReminder: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredTugas.length,
                          itemBuilder: (context, index) {
                            final tugas = _filteredTugas[index];

                            final deadline = (tugas['deadlineDateTime'] as DateTime?) ??
                                _combineDateAndTime(
                                  tugas['deadline_date'] as String,
                                  tugas['deadline_time'] as String,
                                );

                            final isOverdue = deadline.isBefore(DateTime.now()) &&
                                tugas['status'] != 'Selesai';

                            final isReminderActive = tugas['isReminderActive'] == true;
                            final isCompleted = tugas['status'] == 'Selesai';
                            
                            return Opacity(
                              opacity: isCompleted ? 0.4 : 1.0,
                              child: Card(
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

                                                      if (isReminderActive) ...[
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red[50],
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(color: Colors.red),
                                                          ),
                                                          child: const Text(
                                                            'REMINDER',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
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
              if (tugas['deskripsi'] != null && tugas['deskripsi'].toString().isNotEmpty) ...[
                const Text(
                  'Deskripsi:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(tugas['deskripsi']),
                const SizedBox(height: 16),
              ],
              
              if (tugas['catatan'] != null && tugas['catatan'].toString().isNotEmpty) ...[
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
