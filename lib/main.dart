tter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  const PrayerTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serene Devotion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      ),
      home: const PrayerTimesScreen(),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State

 createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State

 {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildMainTimer(),
                    const SizedBox(height: 40),
                    _buildPrayerCard(
                      name: 'الظهر',
                      athan: '12:08',
                      iqamah: '12:28',
                      isActive: true,
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildPrayerCard(
                      name: 'الفجر',
                      athan: '05:45',
                      iqamah: '06:05',
                      isActive: false,
                      icon: Icons.wb_twilight_rounded,
                    ),
                    _buildPrayerCard(
                      name: 'العصر',
                      athan: '14:00',
                      iqamah: '14:15',
                      isActive: false,
                      icon: Icons.wb_sunny,
                    ),
                    _buildPrayerCard(
                      name: 'المغرب',
                      athan: '16:35',
                      iqamah: '16:45',
                      isActive: false,
                      icon: Icons.nightlight_round,
                    ),
                    _buildPrayerCard(
                      name: 'العشاء',
                      athan: '18:10',
                      iqamah: '18:30',
                      isActive: false,
                      icon: Icons.bedtime_rounded,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.calendar_today_outlined, color: Colors.amber, size: 24),
              Row(
                children: [
                  Text(
                    'London, UK',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.location_on, color: Colors.amber, size: 24),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'January 2024 26',
                style: GoogleFonts.manrope(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              Text(
                '14 رجب 1445',
                style: GoogleFonts.manrope(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainTimer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 260,
          height: 260,
          child: CircularProgressIndicator(
            value: 0.7,
            strokeWidth: 4,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation

(Colors.amber.withOpacity(0.8)),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'متبقي على صلاة الظهر',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '01:24:10',
              style: GoogleFonts.manrope(
                fontSize: 54,
                fontWeight: FontWeight.w200,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerCard({
    required String name,
    required String athan,
    required String iqamah,
    required bool isActive,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.amber.withOpacity(0.3) : Colors.white10,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأذان', style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text(athan, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الإقامة', style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text(iqamah, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.amber : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, color: isActive ? Colors.amber : Colors.white38),
                ],
              ),
              if (isActive)
                const Text(
                  'الصلاة الحالية',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF191C1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_filled, 'Home'),
          _navItem(1, Icons.explore_outlined, 'Qibla'),
          _navItem(2, Icons.menu_book_outlined, 'Azkar'),
          _navItem(3, Icons.settings_outlined, 'Settings'),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.amber : Colors.white38),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
