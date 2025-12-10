import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_page.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _matakuliah = [];
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  final List<String> _hariList = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadMatakuliah(), _loadUserProfile()]);
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _userProfile = response;
      });
    } catch (e) {
      // Ignore error, profile might not exist yet
    }
  }

  Future<void> _loadMatakuliah() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('matakuliah')
          .select()
          .eq('user_id', user.id)
          .order('hari');

      setState(() {
        _matakuliah = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }



  List<Map<String, dynamic>> _getMatakuliahByHari(String hari) {
    final matkulHari = _matakuliah.where((mk) => mk['hari'] == hari).toList();
    matkulHari.sort((a, b) => a['jam_mulai'].compareTo(b['jam_mulai']));
    return matkulHari;
  }





  String _buildSubtitleText(int matkulCount) {
    if (matkulCount == 0) {
      return 'Tidak ada jadwal';
    }
    return '$matkulCount kuliah';
  }

  String _formatTime(String time) {
    return time.substring(0, 5);
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return const Center(child: Text('User tidak ditemukan'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _userProfile?['profile_image_url'] != null
                          ? NetworkImage(_userProfile!['profile_image_url'])
                          : null,
                      child: _userProfile?['profile_image_url'] == null
                          ? const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userProfile?['nama'] != null &&
                                    _userProfile!['nama'].isNotEmpty
                                ? 'Selamat datang, ${_userProfile!['nama']}!'
                                : 'Selamat datang!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Jadwal Section
            const Text(
              'Jadwal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_matakuliah.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada jadwal kuliah',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan matakuliah di tab Matakuliah',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _hariList.map((hari) {
                  final matkulHari = _getMatakuliahByHari(hari);
                  final isToday = _isToday(hari);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: isToday ? Colors.blue[50] : null,
                    child: ExpansionTile(
                      title: Text(
                        hari,
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday ? Colors.blue[700] : null,
                        ),
                      ),
                      subtitle: Text(
                        _buildSubtitleText(matkulHari.length),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      children: _buildDayChildren(matkulHari),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDayChildren(
    List<Map<String, dynamic>> matkulHari,
  ) {
    List<Widget> children = [];

    // Add mata kuliah
    for (var mk in matkulHari) {
      children.add(
        ListTile(
          leading: Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          title: Text(
            mk['nama_matkul'],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${mk['kode_matkul']} • ${mk['sks']} SKS',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatTime(mk['jam_mulai'])} - ${_formatTime(mk['jam_selesai'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (mk['ruangan'] != null &&
                      mk['ruangan'].toString().isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.room, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      mk['ruangan'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
              if (mk['dosen'] != null && mk['dosen'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mk['dosen'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      );
    }

    if (children.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Tidak ada jadwal kuliah',
            style: TextStyle(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return children;
  }



  bool _isToday(String hari) {
    final today = DateTime.now().weekday;
    final hariMap = {
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
    };
    return hariMap[hari] == today;
  }
}
