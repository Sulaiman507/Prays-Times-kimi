import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    String jsonString = await DefaultAssetBundle.of(
            // We use simple inline map to avoid extra files
            )
        .loadString('assets/lang/${locale.languageCode}.json')
        .catchError((_) => '{}');

    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });
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
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// Inline translations fallback
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

  City({
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
        name: json['name'],
        country: json['country'] ?? '',
        lat: json['lat'].toDouble(),
        lng: json['lng'].toDouble(),
      );
}

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String date;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });

  factory PrayerTimes.fromApi(Map<String, dynamic> data, String dateStr) {
    final timings = data['timings'];
    return PrayerTimes(
      fajr: timings['Fajr'],
      sunrise: timings['Sunrise'],
      dhuhr: timings['Dhuhr'],
      asr: timings['Asr'],
      maghrib: timings['Maghrib'],
      isha: timings['Isha'],
      date: dateStr,
    );
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
        fajr: json['fajr'],
        sunrise: json['sunrise'],
        dhuhr: json['dhuhr'],
        asr: json['asr'],
        maghrib: json['maghrib'],
        isha: json['isha'],
        date: json['date'],
      );
}

// ============================
// Main App
// ============================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ar');

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
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
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0F172A),
          onPrimary: Colors.white,
          onSecondary: Colors.black,
        ),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardTheme(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white60),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================
// Storage Service
// ============================
class StorageService {
  static const String _cityKey = 'last_city';
  static const String _prayersKey = 'last_prayers';
  static const String _favoritesKey = 'favorites';
  static const String _langKey = 'language';

  static Future<void> saveLastCity(City city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, jsonEncode(city.toJson()));
  }

  static Future<City?> getLastCity() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_cityKey);
    if (str == null) return null;
    return City.fromJson(jsonDecode(str));
  }

  static Future<void> savePrayers(PrayerTimes prayers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prayersKey, jsonEncode(prayers.toJson()));
  }

  static Future<PrayerTimes?> getPrayers() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_prayersKey);
    if (str == null) return null;
    return PrayerTimes.fromJson(jsonDecode(str));
  }

  static Future<void> saveFavorites(List<City> cities) async {
    final prefs = await SharedPreferences.getInstance();
    final list = cities.map((c) => c.toJson()).toList();
    await prefs.setString(_favoritesKey, jsonEncode(list));
  }

  static Future<List<City>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_favoritesKey);
    if (str == null) return [];
    final list = jsonDecode(str) as List;
    return list.map((e) => City.fromJson(e)).toList();
  }

  static Future<void> saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_langKey) ?? 'ar';
  }
}

