import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  String _cityName = 'جدة';
  double _lat = 21.5433;
  double _lng = 39.1728;
  
  Map<String, String> _prayerTimes = {};
  String _gregorianDate = '';
  bool _isLoading = false;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadSavedLocation();
    _calculatePrayerTimes();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cityName = prefs.getString('saved_city_name') ?? 'جدة';
      _lat = prefs.getDouble('saved_lat') ?? 21.5433;
      _lng = prefs.getDouble('saved_lng') ?? 39.1728;
    });
  }

  Future<void> _saveLocation(String name, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_city_name', name);
    await prefs.setDouble('saved_lat', lat);
    await prefs.setDouble('saved_lng', lng);
  }

  void _calculatePrayerTimes() {
    final coordinates = Coordinates(_lat, _lng);
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
  }

  // البحث عن أي مدينة في العالم
  Future<void> _searchCity(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _cityName = query;
          _lat = loc.latitude;
          _lng = loc.longitude;
        });
        await _saveLocation(query, loc.latitude, loc.longitude);
        _calculatePrayerTimes();
        _searchController.clear();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم التبديل إلى: $query')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على المدينة، جرب اسماً آخر')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // الحصول على موقع المستخدم الحالي
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        
        String detectedName = 'موقعي الحالي';
        if (placemarks.isNotEmpty) {
          detectedName = placemarks.first.locality ?? placemarks.first.administrativeArea ?? 'موقعي الحالي';
        }

        setState(() {
          _cityName = detectedName;
          _lat = position.latitude;
          _lng = position.longitude;
        });

        await _saveLocation(detectedName, position.latitude, position.longitude);
        _calculatePrayerTimes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد الموقع تلقائياً')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
              // حقل البحث عن مدينة + زر تحديد الموقع
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن أي مدينة في العالم...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                      ),
                      onSubmitted: _searchCity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location, color: Color(0xFF10B981)),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // بطاقة اسم المدينة المختارة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      'المدينة الحالية: $_cityName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (_isLoading) ...[
                      const Spacer(),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                      )
                    ]
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

              // قائمة الأوقات
              Expanded(
                child: ListView.separated(
                  itemCount: _prayerTimes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
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
                            isSunrise ? Icons.wb_sunny : Icons.access_time_filled,
                            color: isSunrise ? Colors.orange : const Color(0xFF10B981),
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
                            color: isSunrise ? Colors.orange : const Color(0xFF10B981),
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
