import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';

// ============================
// App Constants
// ============================
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF38BDF8);
  static const Color primaryDark = Color(0xFF0EA5E9);
  static const Color secondary = Color(0xFFF59E0B);
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
}

// ============================
// Main Execution Entry Point
// ============================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة خدمة الإشعارات المحلية
  await NotificationService.init();
  
  runApp(const MyApp());
}

// ============================
// Localization Setup
// ============================
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    _localizedStrings = Lang.texts[locale.languageCode] ?? Lang.texts['en']!;
    return true;
  }

  String translate(String key) => _localizedStrings[key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

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
      'searchCity': 'Search for a city...',
      'favorites': 'Favorites',
      'settings': 'Settings',
      'language': 'Language',
      'arabic': 'Arabic',
      'english': 'English',
      'noData': 'No prayer times available',
      'nextPrayer': 'Next Prayer',
      'today': 'Today',
      'addToFavorites': 'Add to Favorites',
      'removeFromFavorites': 'Remove',
      'noCitiesFound': 'No cities found',
      'failedToLoadPrayerTimes': 'Failed to load prayer times',
      'noFavoritesYet': 'No favorites yet',
      'timeFormat': 'Time Format',
      'hours12': '12 Hours',
      'hours24': '24 Hours',
      'am': 'AM',
      'pm': 'PM',
      'athan': 'Athan',
      'iqamah': 'Iqamah',
      'athanTitle': 'Prayer Time',
      'athanBody': 'It is time for',
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
      'favorites': 'المفضلة',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'arabic': 'العربية',
      'english': 'English',
      'noData': 'لا توجد مواقيت متاحة',
      'nextPrayer': 'الصلاة القادمة',
      'today': 'اليوم',
      'addToFavorites': 'إضافة للمفضلة',
      'removeFromFavorites': 'حذف',
      'noCitiesFound': 'لم يتم العثور على مدن',
      'failedToLoadPrayerTimes': 'فشل تحميل مواقيت الصلاة',
      'noFavoritesYet': 'لا توجد مفضلات بعد',
      'timeFormat': 'نظام الوقت',
      'hours12': '12 ساعة',
      'hours24': '24 ساعة',
      'am': 'ص',
      'pm': 'م',
      'athan': 'الأذان',
      'iqamah': 'الإقامة',
      'athanTitle': 'حان وقت الصلاة',
      'athanBody': 'حان الآن موعد أذان صلاة',
    },
  };

  static String t(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return texts[locale]?[key] ?? texts['en']![key] ?? key;
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'lat': lat,
        'lng': lng,
      };

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is City &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          country == other.country;

  @override
  int get hashCode => name.hashCode ^ country.hashCode;
}

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String date;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });

  factory PrayerTimes.fromApi(Map<String, dynamic> data, String dateStr) {
    final timings = data['timings'] as Map<String, dynamic>? ?? {};
    return PrayerTimes(
      fajr: _extractTime(timings['Fajr']),
      sunrise: _extractTime(timings['Sunrise']),
      dhuhr: _extractTime(timings['Dhuhr']),
      asr: _extractTime(timings['Asr']),
      maghrib: _extractTime(timings['Maghrib']),
      isha: _extractTime(timings['Isha']),
      date: dateStr,
    );
  }

  static String _extractTime(dynamic value) {
    if (value == null) return '--:--';
    final str = value.toString().trim();
    final match = RegExp(r'^(\d{1,2}:\d{2})').firstMatch(str);
    return match?.group(1) ?? str;
  }

  Map<String, dynamic> toJson() => {
        'fajr': fajr,
        'sunrise': sunrise,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'date': date,
      };

  factory PrayerTimes.fromJson(Map<String, dynamic> json) => PrayerTimes(
        fajr: (json['fajr'] ?? '--:--').toString(),
        sunrise: (json['sunrise'] ?? '--:--').toString(),
        dhuhr: (json['dhuhr'] ?? '--:--').toString(),
        asr: (json['asr'] ?? '--:--').toString(),
        maghrib: (json['maghrib'] ?? '--:--').toString(),
        isha: (json['isha'] ?? '--:--').toString(),
        date: (json['date'] ?? '').toString(),
      );
}

