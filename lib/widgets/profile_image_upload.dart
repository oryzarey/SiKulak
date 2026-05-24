import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

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
  File? _croppedImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _cropImage();
  }

  Future<void> _cropImage() async {
    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: widget.imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF2979FF),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          minimumAspectRatio: 1.0,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _croppedImage = File(croppedFile.path);
      });
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_croppedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'avatar_$userId.jpg';
      final filePath = 'avatars/$userId/$fileName';

      await supabase.storage.from('profiles').upload(
            filePath,
            _croppedImage!,
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
          // Header
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

          // Image preview with crop grid
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  if (_croppedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _croppedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  else if (widget.imageFile.path.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        File(widget.imageFile.path),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  else
                    Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF2979FF).withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  // Grid overlay
                  CustomPaint(
                    painter: GridPainter(),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Upload button
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

          // Cancel link
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

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    // Draw vertical lines
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
