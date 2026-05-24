import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileImageUploadPage extends StatefulWidget {
  final XFile imageFile;

  const ProfileImageUploadPage({
    super.key,
    required this.imageFile,
  });

  @override
  State<ProfileImageUploadPage> createState() => _ProfileImageUploadPageState();
}

class _ProfileImageUploadPageState extends State<ProfileImageUploadPage> {
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      // Read image as bytes (works on all platforms)
      final bytes = await widget.imageFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading image: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null) return;

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client; // Get supabase instance
      final userId = supabase.auth.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'avatar_$userId.jpg';
      final filePath = 'avatars/$userId/$fileName';

      // For web and mobile, upload bytes
      await supabase.storage.from('profiles').uploadBinary(
            filePath,
            _imageBytes!,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = supabase.storage.from('profiles').getPublicUrl(filePath);

      await supabase.from('profiles').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2979FF),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60, bottom: 40),
            child: Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : const Center(child: Text('No image selected')),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x80FFFFFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF2979FF)),
                        ),
                      )
                    : const Text(
                        'Upload Foto',
                        style: TextStyle(
                          color: Color(0xFF2979FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isUploading ? null : () => Navigator.pop(context),
            child: const Text(
              'BATALKAN',
              style: TextStyle(
                color: Color(0xFF5DADE2),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}