// ============================
// Main App
// ============================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    setState(() => _locale = locale);
  }

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final lang = await StorageService.getLanguage();
    if (mounted) {
      setState(() => _locale = Locale(lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prayer Times',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.white60),
      ),
    );
  }
}

// ============================
// Storage Service
// ============================
class StorageService {
  StorageService._();

  static const String _cityKey = 'last_city';
  static const String _prayersKey = 'last_prayers';
  static const String _favoritesKey = 'favorites';
  static const String _langKey = 'language';
  static const String _timeFormat24Key = 'is_24_hour';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> saveLastCity(City city) async {
    final prefs = await _instance;
    await prefs.setString(_cityKey, jsonEncode(city.toJson()));
  }

  static Future<City?> getLastCity() async {
    final prefs = await _instance;
    final str = prefs.getString(_cityKey);
    if (str == null || str.isEmpty) return null;
    try {
      return City.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePrayers(PrayerTimes prayers) async {
    final prefs = await _instance;
    await prefs.setString(_prayersKey, jsonEncode(prayers.toJson()));
  }

  static Future<PrayerTimes?> getPrayers() async {
    final prefs = await _instance;
    final str = prefs.getString(_prayersKey);
    if (str == null || str.isEmpty) return null;
    try {
      return PrayerTimes.fromJson(jsonDecode(str) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFavorites(List<City> cities) async {
    final prefs = await _instance;
    final list = cities.map((c) => c.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(list));
  }

  static Future<List<City>> getFavorites() async {
    final prefs = await _instance;
    final str = prefs.getString(_favoritesKey);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List<dynamic>;
      return list.map((e) => City.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLanguage(String lang) async {
    final prefs = await _instance;
    await prefs.setString(_langKey, lang);
  }

  static Future<String> getLanguage() async {
    final prefs = await _instance;
    return prefs.getString(_langKey) ?? 'ar';
  }

  static Future<void> saveIs24Hour(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(_timeFormat24Key, value);
  }

  static Future<bool> getIs24Hour() async {
    final prefs = await _instance;
    return prefs.getBool(_timeFormat24Key) ?? false;
  }
}

// ============================
// API Service
// ============================
class PrayerApiService {
  PrayerApiService._();

  static final http.Client _client = http.Client();

  static Future<PrayerTimes?> fetchPrayerTimes(City city) async {
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final url =
        'https://api.aladhan.com/v1/timings/$date?latitude=${city.lat}&longitude=${city.lng}&method=4';

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PrayerTimes.fromApi(data['data'], date);
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<City>> searchCity(String query) async {
    if (query.trim().length < 2) return [];
    final encodedQuery = Uri.encodeQueryComponent(query.trim());

    final url =
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&addressdetails=1&accept-language=ar,en&limit=10';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'PrayerTimesApp/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        final List<City> cities = [];

        for (var item in results) {
          final address = item['address'] as Map<String, dynamic>? ?? {};

          final cityName = address['city'] ??
              address['town'] ??
              address['state'] ??
              address['municipality'] ??
              item['display_name'].toString().split(',').first;

          final countryName = address['country'] ?? '';

          cities.add(City(
            name: cityName.toString(),
            country: countryName.toString(),
            lat: City._parseDouble(item['lat']) ?? 0.0,
            lng: City._parseDouble(item['lon']) ?? 0.0,
          ));
        }
        return cities;
      }
      return [];
    } catch (_) {
      return [];
    }
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

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  City? currentCity;
  PrayerTimes? prayerTimes;
  List<City> favorites = [];
  bool isLoading = true;
  bool is24Hour = false;
  String? error;
  int selectedNavIndex = 0;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeApp();

    // التحديث التلقائي كل دقيقة
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  // التعديل الجوهري: إجبار إعادة جدولة الإشعارات فور تأكيد موافقة الصلاحية
  Future<void> _initializeApp() async {
    await loadInitialData();
    await NotificationService.requestPermissions();
    if (prayerTimes != null) {
      _scheduleAllNotifications(prayerTimes!);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadInitialData() async {
    if (mounted) setState(() => isLoading = true);

    City? savedCity = await StorageService.getLastCity();
    final savedPrayers = await StorageService.getPrayers();
    final savedFavorites = await StorageService.getFavorites();
    final savedIs24Hour = await StorageService.getIs24Hour();

    if (savedCity == null) {
      savedCity = const City(
        name: 'جدة',
        country: 'المملكة العربية السعودية',
        lat: 21.4858,
        lng: 39.1925,
      );
      await StorageService.saveLastCity(savedCity);
    }

    if (mounted) {
      setState(() {
        is24Hour = savedIs24Hour;
        favorites = savedFavorites;
        currentCity = savedCity;
        prayerTimes = savedPrayers;
      });
    }

    await refreshPrayerTimes(savedCity);
  }

  Future<void> refreshPrayerTimes(City city) async {
    if (mounted) {
      setState(() {
        currentCity = city;
        isLoading = true;
        error = null;
      });
    }

    try {
      final prayers = await PrayerApiService.fetchPrayerTimes(city);
      if (prayers != null) {
        await StorageService.savePrayers(prayers);
        if (mounted) {
          setState(() => prayerTimes = prayers);
          _scheduleAllNotifications(prayers);
        }
      } else {
        if (mounted) {
          setState(() => error = Lang.t(context, 'failedToLoadPrayerTimes'));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // جدولة الإشعارات لجميع الصلوات
  void _scheduleAllNotifications(PrayerTimes pt) {
    final now = DateTime.now();
    final prayerList = [
      (id: 1, name: Lang.t(context, 'fajr'), timeStr: pt.fajr),
      (id: 2, name: Lang.t(context, 'dhuhr'), timeStr: pt.dhuhr),
      (id: 3, name: Lang.t(context, 'asr'), timeStr: pt.asr),
      (id: 4, name: Lang.t(context, 'maghrib'), timeStr: pt.maghrib),
      (id: 5, name: Lang.t(context, 'isha'), timeStr: pt.isha),
    ];

    for (var p in prayerList) {
      final parsedTime = _parseTime(p.timeStr);
      if (parsedTime != null) {
        final scheduledDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          parsedTime.hour,
          parsedTime.minute,
        );

        if (scheduledDateTime.isAfter(now)) {
          NotificationService.scheduleNotification(
            id: p.id,
            title: '${Lang.t(context, 'athanTitle')}: ${p.name}',
            body: '${Lang.t(context, 'athanBody')} ${p.name}',
            scheduledTime: scheduledDateTime,
          );
        }
        
        // جدولة الجمعة إذا صادف وقت الظهر
        if (p.id == 2) {
          NotificationService.scheduleFridayReminder(scheduledDateTime);
        }
      }
    }
  }

  bool get isFavorite =>
      currentCity != null &&
      favorites.any((c) =>
          c.name == currentCity!.name && c.country == currentCity!.country);

  Future<void> toggleFavorite() async {
    if (currentCity == null) return;
    setState(() {
      if (isFavorite) {
        favorites.removeWhere((c) =>
            c.name == currentCity!.name && c.country == currentCity!.country);
      } else {
        favorites.add(currentCity!);
      }
    });
    await StorageService.saveFavorites(favorites);
  }

  String _formatTime(String rawTime) {
    if (rawTime == '--:--') return rawTime;
    final clean = PrayerTimes._extractTime(rawTime);
    if (is24Hour) return clean;

    final parts = clean.split(':');
    if (parts.length < 2) return clean;
    int hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];

    final period = hour >= 12 ? Lang.t(context, 'pm') : Lang.t(context, 'am');
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final formattedHour = hour.toString().padLeft(2, '0');
    return '$formattedHour:$minute $period';
  }

  String _calculateIqamah(String rawAthanTime, int offsetMinutes) {
    if (rawAthanTime == '--:--') return '--:--';
    final clean = PrayerTimes._extractTime(rawAthanTime);
    final parts = clean.split(':');
    if (parts.length < 2) return '--:--';

    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1]) ?? 0;

    DateTime now = DateTime.now();
    DateTime athanDateTime = DateTime(now.year, now.month, now.day, hour, minute);
    DateTime iqamahDateTime = athanDateTime.add(Duration(minutes: offsetMinutes));

    final formattedRaw = DateFormat('HH:mm').format(iqamahDateTime);
    return _formatTime(formattedRaw);
  }

  TimeOfDay? _parseTime(String time) {
    final clean = PrayerTimes._extractTime(time);
    final parts = clean.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  ({String key, String name, String time})? _getNextPrayer() {
    if (prayerTimes == null) return null;

    final now = TimeOfDay.now();
    final prayers = [
      (key: 'fajr', name: Lang.t(context, 'fajr'), time: prayerTimes!.fajr),
      (key: 'dhuhr', name: Lang.t(context, 'dhuhr'), time: prayerTimes!.dhuhr),
      (key: 'asr', name: Lang.t(context, 'asr'), time: prayerTimes!.asr),
      (
        key: 'maghrib',
        name: Lang.t(context, 'maghrib'),
        time: prayerTimes!.maghrib
      ),
      (key: 'isha', name: Lang.t(context, 'isha'), time: prayerTimes!.isha),
    ];

    for (final p in prayers) {
      final t = _parseTime(p.time);
      if (t == null) continue;
      if (t.hour > now.hour ||
          (t.hour == now.hour && t.minute > now.minute)) {
        return p;
      }
    }

    return (
      key: 'fajr',
      name: Lang.t(context, 'fajr'),
      time: prayerTimes!.fajr
    );
  }

  String getNextPrayerText() {
    final next = _getNextPrayer();
    if (next == null) return '';
    return '${next.name}: ${_formatTime(next.time)}';
  }

  String getNextPrayerKey() {
    return _getNextPrayer()?.key ?? '';
  }

  void _openSearch() async {
    final city = await showSearch<City?>(
      context: context,
      delegate: CitySearchDelegate(),
    );
    if (city != null) {
      await StorageService.saveLastCity(city);
      await refreshPrayerTimes(city);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedNavIndex,
          children: [
            _buildHome(),
            FavoritesScreen(
              favorites: favorites,
              onCitySelected: (city) {
                setState(() => selectedNavIndex = 0);
                refreshPrayerTimes(city);
              },
            ),
            SettingsScreen(
              is24Hour: is24Hour,
              onTimeFormatChanged: (bool val) {
                setState(() => is24Hour = val);
              },
              onLanguageChanged: () => setState(() {}),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: (index) => setState(() => selectedNavIndex = index),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: Lang.t(context, 'appName'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: Lang.t(context, 'favorites'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: Lang.t(context, 'settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return RefreshIndicator(
      onRefresh: () async {
        if (currentCity != null) await refreshPrayerTimes(currentCity!);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildHeroCard(),
                  const SizedBox(height: 28),
                  _buildPrayerContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Lang.t(context, 'appName'),
              style: GoogleFonts.cairo(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              DateFormat(
                'EEEE, d MMMM',
                Localizations.localeOf(context).languageCode,
              ).format(DateTime.now()),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        IconButton(
          onPressed: _openSearch,
          icon: const Icon(Icons.search, color: Colors.white, size: 28),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  currentCity?.name ?? Lang.t(context, 'searchCity'),
                  style: GoogleFonts.cairo(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (currentCity != null)
                IconButton(
                  onPressed: toggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
            ],
          ),
          Text(
            currentCity?.country ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${Lang.t(context, 'nextPrayer')}: ${getNextPrayerText()}',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (error != null) {
      return Center(
        child: Text(
          error!,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }
    if (prayerTimes == null) {
      return Center(
        child: Text(
          Lang.t(context, 'noData'),
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    return _buildPrayersGrid(prayerTimes!);
  }

  Widget _buildPrayersGrid(PrayerTimes pt) {
    final prayers = [
      (key: 'fajr', name: Lang.t(context, 'fajr'), time: pt.fajr, icon: Icons.wb_twilight, iqamahOffset: 25, isPrayer: true),
      (key: 'sunrise', name: Lang.t(context, 'sunrise'), time: pt.sunrise, icon: Icons.wb_sunny_outlined, iqamahOffset: 0, isPrayer: false),
      (key: 'dhuhr', name: Lang.t(context, 'dhuhr'), time: pt.dhuhr, icon: Icons.sunny, iqamahOffset: 20, isPrayer: true),
      (key: 'asr', name: Lang.t(context, 'asr'), time: pt.asr, icon: Icons.cloud, iqamahOffset: 20, isPrayer: true),
      (key: 'maghrib', name: Lang.t(context, 'maghrib'), time: pt.maghrib, icon: Icons.nights_stay_outlined, iqamahOffset: 10, isPrayer: true),
      (key: 'isha', name: Lang.t(context, 'isha'), time: pt.isha, icon: Icons.brightness_3, iqamahOffset: 20, isPrayer: true),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: prayers.length,
      itemBuilder: (context, index) {
        final p = prayers[index];
        final isNext = p.key == getNextPrayerKey();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isNext ? AppColors.secondary.withOpacity(0.5) : Colors.white.withOpacity(0.05),
              width: isNext ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(p.icon, color: AppColors.primary, size: 26),
                  if (isNext)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Lang.t(context, 'nextPrayer'),
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                p.name,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Divider(color: Colors.white12, height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Lang.t(context, 'athan'),
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      Text(
                        _formatTime(p.time),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (p.isPrayer) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          Lang.t(context, 'iqamah'),
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        Text(
                          _calculateIqamah(p.time, p.iqamahOffset),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================
// Favorites Screen
// ============================
class FavoritesScreen extends StatelessWidget {
  final List<City> favorites;
  final Function(City) onCitySelected;

  const FavoritesScreen({
    super.key,
    required this.favorites,
    required this.onCitySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Center(
        child: Text(
          Lang.t(context, 'noFavoritesYet'),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final city = favorites[index];
        return Card(
          color: AppColors.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              city.name,
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              city.country,
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 18),
            onTap: () => onCitySelected(city),
          ),
        );
      },
    );
  }
}

// ============================
// Settings Screen
// ============================
class SettingsScreen extends StatelessWidget {
  final bool is24Hour;
  final ValueChanged<bool> onTimeFormatChanged;
  final VoidCallback onLanguageChanged;

  const SettingsScreen({
    super.key,
    required this.is24Hour,
    required this.onTimeFormatChanged,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentLang = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          Lang.t(context, 'settings'),
          style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        
        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: const Icon(Icons.language, color: AppColors.primary),
            title: Text(Lang.t(context, 'language'), style: const TextStyle(color: Colors.white)),
            trailing: DropdownButton<String>(
              value: currentLang,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: 'ar',
                  child: Text(Lang.t(context, 'arabic'), style: const TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(Lang.t(context, 'english'), style: const TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (String? newLang) async {
                if (newLang != null) {
                  await StorageService.saveLanguage(newLang);
                  if (context.mounted) {
                    MyApp.setLocale(context, Locale(newLang));
                    onLanguageChanged();
                  }
                }
              },
            ),
          ),
        ),
        
        const SizedBox(height: 10),

        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: const Icon(Icons.access_time, color: AppColors.primary),
            title: Text(Lang.t(context, 'timeFormat'), style: const TextStyle(color: Colors.white)),
            trailing: DropdownButton<bool>(
              value: is24Hour,
              dropdownColor: AppColors.surface,
              underline: const SizedBox(),
              items: [
                DropdownMenuItem(
                  value: false,
                  child: Text(Lang.t(context, 'hours12'), style: const TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text(Lang.t(context, 'hours24'), style: const TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (bool? newVal) async {
                if (newVal != null) {
                  await StorageService.saveIs24Hour(newVal);
                  onTimeFormatChanged(newVal);
                }
              },
            ),
          ),
        ),
      ],
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
          style: const TextStyle(color: Colors.white60),
        ),
      );
    }

    return FutureBuilder<List<City>>(
      future: PrayerApiService.searchCity(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              Lang.t(context, 'noCitiesFound'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final cities = snapshot.data!;

        return ListView.builder(
          itemCount: cities.length,
          itemBuilder: (context, index) {
            final city = cities[index];
            return ListTile(
              title: Text(city.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(city.country, style: const TextStyle(color: Colors.white70)),
              leading: const Icon(Icons.location_city, color: AppColors.primary),
              onTap: () => close(context, city),
            );
          },
        );
      },
    );
  }
}
