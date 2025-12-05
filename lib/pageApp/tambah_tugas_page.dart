import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TambahTugasPage extends StatefulWidget {
  const TambahTugasPage({super.key});

  @override
  State<TambahTugasPage> createState() => _TambahTugasPageState();
}

class _TambahTugasPageState extends State<TambahTugasPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaTugasController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _catatanController = TextEditingController();
  
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _matakuliahList = [];
  String? _selectedMatakuliahId;
  String _selectedJenisTugas = 'Individu';
  String _selectedPrioritas = 'Sedang';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 23, minute: 59);
  bool _isLoading = false;

  final List<String> _jenisTugasList = [
    'Individu', 'Kelompok', 'Quiz', 'UTS', 'UAS', 'Presentasi', 'Laporan'
  ];

  final List<String> _prioritasList = [
    'Rendah', 'Sedang', 'Tinggi', 'Urgent'
  ];

  @override
  void initState() {
    super.initState();
    _loadMatakuliah();
  }

  Future<void> _loadMatakuliah() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('matakuliah')
          .select('id, nama_matkul, kode_matkul')
          .eq('user_id', user.id)
          .order('nama_matkul');

      setState(() {
        _matakuliahList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matakuliah: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _simpanTugas() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      await _supabase.from('tugas').insert({
        'user_id': user.id,
        'matakuliah_id': _selectedMatakuliahId,
        'nama_tugas': _namaTugasController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'jenis_tugas': _selectedJenisTugas,
        'deadline_date': _selectedDate.toIso8601String().split('T')[0],
        'deadline_time': _formatTime(_selectedTime),
        'prioritas': _selectedPrioritas,
        'catatan': _catatanController.text.trim(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas berhasil ditambahkan!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
      _namaTugasController.clear();
      _deskripsiController.clear();
      _catatanController.clear();
      setState(() {
        _selectedMatakuliahId = null;
        _selectedJenisTugas = 'Individu';
        _selectedPrioritas = 'Sedang';
        _selectedDate = DateTime.now().add(const Duration(days: 1));
        _selectedTime = const TimeOfDay(hour: 23, minute: 59);
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _namaTugasController.dispose();
    _deskripsiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Tugas'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Tugas
              TextFormField(
                controller: _namaTugasController,
                decoration: const InputDecoration(
                  labelText: 'Nama Tugas *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama tugas tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Matakuliah
              DropdownButtonFormField<String>(
                value: _selectedMatakuliahId,
                decoration: const InputDecoration(
                  labelText: 'Matakuliah',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Pilih Matakuliah (Opsional)'),
                  ),
                  ..._matakuliahList.map((mk) {
                    return DropdownMenuItem<String>(
                      value: mk['id'],
                      child: Text('${mk['kode_matkul']} - ${mk['nama_matkul']}'),
                    );
                  }),
                ],
                onChanged: (String? newValue) {
                  setState(() => _selectedMatakuliahId = newValue);
                },
              ),
              const SizedBox(height: 16),

              // Jenis Tugas
              DropdownButtonFormField<String>(
                value: _selectedJenisTugas,
                decoration: const InputDecoration(
                  labelText: 'Jenis Tugas *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: _jenisTugasList.map((jenis) {
                  return DropdownMenuItem<String>(
                    value: jenis,
                    child: Text(jenis),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedJenisTugas = newValue!);
                },
              ),
              const SizedBox(height: 16),

              // Deadline Date & Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Deadline *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_formatDate(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam Deadline *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_formatTime(_selectedTime)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prioritas
              DropdownButtonFormField<String>(
                value: _selectedPrioritas,
                decoration: const InputDecoration(
                  labelText: 'Prioritas *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: _prioritasList.map((prioritas) {
                  return DropdownMenuItem<String>(
                    value: prioritas,
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 12,
                          color: _getPriorityColor(prioritas),
                        ),
                        const SizedBox(width: 8),
                        Text(prioritas),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedPrioritas = newValue!);
                },
              ),
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Tugas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Catatan
              TextFormField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Button Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpanTugas,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Simpan Tugas',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String prioritas) {
    switch (prioritas) {
      case 'Rendah':
        return Colors.green;
      case 'Sedang':
        return Colors.orange;
      case 'Tinggi':
        return Colors.red;
      case 'Urgent':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}