// ============================
// API Service
// ============================
class PrayerApiService {
  static Future<PrayerTimes?> fetchPrayerTimes(City city) async {
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final url =
        'https://api.aladhan.com/v1/timings/$date?latitude=${city.lat}&longitude=${city.lng}&method=4';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return PrayerTimes.fromApi(data['data'], date);
    }
    return null;
  }

  static Future<List<City>> searchCity(String query) async {
    if (query.length < 2) return [];
    final url =
        'https://api.aladhan.com/v1/cities?country=&state=&q=$query&limit=10';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final cities = data['data'] as List;
      return cities.map((c) {
        return City(
          name: c['name'] ?? '',
          country: c['country'] ?? '',
          lat: double.tryParse(c['latitude'].toString()) ?? 0,
          lng: double.tryParse(c['longitude'].toString()) ?? 0,
        );
      }).toList();
    }
    return [];
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
  City? currentCity;
  PrayerTimes? prayerTimes;
  List<City> favorites = [];
  bool isLoading = true;
  String? error;
  int selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    setState(() => isLoading = true);
    final savedCity = await StorageService.getLastCity();
    final savedPrayers = await StorageService.getPrayers();
    final savedFavorites = await StorageService.getFavorites();

    setState(() {
      favorites = savedFavorites;
      if (savedCity != null) {
        currentCity = savedCity;
        prayerTimes = savedPrayers;
      }
    });

    if (savedCity != null) {
      await refreshPrayerTimes(savedCity);
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> refreshPrayerTimes(City city) async {
    setState(() {
      currentCity = city;
      isLoading = true;
      error = null;
    });

    try {
      final prayers = await PrayerApiService.fetchPrayerTimes(city);
      if (prayers != null) {
        await StorageService.savePrayers(prayers);
        setState(() => prayerTimes = prayers);
      } else {
        setState(() => error = 'Failed to load prayer times');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  bool get isFavorite =>
      currentCity != null &&
      favorites.any((c) => c.name == currentCity!.name && c.country == currentCity!.country);

  void toggleFavorite() async {
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

  String getNextPrayer() {
    if (prayerTimes == null) return '';
    final now = TimeOfDay.now();
    final prayers = [
      {'name': Lang.t(context, 'fajr'), 'time': prayerTimes!.fajr},
      {'name': Lang.t(context, 'sunrise'), 'time': prayerTimes!.sunrise},
      {'name': Lang.t(context, 'dhuhr'), 'time': prayerTimes!.dhuhr},
      {'name': Lang.t(context, 'asr'), 'time': prayerTimes!.asr},
      {'name': Lang.t(context, 'maghrib'), 'time': prayerTimes!.maghrib},
      {'name': Lang.t(context, 'isha'), 'time': prayerTimes!.isha},
    ];

    for (var p in prayers) {
      final t = parseTime(p['time']!);
      if (t.hour > now.hour || (t.hour == now.hour && t.minute > now.minute)) {
        return '${p['name']}: ${p['time']}';
      }
    }
    return '${Lang.t(context, 'fajr')}: ${prayerTimes!.fajr}';
  }

  TimeOfDay parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(),
      FavoritesScreen(
        favorites: favorites,
        onCitySelected: (city) => refreshPrayerTimes(city),
      ),
      SettingsScreen(
        onLanguageChanged: () => setState(() {}),
      ),
    ];

    return Scaffold(
      body: SafeArea(child: pages[selectedNavIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavIndex,
        onDestinationSelected: (index) => setState(() => selectedNavIndex = index),
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF38BDF8).withOpacity(0.2),
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
                  // Header
                  Row(
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
                            DateFormat('EEEE, d MMMM', Localizations.localeOf(context).languageCode)
                                .format(DateTime.now()),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => _openSearch(),
                        icon: const Icon(Icons.search, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withOpacity(0.3),
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
                          style: const TextStyle(color: Colors.white80, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${Lang.t(context, 'nextPrayer')}: ${getNextPrayer()}',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Prayer Times Grid
                  if (isLoading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                  else if (error != null)
                    Center(
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    )
                  else if (prayerTimes == null)
                    Center(
                      child: Text(
                        Lang.t(context, 'noData'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    _buildPrayersGrid(prayerTimes!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayersGrid(PrayerTimes pt) {
    final prayers = [
      {'key': 'fajr', 'name': Lang.t(context, 'fajr'), 'time': pt.fajr, 'icon': Icons.wb_twilight},
      {'key': 'sunrise', 'name': Lang.t(context, 'sunrise'), 'time': pt.sunrise, 'icon': Icons.wb_sunny_outlined},
      {'key': 'dhuhr', 'name': Lang.t(context, 'dhuhr'), 'time': pt.dhuhr, 'icon': Icons.sunny},
      {'key': 'asr', 'name': Lang.t(context, 'asr'), 'time': pt.asr, 'icon': Icons.cloud},
      {'key': 'maghrib', 'name': Lang.t(context, 'maghrib'), 'time': pt.maghrib, 'icon': Icons.nights_stay_outlined},
      {'key': 'isha', 'name': Lang.t(context, 'isha'), 'time': pt.isha, 'icon': Icons.brightness_3},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: prayers.length,
      itemBuilder: (context, index) {
        final p = prayers[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(p['icon'] as IconData, color: const Color(0xFF38BDF8), size: 28),
                  if (p['key'] == getNextPrayerKey())
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        Lang.t(context, 'nextPrayer'),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['time'] as String,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    p['name'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String getNextPrayerKey() {
    if (prayerTimes == null) return '';
    final now = TimeOfDay.now();
    final prayers = [
      {'key': 'fajr', 'time': prayerTimes!.fajr},
      {'key': 'dhuhr', 'time': prayerTimes!.dhuhr},
      {'key': 'asr', 'time': prayerTimes!.asr},
      {'key': 'maghrib', 'time': prayerTimes!.maghrib},
      {'key': 'isha', 'time': prayerTimes!.isha},
    ];

    for (var p in prayers) {
      final t = parseTime(p['time']!);
      if (t.hour > now.hour || (t.hour == now.hour && t.minute > now.minute)) {
        return p['key']!;
      }
    }
    return 'fajr';
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
}

// ============================
// Search Delegate
// ============================
class CitySearchDelegate extends SearchDelegate<City?> {
  List<City> results = [];
  bool loading = false;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.length < 2) {
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
          return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No cities found', style: TextStyle(color: Colors.white60)),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final city = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.location_city, color: Color(0xFF38BDF8)),
              title: Text(city.name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(city.country, style: const TextStyle(color: Colors.white60)),
              onTap: () => close(context, city),
            );
          },
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              Lang.t(context, 'favorites'),
              style: const TextStyle(color: Colors.white60, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final city = favorites[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF38BDF8),
              child: Icon(Icons.location_on, color: Colors.white),
            ),
            title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(city.country),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white60),
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
  final VoidCallback onLanguageChanged;

  const SettingsScreen({super.key, required this.onLanguageChanged});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Lang.t(context, 'settings'),
            style: GoogleFonts.cairo(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: Color(0xFF38BDF8)),
              title: Text(Lang.t(context, 'language')),
              trailing: DropdownButton<String>(
                value: isArabic ? 'ar' : 'en',
                dropdownColor: const Color(0xFF1E293B),
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'ar', child: Text(Lang.t(context, 'arabic'))),
                  DropdownMenuItem(value: 'en', child: Text(Lang.t(context, 'english'))),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await StorageService.saveLanguage(value);
                    MyApp.setLocale(context, Locale(value));
                    onLanguageChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
