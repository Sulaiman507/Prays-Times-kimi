import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================
// App Colors (Green Emerald Theme)
// ============================
class AppColors {
  AppColors._();

  static const Color primaryGreen = Color(0xFF2D7A5D);
  static const Color darkGreen = Color(0xFF1B4D3E);
  static const Color lightGreen = Color(0xFFE8F3EE);
  static const Color background = Color(0xFFF6F8F7);
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF1C274C);
  static const Color textMuted = Color(0xFF8C98A8);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ============================
// Localization & Helpers
// ============================
class Lang {
  static const Map<String, Map<String, String>> texts = {
    'en': {
      'appName': 'Prayer Times',
      'fajr': 'Fajr',
      'sunrise': 'Sunrise',
      'dhuhr': 'Dhuhr',
      'asr': 'Asr',
      'maghrib': 'Maghrib',
      'isha': 'Isha',
      'searchCity': 'Search city...',
      'nextPrayer': ' الصلاة القادمة',
      'todaySchedule': 'جدول اليوم',
      'noCitiesFound': 'No cities found',
    },
    'ar': {
      'appName': 'مواقيت الصلاة',
      'fajr': 'الفجر',
      'sunrise': 'الشروق',
      'dhuhr': 'الظهر',
      'asr': 'العصر',
      'maghrib': 'المغرب',
      'isha': 'العشاء',
      'searchCity': 'ابحث عن مدينة...',
      'nextPrayer': ' الصلاة القادمة',
      'todaySchedule': 'جدول اليوم',
      'noCitiesFound': 'لم يتم العثور على مدن',
    },
  };

  static String t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return texts[locale]?[key] ?? texts['ar']![key] ?? key;
  }
}

// ============================
// Models
// ============================
class City {
  final String name;
  final String country;
  final double lat;
  final double lng;

  const City({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {'name': name, 'country': country, 'lat': lat, 'lng': lng};

  factory City.fromJson(Map<String, dynamic> json) => City(
        name: (json['name'] ?? '').toString(),
        country: (json['country'] ?? '').toString(),
        lat: _parseDouble(json['lat']) ?? 0.0,
        lng: _parseDouble(json['lng']) ?? 0.0,
      );

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTimes.fromApi(Map<String, dynamic> data) {
    final timings = data['timings'] as Map<String, dynamic>? ?? {};
    return PrayerTimes(
      fajr: _clean(timings['Fajr']),
      sunrise: _clean(timings['Sunrise']),
      dhuhr: _clean(timings['Dhuhr']),
      asr: _clean(timings['Asr']),
      maghrib: _clean(timings['Maghrib']),
      isha: _clean(timings['Isha']),
    );
  }

  static String _clean(dynamic v) {
    if (v == null) return '00:00';
    final str = v.toString().trim();
    final match = RegExp(r'^(\d{1,2}:\d{2})').firstMatch(str);
    return match?.group(1) ?? str;
  }
}

// Helper formatting 24h string "15:50" -> 12h format {time: "3:50", period: "م"}
class TimeFormatter {
  static Map<String, String> to12Hour(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'م' : 'ص';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return {'time': '$hour:$minute', 'period': period};
    } catch (_) {
      return {'time': time24, 'period': ''};
    }
  }

  // Calculate Iqama time (+20 mins standard offset for demonstration)
  static String getIqamaTime(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]) + 20; // 20 mins offset
      if (minute >= 60) {
        minute -= 60;
        hour += 1;
      }
      final period = hour >= 12 ? 'م' : 'ص';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      final minuteStr = minute.toString().padLeft(2, '0');
      return '$hour:$minuteStr $period';
    } catch (_) {
      return '';
    }
  }
}

// ============================
// Storage & API Services
// ============================
class StorageService {
  static const String _cityKey = 'last_city';

  static Future<void> saveLastCity(City city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, jsonEncode(city.toJson()));
  }

  static Future<City?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_cityKey);
    if (str == null) return null;
    try {
      return City.fromJson(jsonDecode(str));
    } catch (_) {
      return null;
    }
  }
}

class PrayerApiService {
  static final http.Client _client = http.Client();

