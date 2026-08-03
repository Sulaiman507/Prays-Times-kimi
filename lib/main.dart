import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF10B981),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
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
  String _selectedCityKey = 'Jeddah';
  Map<String, String> _prayerTimes = {};
  String _gregorianDate = '';

  // خريطة المدن مع الإحداثيات الجغرافية
  final Map<String, Map<String, dynamic>> _citiesData = {
    'Jeddah': {'name': 'جدة', 'lat': 21.5433, 'lng': 39.1728},
    'Makkah': {'name': 'مكة المكرمة', 'lat': 21.3891, 'lng': 39.8579},
    'Madinah': {'name': 'المدينة المنورة', 'lat': 24.5247, 'lng': 39.5692},
    'Riyadh': {'name': 'الرياض', 'lat': 24.7136, 'lng': 46.6753},
    'Dammam': {'name': 'الدمام', 'lat': 26.4207, 'lng': 50.0888},
  };

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await NotificationService.requestPermissions();
    await _loadSavedCity();
    _calculatePrayerTimes();
  }

  Future<void> _loadSavedCity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCityKey = prefs.getString('saved_city') ?? 'Jeddah';
    });
  }

  Future<void> _saveCity(String cityKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_city', cityKey);
  }

  // حساب المواقيت فورياً وأوفلاين بدون طلبات HTTP
  void _calculatePrayerTimes() {
    final cityInfo = _citiesData[_selectedCityKey] ?? _citiesData['Jeddah']!;
    final coordinates = Coordinates(cityInfo['lat'], cityInfo['lng']);

    // تطبيق معيار أم القرى الرسمي في المملكة العربية السعودية
    final params = CalculationMethod.umm_al_qura.getParameters();

    final now = DateTime.now();
    final dateComponents = DateComponents(now.year, now.month, now.day);

    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    final timeFormatter = DateFormat.jm('ar');

    setState(() {
      _prayerTimes = {
        'الفجر': timeFormatter.format(prayerTimes.fajr),
        'الشروق': timeFormatter.format(prayerTimes.sunrise),
        'الظهر': timeFormatter.format(prayerTimes.dhuhr),
        'العصر': timeFormatter.format(prayerTimes.asr),
        'المغرب': timeFormatter.format(prayerTimes.maghrib),
        'العشاء': timeFormatter.format(prayerTimes.isha),
      };

      _gregorianDate = DateFormat('EEEE، d MMMM yyyy', 'ar').format(now);
    });

    _scheduleNotificationsOffline(prayerTimes);
  }

  Future<void> _scheduleNotificationsOffline(PrayerTimes prayerTimes) async {
    await NotificationService.cancelAll();

    final cityName = _citiesData[_selectedCityKey]?['name'] ?? 'مدينتك';
    final now = DateTime.now();

    final List<Map<String, dynamic>> prayers = [
      {'id': 1, 'name': 'الفجر', 'time': prayerTimes.fajr},
      {'id': 2, 'name': 'الظهر', 'time': prayerTimes.dhuhr},
      {'id': 3, 'name': 'العصر', 'time': prayerTimes.asr},
      {'id': 4, 'name': 'المغرب', 'time': prayerTimes.maghrib},
      {'id': 5, 'name': 'العشاء', 'time': prayerTimes.isha},
    ];

    for (var prayer in prayers) {
      DateTime scheduledDate = prayer['time'];

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await NotificationService.scheduleNotification(
        id: prayer['id'],
        title: 'حان الآن موعد صلاة ${prayer['name']}',
        body: 'الله أكبر، حان وقت أذان صلاة ${prayer['name']} في $cityName',
        scheduledTime: scheduledDate,
      );

      if (prayer['name'] == 'الظهر') {
        await NotificationService.scheduleFridayReminder(scheduledDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // اختيار المدينة
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('المدينة:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCityKey,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        items: _citiesData.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value['name'],
                                style: const TextStyle(fontSize: 16)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null && newValue != _selectedCityKey) {
                            setState(() {
                              _selectedCityKey = newValue;
                            });
                            _saveCity(newValue);
                            _calculatePrayerTimes();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // بطاقة التاريخ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'مواقيت اليوم',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _gregorianDate,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // قائمة مواقيت الصلاة
              Expanded(
                child: ListView.separated(
                  itemCount: _prayerTimes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final name = _prayerTimes.keys.elementAt(index);
                    final time = _prayerTimes.values.elementAt(index);
                    final isSunrise = name == 'الشروق';

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSunrise
                              ? Colors.orange.withOpacity(0.2)
                              : const Color(0xFF10B981).withOpacity(0.2),
                          child: Icon(
                            isSunrise
                                ? Icons.wb_sunny
                                : Icons.access_time_filled,
                            color: isSunrise
                                ? Colors.orange
                                : const Color(0xFF10B981),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        trailing: Text(
                          time,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isSunrise
                                ? Colors.orange
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
