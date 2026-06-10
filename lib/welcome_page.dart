import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'register_page.dart';
import 'login_page.dart';

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

          // ── 2. Blue overlay dengan gradient ke putih
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2979FF).withValues(alpha: 0.90),
                  const Color(0xFF2979FF).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // 3. Semua konten
          CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // Bagian atas: teks + logo
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      SvgPicture.asset(
                        'assets/images/Logo.svg',
                        width: 130,
                        height: 130,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ],
                  ),
                ),
              ),

              //Bagian bawah: panel putih dengan gradient
              SliverFillRemaining(
                hasScrollBody: false,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tagline
                        Padding(
                          padding: const EdgeInsets.only(bottom: 40),
                          child: const Text(
                            'Kulakan Lebih Cerdas,\nUntung Lebih Besar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color.fromARGB(255, 0, 0, 0),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),

                        // Tombol Masuk (filled)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
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
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
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
                        const SizedBox(height: 50),
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
