import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade900.withValues(alpha: 0.8),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      // 1. Cek apakah email terdaftar di tabel profiles
      final existingUser = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingUser == null) {
        _showError('Email tidak terdaftar.');
        setState(() => _isLoading = false);
        return;
      }

      // 2. Jika ada, kirim instruksi reset password
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.sikulak://login-callback/',
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = true;
      });
    } on AuthException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Email tidak ditemukan.');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          Container(color: const Color(0xFF2979FF).withValues(alpha: 0.90)),
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      SvgPicture.asset(
                        'assets/images/Logo.svg',
                        width: 100,
                        height: 100,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // White panel
              SliverFillRemaining(
                hasScrollBody: false,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: _isSuccess ? _buildSuccessState() : _buildFormState(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lupa Kata Sandi',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2979FF),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masukkan email anda untuk mengatur ulang kata sandi',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 28),
          _buildLabel('Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email tidak boleh kosong';
              if (!value.contains('@')) return 'Email tidak valid';
              return null;
            },
            decoration: _inputDecoration(hint: 'Masukkan email anda', prefixIcon: Icons.mail_outline_rounded),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Kirim', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Berhasil!',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF2979FF)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Konfirmasi pengaturan kata sandi berhasil dikirim. Silahkan periksa email anda.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text('Kembali', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black38),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF2979FF), size: 20),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF2979FF), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.red, width: 2)),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    );
  }
}
