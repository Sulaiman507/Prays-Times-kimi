import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مواقيت الصلاة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const PrayerTimesScreen(),
    );
  }
}

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // بيانات وهمية ثابتة (دون الحاجة لإنترنت)
    final Map<String, String> prayerTimes = {
      'Fajr': '04:31',
      'Sunrise': '05:54',
      'Dhuhr': '12:27',
      'Asr': '15:46',
      'Maghrib': '19:00',
      'Isha': '20:30',
    };
    final List<String> prayerNamesAr = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final List<String> prayerNames = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final List<String> icons = ['🌙', '☀️', '🌤️', '🌅', '🌇', '🌃'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('مواقيت الصلاة - مكة', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue, Colors.teal],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
          children: [
            // عداد وهمي
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Text('⏳ متبقي على العصر', style: TextStyle(color: Colors.white, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('03:25:12', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            // قائمة الصلوات
            ...List.generate(6, (index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Text(icons[index], style: const TextStyle(fontSize: 22)),
                  ),
                  title: Text(prayerNamesAr[index], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text(prayerNames[index], style: const TextStyle(color: Colors.white70)),
                  trailing: Text(prayerTimes[prayerNames[index]]!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
