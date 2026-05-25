import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'models.dart';
import 'widgets/navbar.dart';
import 'widgets/profile_edit_dialog.dart';
import 'widgets/profile_image_upload.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  final int _selectedNavItem = 4; // Profile tab

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final profile = UserProfile.fromJson(response);
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleProfilePictureClick() async {
    showDialog(
      context: context,
      builder: (context) => ProfileEditDialog(
        onImageSelected: _handleImageSelected,
        onDeletePhoto: _handleDeletePhoto,
      ),
    );
  }

  Future<void> _handleImageSelected(XFile imageFile) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileImageUploadPage(imageFile: imageFile),
      ),
    );

    if (result == true && mounted) {
      await _loadUserProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    }
  }

  Future<void> _handleDeletePhoto() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('profiles').update({
        'avatar_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _loadUserProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await supabase.auth.signOut();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showEditFieldSheet({
    required String title,
    required String initialValue,
    required String fieldName,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required Future<void> Function(String) onSave,
  }) {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ubah $title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2979FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    keyboardType: keyboardType,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    validator: validator ?? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '$title tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: 'Masukkan $title baru',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSaving = true);
                                  try {
                                    final value = controller.text.trim();
                                    await onSave(value);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$title berhasil diperbarui')),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Gagal memperbarui $title: $e')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2979FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _selectedNavItem,
        onItemTapped: (index) {
          if (index == 4) return;
          Navigator.of(context).pop(index);
        },
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                )
              : _profile == null
                  ? const Center(
                      child: Text('Profile not found'),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          // Blue header with profile picture
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF2979FF), Color(0xFF1E5DB8)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 20,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                Text(
                                  'Profile',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 30),
                                // Profile picture
                                GestureDetector(
                                  onTap: _handleProfilePictureClick,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 4,
                                          ),
                                          color: Colors.grey[300],
                                        ),
                                        child: _profile!.avatarUrl != null &&
                                                _profile!.avatarUrl!.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  '${_profile!.avatarUrl}?t=${_profile!.updatedAt.millisecondsSinceEpoch}',
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.person,
                                                      size: 60,
                                                      color: Colors.grey,
                                                    );
                                                  },
                                                ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey[400],
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),

                          // White rounded container with profile info
                          Transform.translate(
                            offset: const Offset(0, -20),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name and email header
                                  Center(
                                    child: Column(
                                      children: [
                                        Text(
                                          _profile!.fullName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: const Color(0xFF2979FF),
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          supabase.auth.currentUser?.email ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Profile section
                                  Text(
                                    'Profile',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF2979FF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Nama Anda
                                  _buildProfileField(
                                    context,
                                    icon: Icons.person,
                                    label: 'Nama anda',
                                    value: _profile!.fullName,
                                    onTap: () => _showEditFieldSheet(
                                      title: 'Nama Anda',
                                      initialValue: _profile!.fullName,
                                      fieldName: 'full_name',
                                      onSave: (val) async {
                                        final userId = supabase.auth.currentUser?.id;
                                        if (userId == null) return;
                                        await supabase.from('profiles').update({
                                          'full_name': val,
                                          'updated_at': DateTime.now().toIso8601String(),
                                        }).eq('id', userId);
                                        await _loadUserProfile();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Nomor Telepon
                                  _buildProfileField(
                                    context,
                                    icon: Icons.phone,
                                    label: 'Nomor telepon',
                                    value: _profile!.phoneNumber ?? '-',
                                    onTap: () => _showEditFieldSheet(
                                      title: 'Nomor Telepon',
                                      initialValue: _profile!.phoneNumber ?? '',
                                      fieldName: 'phone_number',
                                      keyboardType: TextInputType.phone,
                                      onSave: (val) async {
                                        final userId = supabase.auth.currentUser?.id;
                                        if (userId == null) return;
                                        await supabase.from('profiles').update({
                                          'phone_number': val,
                                          'updated_at': DateTime.now().toIso8601String(),
                                        }).eq('id', userId);
                                        await _loadUserProfile();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Alamat Email
                                  _buildProfileField(
                                    context,
                                    icon: Icons.email,
                                    label: 'Alamat email',
                                    value:
                                        supabase.auth.currentUser?.email ?? '',
                                    onTap: () => _showEditFieldSheet(
                                      title: 'Alamat Email',
                                      initialValue: supabase.auth.currentUser?.email ?? '',
                                      fieldName: 'email',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Alamat email tidak boleh kosong';
                                        }
                                        if (!val.contains('@')) {
                                          return 'Alamat email tidak valid';
                                        }
                                        return null;
                                      },
                                      onSave: (val) async {
                                        await supabase.auth.updateUser(UserAttributes(email: val));
                                        await _loadUserProfile();
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Settings section
                                  Text(
                                    'Settings',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: const Color(0xFF2979FF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Kata Sandi
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushNamed('/change-password');
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.lock,
                                              color: Color(0xFF2979FF),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Expanded(
                                            child: Text(
                                              'Kata Sandi',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Logout
                                  GestureDetector(
                                    onTap: _handleLogout,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.red[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.logout,
                                              color: Colors.red[600],
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          const Expanded(
                                            child: Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileField(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.grey[600],
                size: 20,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
          ),
        ],
      ),
    ),
  );
}
}
