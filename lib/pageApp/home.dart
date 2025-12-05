import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _supabase = Supabase.instance.client;

  final List<Widget> _pages = const [
    HomeContent(),
    TambahTugasPage(),
    TambahMatakuliahPage(),
  ];

  final List<String> _titles = const [
    'Home',
    'Tambah Tugas',
    'Tambah Matakuliah',
  ];

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (!mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                '/auth',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_add),
            label: 'Tambah Tugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Tambah Matkul',
          ),
        ],
      ),
    );
  }
}

/// =========== ISI HOME ===========
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Center(
      child: Text(
        user == null
            ? 'User tidak ditemukan'
            : 'Selamat datang, ${user.email}',
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// =========== TAMBAH TUGAS ===========
class TambahTugasPage extends StatelessWidget {
  const TambahTugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nama Tugas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Deskripsi',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: null,
            child: const Text('Simpan Tugas'),
          ),
        ],
      ),
    );
  }
}

/// =========== TAMBAH MATAKULIAH ===========
class TambahMatakuliahPage extends StatelessWidget {
  const TambahMatakuliahPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: 'Nama Matakuliah',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Kode Matakuliah',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: null,
            child: const Text('Simpan Matakuliah'),
          ),
        ],
      ),
    );
  }
}
