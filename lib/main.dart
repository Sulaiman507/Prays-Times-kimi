import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, String> _prayerTimes = {};
  String _hijriDate = '';
  String _gregorianDate = '';

  // خريطة المدن مع أسمائها بالإيجاز وإحداثياتها الجغرافية لضمان عدم حدوث أي خطأ في API
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
    await fetchPrayerTimes();
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

  Future<void> fetchPrayerTimes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cityInfo = _citiesData[_selectedCityKey] ?? _citiesData['Jeddah']!;
      final double lat = cityInfo['lat'];
      final double lng = cityInfo['lng'];

      // استخدام API الإحداثيات المباشر المستقر جداً عبر طريقة أم القرى (method=4)
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lng&method=4',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'];
        final dateData = data['data']['date'];

        setState(() {
          _prayerTimes = {
            'الفجر': timings['Fajr'],
            'الشروق': timings['Sunrise'],
            'الظهر': timings['Dhuhr'],
            'العصر': timings['Asr'],
            'المغرب': timings['Maghrib'],
            'العشاء': timings['Isha'],
          };

          final hijri = dateData['hijri'];
          _hijriDate =
              '${hijri['day']} ${hijri['month']['ar']} ${hijri['year']} هـ';

          final gregorian = dateData['gregorian'];
          _gregorianDate =
              '${gregorian['day']} ${gregorian['month']['en']} ${gregorian['year']} م';

          _isLoading = false;
        });

        await _scheduleNotifications(timings);
      } else {
        setState(() {
          _errorMessage = 'تعذر جلب المواقيت (رمز: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'تأكد من اتصالك بالإنترنت والتحقق من الإعدادات';
        _isLoading = false;
      });
    }
  }

  Future<void> _scheduleNotifications(Map<String, dynamic> timings) async {
    await NotificationService.cancelAll();

    final now = DateTime.now();
    final prayers = {
      1: {'name': 'الفجر', 'time': timings['Fajr']},
      2: {'name': 'الظهر', 'time': timings['Dhuhr']},
      3: {'name': 'العصر', 'time': timings['Asr']},
      4: {'name': 'المغرب', 'time': timings['Maghrib']},
      5: {'name': 'العشاء', 'time': timings['Isha']},
    };

    final cityName = _citiesData[_selectedCityKey]?['name'] ?? 'مدينتك';

    prayers.forEach((id, info) async {
      final timeParts = (info['time'] as String).split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await NotificationService.scheduleNotification(
        id: id,
        title: 'حان الآن موعد صلاة ${info['name']}',
        body: 'الله أكبر، حان وقت أذان صلاة ${info['name']} في $cityName',
        scheduledTime: scheduledDate,
      );

      if (info['name'] == 'الظهر') {
        await NotificationService.scheduleFridayReminder(scheduledDate);
      }
    });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchPrayerTimes,
            tooltip: 'تحديث',
          ),
        ],
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
                            fetchPrayerTimes();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // بطاقة التاريخ الهجري والميلادي
              if (_hijriDate.isNotEmpty)
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
                      Text(
                        _hijriDate,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gregorianDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // قائمة مواقيت الصلاة
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.redAccent),
                                const SizedBox(height: 8),
                                Text(_errorMessage!,
                                    style:
                                        const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: fetchPrayerTimes,
                                  child: const Text('إعادة المحاولة'),
                                )
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _prayerTimes.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final name = _prayerTimes.keys.elementAt(index);
                              final time =
                                  _prayerTimes.values.elementAt(index);
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
                                        : const Color(0xFF10B981)
                                            .withOpacity(0.2),
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
