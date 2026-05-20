import 'package:flutter/material.dart';
import 'main.dart';
import 'welcome_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoadingTodos = true;
  String _todosStatus = '';
  List<dynamic>? _todos;
  String? _todosError;

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    setState(() {
      _isLoadingTodos = true;
      _todosError = null;
    });

    try {
      final data = await supabase.from('todos').select();
      if (!mounted) return;
      setState(() {
        _todos = data;
        _todosStatus = '✅ Tabel "todos" ditemukan — ${data.length} item';
        _isLoadingTodos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _todosError = e.toString();
        _todosStatus = '⚠️ Tidak bisa membaca tabel "todos"';
        _isLoadingTodos = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final session = supabase.auth.currentSession;
    final metadata = user?.userMetadata;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: const Color(0xFF2979FF).withValues(alpha: 0.90),
          ),

          Column(
            children: [
              // ── Header ───────────────────────────────────────────────
              Expanded(
                flex: 3,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.bug_report_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Debug Dashboard',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session != null
                              ? '🟢 Koneksi Supabase Berhasil'
                              : '🔴 Tidak ada sesi aktif',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── White Panel ──────────────────────────────────────────
              Expanded(
                flex: 9,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── User Info Section ────────────────────────
                          const Text(
                            'Informasi Pengguna',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2979FF),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildInfoCard(
                            icon: Icons.person_outline_rounded,
                            label: 'Nama',
                            value: metadata?['nama'] ??
                                metadata?['name'] ??
                                'Tidak diset',
                          ),
                          const SizedBox(height: 10),
                          _buildInfoCard(
                            icon: Icons.mail_outline_rounded,
                            label: 'Email',
                            value: user?.email ?? 'Tidak tersedia',
                          ),
                          const SizedBox(height: 10),
                          _buildInfoCard(
                            icon: Icons.fingerprint_rounded,
                            label: 'User ID',
                            value: user?.id ?? 'Tidak tersedia',
                            isSmall: true,
                          ),
                          const SizedBox(height: 10),
                          _buildInfoCard(
                            icon: Icons.calendar_today_rounded,
                            label: 'Dibuat pada',
                            value: user?.createdAt ?? 'Tidak tersedia',
                            isSmall: true,
                          ),

                          const SizedBox(height: 28),

                          // ── DB Connection Test ───────────────────────
                          const Text(
                            'Tes Koneksi Database',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2979FF),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Status card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isLoadingTodos
                                  ? Colors.grey.shade50
                                  : _todosError != null
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isLoadingTodos
                                    ? Colors.grey.shade200
                                    : _todosError != null
                                        ? Colors.orange.shade200
                                        : Colors.green.shade200,
                              ),
                            ),
                            child: _isLoadingTodos
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF2979FF),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Memuat data dari "todos"...',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _todosStatus,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _todosError != null
                                              ? Colors.orange.shade800
                                              : Colors.green.shade800,
                                        ),
                                      ),
                                      if (_todosError != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _todosError!,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: Colors.orange.shade700,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                          ),

                          // Show todo items if available
                          if (_todos != null && _todos!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Data Todos:',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              _todos!.length,
                              (index) {
                                final todo = _todos![index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.green.shade400,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          todo['name']?.toString() ??
                                              todo.toString(),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Refresh button
                          Center(
                            child: TextButton.icon(
                              onPressed: _fetchTodos,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: Color(0xFF2979FF),
                              ),
                              label: const Text(
                                'Refresh',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2979FF),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Logout Button ────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              label: const Text(
                                'Keluar',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade500,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helper: info card ──────────────────────────────────────────────────────
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    bool isSmall = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2979FF), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: isSmall ? 11 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
