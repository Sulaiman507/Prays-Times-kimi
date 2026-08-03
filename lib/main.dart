import 'package:flutter/material.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة خدمة الإشعارات
  await NotificationService.init();

  // 2. طلب الصلاحيات
  await NotificationService.requestPermissions();

  runApp(const PrayerTimesApp());
}

class PrayerTimesApp extends StatelessWidget {
  const PrayerTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مواقيت الصلاة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B121E),
        fontFamily: 'Tajawal', // أو الخط الافتراضي للنظام
      ),
      home: const PrayerTimesScreen(),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleNotifications();
  }

  void _scheduleNotifications() async {
    await NotificationService.cancelAll();
    
    // جدولة إشعار تجريبي يظهر بعد 5 ثوانٍ لتأكيد عمل الإشعارات
    final now = DateTime.now();
    await NotificationService.scheduleNotification(
      id: 99,
      title: 'تنبيه الأذان 🕌',
      body: 'حان الآن موعد صلاة العصر حسب التوقيت المحلي',
      scheduledTime: now.add(const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    _buildPrayerGrid(),
                    const SizedBox(height: 20),
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

  // الهيدر العلوي: مواقيت الصلاة والأحد، 2 أغسطس
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'الأحد، 2 أغسطس',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, size: 28, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // الكارت الأزرق الكبير العلوي
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00B2FE), Color(0xFF008BE7)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF008BE7).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'جدة',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.favorite_border, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'المملكة العربية السعودية',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white80,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'الصلاة القادمة: العصر: 03:49 م',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // شبكة الصلوات (2 في كل صف)
  Widget _buildPrayerGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.05,
      children: [
        _buildPrayerGridCard(
          name: 'الفجر',
          athan: '04:34 ص',
          iqamah: '04:59 ص',
          icon: Icons.wb_twilight_rounded,
          isNext: false,
        ),
        _buildPrayerGridCard(
          name: 'الشروق',
          athan: '05:57 ص',
          iqamah: null,
          icon: Icons.wb_sunny_outlined,
          isNext: false,
        ),
        _buildPrayerGridCard(
          name: 'الظهر',
          athan: '12:30 م',
          iqamah: '12:50 م',
          icon: Icons.wb_sunny,
          isNext: false,
        ),
        _buildPrayerGridCard(
          name: 'العصر',
          athan: '03:49 م',
          iqamah: '04:09 م',
          icon: Icons.cloud_outlined,
          isNext: true, // الصلاة القادمة (إطار أصفر وبادج)
        ),
      ],
    );
  }

  Widget _buildPrayerGridCard({
    required String name,
    required String athan,
    String? iqamah,
    required IconData icon,
    required bool isNext,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNext ? const Color(0xFFD97706) : Colors.transparent,
          width: isNext ? 1.5 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (isNext)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'الصلاة القادمة',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(),
              Icon(icon, color: Colors.lightBlueAccent, size: 24),
            ],
          ),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الأذان', style: TextStyle(color: Colors.white38, fontSize: 12)),
              Text(athan, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          if (iqamah != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإقامة', style: TextStyle(color: Colors.white38, fontSize: 12)),
                Text(iqamah, style: const TextStyle(color: Color(0xFF00B2FE), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  // الشريط السفلي الأصلي
  Widget _buildBottomNavBar() {
    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: Color(0xFF0B121E),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home, 'مواقيت الصلاة'),
          _navItem(1, Icons.favorite_border, 'المفضلة'),
          _navItem(2, Icons.settings_outlined, 'الإعدادات'),
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
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00B2FE) : Colors.white38,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