  static Future<PrayerTimes?> fetchPrayerTimes(City city) async {
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final url = 'https://api.aladhan.com/v1/timings/$date?latitude=${city.lat}&longitude=${city.lng}&method=4';

    try {
      final response = await _client.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PrayerTimes.fromApi(data['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<City>> searchCity(String query) async {
    if (query.trim().length < 2) return [];
    final encoded = Uri.encodeQueryComponent(query.trim());
    final url = 'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&addressdetails=1&accept-language=ar,en&limit=8';

    try {
      final response = await _client.get(Uri.parse(url), headers: {'User-Agent': 'PrayerApp/1.0'});
      if (response.statusCode == 200) {
        final List results = jsonDecode(response.body);
        return results.map((item) {
          final addr = item['address'] ?? {};
          final name = addr['city'] ?? addr['town'] ?? addr['state'] ?? item['display_name'].toString().split(',').first;
          return City(
            name: name.toString(),
            country: (addr['country'] ?? '').toString(),
            lat: double.tryParse(item['lat'].toString()) ?? 0.0,
            lng: double.tryParse(item['lon'].toString()) ?? 0.0,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}

// ============================
// Main App Entry
// ============================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prayer Times',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.cairoTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================
// Home Screen
// ============================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  City currentCity = const City(name: 'جدة', country: 'المملكة العربية السعودية', lat: 21.5433, lng: 39.1728);
  PrayerTimes? prayerTimes;
  bool isLoading = true;

  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  String _nextPrayerName = '';
  String _nextPrayerEn = '';
  String _nextPrayerTime12 = '';

  @override
  void initState() {
    super.initState();
    _initData();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    final savedCity = await StorageService.getLastCity();
    if (savedCity != null) {
      currentCity = savedCity;
    }
    await _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    setState(() => isLoading = true);
    final times = await PrayerApiService.fetchPrayerTimes(currentCity);
    if (mounted) {
      setState(() {
        prayerTimes = times;
        isLoading = false;
      });
      _updateNextPrayerCountdown();
    }
  }

  void _startCountdownTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNextPrayerCountdown();
    });
  }

  void _updateNextPrayerCountdown() {
    if (prayerTimes == null) return;

    final now = DateTime.now();
    final prayers = [
      {'name': 'الفجر', 'en': 'Fajr', 'time': prayerTimes!.fajr},
      {'name': 'الظهر', 'en': 'Dhuhr', 'time': prayerTimes!.dhuhr},
      {'name': 'العصر', 'en': 'Asr', 'time': prayerTimes!.asr},
      {'name': 'المغرب', 'en': 'Maghrib', 'time': prayerTimes!.maghrib},
      {'name': 'العشاء', 'en': 'Isha', 'time': prayerTimes!.isha},
    ];

    for (var p in prayers) {
      final parts = p['time']!.split(':');
      final pDateTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));

      if (pDateTime.isAfter(now)) {
        if (mounted) {
          final formatted = TimeFormatter.to12Hour(p['time']!);
          setState(() {
            _nextPrayerName = p['name']!;
            _nextPrayerEn = p['en']!;
            _nextPrayerTime12 = '${formatted['time']} ${formatted['period']}';
            _timeRemaining = pDateTime.difference(now);
          });
        }
        return;
      }
    }

    final parts = prayerTimes!.fajr.split(':');
    final tomorrowFajr = DateTime(now.year, now.month, now.day + 1, int.parse(parts[0]), int.parse(parts[1]));
    if (mounted) {
      final formatted = TimeFormatter.to12Hour(prayerTimes!.fajr);
      setState(() {
        _nextPrayerName = 'الفجر';
        _nextPrayerEn = 'Fajr';
        _nextPrayerTime12 = '${formatted['time']} ${formatted['period']}';
        _timeRemaining = tomorrowFajr.difference(now);
      });
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _openSearch() async {
    final selectedCity = await showSearch<City?>(
      context: context,
      delegate: CitySearchDelegate(),
    );
    if (selectedCity != null) {
      setState(() => currentCity = selectedCity);
      await StorageService.saveLastCity(selectedCity);
      await _loadPrayerTimes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTopHeader(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Lang.t(context, 'todaySchedule'),
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  isLoading
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppColors.primaryGreen),
                        ))
                      : _buildPrayerList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.darkGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 25),
      child: Column(
        children: [
          // Header Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    radius: 18,
                    child: const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('English ✨', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${currentCity.name}\n${currentCity.country}',
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.2),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.location_on_outlined, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            Lang.t(context, 'nextPrayer'),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 2),

          // Next Prayer Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _nextPrayerEn,
                style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w300),
              ),
              const SizedBox(width: 8),
              Text(
                _nextPrayerName.isEmpty ? '--' : _nextPrayerName,
                style: GoogleFonts.cairo(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Countdown Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nights_stay_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_timeRemaining),
                  style: GoogleFonts.robotoMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Time detail
          Text(
            '$_nextPrayerName الساعة $_nextPrayerTime12',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Dates Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('١٨ صفر ١٤٤٨ هـ'),
              const SizedBox(width: 8),
              _buildBadge('السبت ١ أغسطس ٢٠٢٦'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
    );
  }

  Widget _buildPrayerList() {
    if (prayerTimes == null) return const SizedBox();

    final prayers = [
      {'key': 'fajr', 'name': 'الفجر', 'en': 'Fajr', 'time': prayerTimes!.fajr, 'sub': 'فرض', 'icon': Icons.mosque_outlined},
      {'key': 'sunrise', 'name': 'الشروق', 'en': 'Sunrise', 'time': prayerTimes!.sunrise, 'sub': 'شروق', 'icon': Icons.wb_sunny_outlined},
      {'key': 'dhuhr', 'name': 'الظهر', 'en': 'Dhuhr', 'time': prayerTimes!.dhuhr, 'sub': 'خلال', 'icon': Icons.wb_sunny},
      {'key': 'asr', 'name': 'العصر', 'en': 'Asr', 'time': prayerTimes!.asr, 'sub': 'فرض', 'icon': Icons.cloud_outlined},
      {'key': 'maghrib', 'name': 'المغرب', 'en': 'Maghrib', 'time': prayerTimes!.maghrib, 'sub': 'فرض', 'icon': Icons.wb_twilight},
      {'key': 'isha', 'name': 'العشاء', 'en': 'Isha', 'time': prayerTimes!.isha, 'sub': 'فرض', 'icon': Icons.nights_stay_outlined},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prayers.length,
      itemBuilder: (context, index) {
        final item = prayers[index];
        final isNext = item['name'] == _nextPrayerName;
        final t12 = TimeFormatter.to12Hour(item['time'] as String);
        final iqamaStr = TimeFormatter.getIqamaTime(item['time'] as String);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isNext ? AppColors.primaryGreen : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Notification Bell (Left)
              CircleAvatar(
                backgroundColor: isNext ? Colors.white.withOpacity(0.2) : const Color(0xFFEAF3EE),
                radius: 18,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: isNext ? Colors.white : AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Time Block (12 Hours)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    t12['period']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isNext ? Colors.white70 : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t12['time']!,
                    style: GoogleFonts.robotoMono(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isNext ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Prayer Name & Subtext
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['en'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isNext ? Colors.white70 : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['name'] as String,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isNext ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item['key'] == 'sunrise'
                        ? 'الأذان'
                        : (item['key'] == 'dhuhr' && isNext
                            ? 'خلال ${_formatDuration(_timeRemaining)} الإقامة $iqamaStr'
                            : 'الإقامة $iqamaStr'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isNext ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Right Icon
              CircleAvatar(
                backgroundColor: isNext ? Colors.white.withOpacity(0.2) : const Color(0xFFEAF3EE),
                radius: 18,
                child: Icon(
                  item['icon'] as IconData,
                  color: isNext ? Colors.white : AppColors.primaryGreen,
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================
// Search Delegate
// ============================
class CitySearchDelegate extends SearchDelegate<City?> {
  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              query = '';
              showSuggestions(context);
            },
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().length < 2) {
      return Center(
        child: Text(
          Lang.t(context, 'searchCity'),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return FutureBuilder<List<City>>(
      future: PrayerApiService.searchCity(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              Lang.t(context, 'noCitiesFound'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final cities = snapshot.data!;

        return ListView.builder(
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            return ListTile(
              title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
              subtitle: Text(city.country, style: const TextStyle(color: AppColors.textMuted)),
              leading: const Icon(Icons.location_city, color: AppColors.primaryGreen),
              onTap: () => close(context, city),
            );
          },
        );
      },
    );
  }
}
