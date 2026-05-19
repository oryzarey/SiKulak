import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background image full opacity 
          Image.asset(
            'assets/images/background.png',
            fit: BoxFit.cover,
          ),

          // ── 2. Blue overlay di atas image
          Container(
            color: const Color(0xFF2979FF).withOpacity(0.90),
          ),

          // 3. Semua konten
          Column(
            children: [
              // Bagian atas: teks + logo 
              Expanded(
                flex: 6,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Selamat Datang',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Image.asset(
                        'assets/icons/logo.png',
                        width: 130,
                        height: 130,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'SiKulak',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sistem Informasi Kulak',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              //Bagian bawah: panel putih
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Tombol Masuk (filled)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Navigate to login page
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A237E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Masuk',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Tombol Daftar (outlined)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              // TODO: Navigate to register page
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A237E),
                              side: const BorderSide(
                                color: Color(0xFF1A237E),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
