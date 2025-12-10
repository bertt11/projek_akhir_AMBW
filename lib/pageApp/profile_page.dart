import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  final _namaController = TextEditingController();
  final _nimController = TextEditingController();
  final _jurusanController = TextEditingController();
  final _semesterController = TextEditingController();
  final _teleponController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploading = false;
  String? _profileImageUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        _namaController.text = response['nama'] ?? '';
        _nimController.text = response['nim'] ?? '';
        _jurusanController.text = response['jurusan'] ?? '';
        _semesterController.text = response['semester'] ?? '';
        _teleponController.text = response['telepon'] ?? '';
        _profileImageUrl = response['profile_image_url'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = pickedFile.name;
        });
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageBytes == null) return;

    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not found';

      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _supabase.storage
          .from('profiles')
          .uploadBinary(fileName, _selectedImageBytes!);

      final imageUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl(fileName);

      setState(() {
        _profileImageUrl = imageUrl;
      });

      // Update profile dengan URL gambar baru tanpa menampilkan alert
      await _updateProfileImageOnly();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _updateProfileImageOnly() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not found';

      // Cek apakah profile sudah ada
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingProfile != null) {
        // Update hanya URL gambar
        await _supabase
            .from('profiles')
            .update({'profile_image_url': _profileImageUrl})
            .eq('user_id', user.id);
      } else {
        // Insert profile baru dengan data minimal
        await _supabase
            .from('profiles')
            .insert({
              'user_id': user.id,
              'profile_image_url': _profileImageUrl,
            });
      }
    } catch (e) {
      // Silent error untuk update gambar saja
      debugPrint('Error updating profile image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not found';

      // Cek apakah profile sudah ada
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      final profileData = {
        'user_id': user.id,
        'nama': _namaController.text.trim(),
        'nim': _nimController.text.trim(),
        'jurusan': _jurusanController.text.trim(),
        'semester': _semesterController.text.trim(),
        'telepon': _teleponController.text.trim(),
        'profile_image_url': _profileImageUrl,
      };

      if (existingProfile != null) {
        // Update existing profile
        await _supabase
            .from('profiles')
            .update(profileData)
            .eq('user_id', user.id);
      } else {
        // Insert new profile
        await _supabase
            .from('profiles')
            .insert(profileData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nimController.dispose();
    _jurusanController.dispose();
    _semesterController.dispose();
    _teleponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Picture Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: _selectedImageBytes != null
                                ? MemoryImage(_selectedImageBytes!)
                                : _profileImageUrl != null
                                    ? NetworkImage(_profileImageUrl!)
                                    : null,
                            child: _selectedImageBytes == null && _profileImageUrl == null
                                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: 20,
                                icon: _isUploading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                onPressed: _isUploading ? null : _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email (Read-only)
                    TextFormField(
                      initialValue: user?.email ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Nama Lengkap
                    TextFormField(
                      controller: _namaController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Nama tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // NIM
                    TextFormField(
                      controller: _nimController,
                      decoration: const InputDecoration(
                        labelText: 'NIM *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'NIM tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Jurusan
                    TextFormField(
                      controller: _jurusanController,
                      decoration: const InputDecoration(
                        labelText: 'Jurusan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Semester
                    TextFormField(
                      controller: _semesterController,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timeline),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Telepon
                    TextFormField(
                      controller: _teleponController,
                      decoration: const InputDecoration(
                        labelText: 'No. Telepon',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading ? null : _saveProfile,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Simpan Profile',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
  }
}