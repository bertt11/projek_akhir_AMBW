import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TambahMatakuliahPage extends StatefulWidget {
  const TambahMatakuliahPage({super.key});

  @override
  State<TambahMatakuliahPage> createState() => _TambahMatakuliahPageState();
}

class _TambahMatakuliahPageState extends State<TambahMatakuliahPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaMatkulController = TextEditingController();
  final _kodeMatkulController = TextEditingController();
  final _dosenController = TextEditingController();
  final _ruanganController = TextEditingController();
  
  String _selectedHari = 'Senin';
  TimeOfDay _jamMulai = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _jamSelesai = const TimeOfDay(hour: 10, minute: 0);
  int _sks = 3;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  final List<String> _hariList = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'
  ];

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _jamMulai : _jamSelesai,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _jamMulai = picked;
        } else {
          _jamSelesai = picked;
        }
      });
    }
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _simpanMatakuliah() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      await _supabase.from('matakuliah').insert({
        'user_id': user.id,
        'nama_matkul': _namaMatkulController.text.trim(),
        'kode_matkul': _kodeMatkulController.text.trim(),
        'sks': _sks,
        'dosen': _dosenController.text.trim(),
        'hari': _selectedHari,
        'jam_mulai': _timeToString(_jamMulai),
        'jam_selesai': _timeToString(_jamSelesai),
        'ruangan': _ruanganController.text.trim(),
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Matakuliah berhasil ditambahkan!'),
          backgroundColor: Colors.green,
        ),
      );

      // Reset form
      _formKey.currentState!.reset();
      _namaMatkulController.clear();
      _kodeMatkulController.clear();
      _dosenController.clear();
      _ruanganController.clear();
      setState(() {
        _selectedHari = 'Senin';
        _jamMulai = const TimeOfDay(hour: 8, minute: 0);
        _jamSelesai = const TimeOfDay(hour: 10, minute: 0);
        _sks = 3;
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
    _namaMatkulController.dispose();
    _kodeMatkulController.dispose();
    _dosenController.dispose();
    _ruanganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Matakuliah
              TextFormField(
                controller: _namaMatkulController,
                decoration: const InputDecoration(
                  labelText: 'Nama Matakuliah *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama matakuliah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kode Matakuliah
              TextFormField(
                controller: _kodeMatkulController,
                decoration: const InputDecoration(
                  labelText: 'Kode Matakuliah *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Kode matakuliah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKS
              DropdownButtonFormField<int>(
                value: _sks,
                decoration: const InputDecoration(
                  labelText: 'SKS',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4, 6].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value SKS'),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() => _sks = newValue!);
                },
              ),
              const SizedBox(height: 16),

              // Dosen
              TextFormField(
                controller: _dosenController,
                decoration: const InputDecoration(
                  labelText: 'Nama Dosen',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Hari
              DropdownButtonFormField<String>(
                value: _selectedHari,
                decoration: const InputDecoration(
                  labelText: 'Hari *',
                  border: OutlineInputBorder(),
                ),
                items: _hariList.map((String hari) {
                  return DropdownMenuItem<String>(
                    value: hari,
                    child: Text(hari),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() => _selectedHari = newValue!);
                },
              ),
              const SizedBox(height: 16),

              // Jam Mulai dan Selesai
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam Mulai *',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_timeToString(_jamMulai)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Jam Selesai *',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_timeToString(_jamSelesai)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ruangan
              TextFormField(
                controller: _ruanganController,
                decoration: const InputDecoration(
                  labelText: 'Ruangan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Button Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _simpanMatakuliah,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan Matakuliah'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}