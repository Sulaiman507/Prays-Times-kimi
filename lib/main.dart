import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مواقيت الصلاة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: kIsWeb ? 'Cairo' : GoogleFonts.cairo().fontFamily,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: kIsWeb ? 'Cairo' : GoogleFonts.cairo().fontFamily,
      ),
      themeMode: ThemeMode.system,
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
  Map<String, dynamic>? prayerTimes;
  Map<String, dynamic>? fullData;
  bool isLoading = true;
  String city = 'Makkah';
  String country = 'SA';
  final TextEditingController cityController = TextEditingController();
  List<String> favorites = [];
  String? nextPrayer;
  Duration? timeUntilNext;

  final List<String> prayerNames = [
    'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  ];
  final List<String> prayerNamesAr = [
    'الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'
  ];
  final List<String> prayerIcons = [
    '🌙', '☀️', '🌤️', '🌅', '🌇', '🌃'
  ];

  @override
  void initState() {
    super.initState();
    loadFavorites();
    loadSavedPrayerTimes();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favorites = prefs.getStringList('favorites') ?? [];
    });
  }

  Future<void> loadSavedPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('prayer_times');
    final savedCity = prefs.getString('city') ?? 'Makkah';
    final savedCountry = prefs.getString('country') ?? 'SA';
    final savedFull = prefs.getString('full_data');

    if (saved != null) {
      setState(() {
        prayerTimes = jsonDecode(saved);
        city = savedCity;
        country = savedCountry;
        isLoading = false;
        if (savedFull != null) fullData = jsonDecode(savedFull);
        _calculateNextPrayer();
      });
    } else {
      fetchPrayerTimes();
    }
  }

  Future<void> fetchPrayerTimes() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity?city=$city&country=$country&method=2'
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final timings = data['data']['timings'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('prayer_times', jsonEncode(timings));
        await prefs.setString('full_data', jsonEncode(data['data']));
        await prefs.setString('city', city);
        await prefs.setString('country', country);

        setState(() {
          prayerTimes = timings;
          fullData = data['data'];
          isLoading = false;
          _calculateNextPrayer();
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  void _calculateNextPrayer() {
    if (prayerTimes == null) return;
    final now = DateTime.now();

    List<Map<String, dynamic>> times = [];
    for (var name in prayerNames) {
      final timeStr = prayerTimes![name] ?? '00:00';
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      times.add({'name': name, 'time': dt});
    }

    times.sort((a, b) => a['time'].compareTo(b['time']));

    String? nextName;
    Duration? minDiff;
    for (var t in times) {
      final diff = t['time'].difference(now);
      if (diff.isNegative) continue;
      if (minDiff == null || diff < minDiff) {
        minDiff = diff;
        nextName = t['name'];
      }
    }

    if (nextName == null && times.isNotEmpty) {
      final fajr = times.firstWhere((t) => t['name'] == 'Fajr', orElse: () => times.first);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final fajrTomorrow = DateTime(tomorrow.year, tomorrow.month, tomorrow.day,
          fajr['time'].hour, fajr['time'].minute);
      minDiff = fajrTomorrow.difference(now);
      nextName = fajr['name'];
    }

    setState(() {
      nextPrayer = nextName;
      timeUntilNext = minDiff;
    });
  }

  Future<void> addToFavorites() async {
    final key = '$city, $country';
    if (!favorites.contains(key)) {
      setState(() => favorites.add(key));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorites', favorites);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة للمفضلة')),
      );
    }
  }

  void searchCity() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('البحث عن مدينة'),
        content: TextField(
          controller: cityController,
          decoration: const InputDecoration(
            hintText: 'اسم المدينة (مثال: Riyadh)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (cityController.text.isNotEmpty) {
                setState(() {
                  city = cityController.text;
                  country = 'SA';
                });
                fetchPrayerTimes();
                Navigator.pop(context);
              }
            },
            child: const Text('بحث'),
          ),
        ],
      ),
    );
  }

  void showFavorites() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'المفضلة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (favorites.isEmpty)
              const Text('لا توجد مدن مفضلة')
            else
              ...favorites.map((fav) {
                final parts = fav.split(', ');
                return ListTile(
                  title: Text(parts[0]),
                  subtitle: Text(parts[1]),
                  onTap: () {
                    setState(() {
                      city = parts[0];
                      country = parts[1];
                    });
                    fetchPrayerTimes();
                    Navigator.pop(context);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      setState(() => favorites.remove(fav));
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setStringList('favorites', favorites);
                      Navigator.pop(context);
                      showFavorites();
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'مواقيت الصلاة - $city',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (fullData != null)
              Text(
                '${fullData!['gregorian']['date']} - ${fullData!['hijri']['date']}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.white),
            onPressed: showFavorites,
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: searchCity,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.blue[900]!, Colors.teal[700]!],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : prayerTimes == null
                ? const Center(child: Text('لا توجد بيانات', style: TextStyle(color: Colors.white)))
                : RefreshIndicator(
                    onRefresh: fetchPrayerTimes,
                    color: Colors.teal,
                    child: ListView(
                      padding: const EdgeInsets.only(top: 80, left: 16, right: 16, bottom: 16),
                      children: [
                        if (nextPrayer != null && timeUntilNext != null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '⏳ متبقي على ${prayerNamesAr[prayerNames.indexOf(nextPrayer!)]}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatDuration(timeUntilNext!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...List.generate(prayerNames.length, (index) {
                          final key = prayerNames[index];
                          final time = prayerTimes![key] ?? '--:--';
                          final isCurrent = nextPrayer == key;

                          return Card(
                            elevation: isCurrent ? 8 : 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: isCurrent
                                ? Colors.amber.withOpacity(0.3)
                                : Colors.white.withOpacity(0.15),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCurrent ? Colors.amber : Colors.teal,
                                child: Text(
                                  prayerIcons[index],
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              title: Text(
                                prayerNamesAr[index],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                key,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Text(
                                time,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addToFavorites,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.favorite_border, color: Colors.white),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }
}
