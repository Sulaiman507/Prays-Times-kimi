import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
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
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071A16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF35D399),
          secondary: Color(0xFFE6B85C),
          surface: Color(0xFF102B25),
        ),
        textTheme: GoogleFonts.cairoTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: const PrayerTimesScreen(),
    );
  }
}

class _PrayerTimeItem {
  const _PrayerTimeItem({
    required this.name,
    required this.time,
    required this.dateTime,
    required this.icon,
    required this.color,
    required this.isSunrise,
  });

  final String name;
  final String time;
  final DateTime dateTime;
  final IconData icon;
  final Color color;
  final bool isSunrise;
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  static const Color background = Color(0xFF071A16);
  static const Color cardColor = Color(0xFF102B25);
  static const Color green = Color(0xFF35D399);
  static const Color gold = Color(0xFFE6B85C);
  static const Color mutedText = Color(0xFFA9C2BA);

  String _cityName = 'جدة';
  double _latitude = 21.5433;
  double _longitude = 39.1728;

  String _timeZoneName = 'Asia/Riyadh';
  late tz.Location _timeZoneLocation;

  List<_PrayerTimeItem> _prayerItems = [];
  String _gregorianDate = '';
  String _currentPrayerName = 'قبل الفجر';
  String _nextPrayerName = 'الفجر';
  DateTime? _nextPrayerTime;

  bool _isLoading = false;

  final TextEditingController _searchController =
      TextEditingController();

  final Geocoding _geocoding = Geocoding();

  @override
  void initState() {
    super.initState();
    _timeZoneLocation = tz.getLocation('Asia/Riyadh');
    _initializeApp();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    await _loadSavedLocation();

    if (!mounted) {
      return;
    }

    _calculatePrayerTimes();

    try {
      final timeZoneName = await _fetchTimeZoneName(
        _latitude,
        _longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _timeZoneName = timeZoneName;
        _timeZoneLocation = tz.getLocation(timeZoneName);
      });

      _calculatePrayerTimes();

      await _saveLocation(
        _cityName,
        _latitude,
        _longitude,
        _timeZoneName,
      );
    } catch (_) {
      _calculatePrayerTimes();
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();

    final cityName =
        prefs.getString('saved_city_name') ?? 'جدة';

    final latitude =
        prefs.getDouble('saved_lat') ?? 21.5433;

    final longitude =
        prefs.getDouble('saved_lng') ?? 39.1728;

    final timeZoneName =
        prefs.getString('saved_timezone_name') ??
            'Asia/Riyadh';

    tz.Location location;

    try {
      location = tz.getLocation(timeZoneName);
    } catch (_) {
      location = tz.getLocation('Asia/Riyadh');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = cityName;
      _latitude = latitude;
      _longitude = longitude;
      _timeZoneName = timeZoneName;
      _timeZoneLocation = location;
    });
  }

  Future<void> _saveLocation(
    String cityName,
    double latitude,
    double longitude,
    String timeZoneName,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('saved_city_name', cityName);
    await prefs.setDouble('saved_lat', latitude);
    await prefs.setDouble('saved_lng', longitude);
    await prefs.setString(
      'saved_timezone_name',
      timeZoneName,
    );
  }

  Future<String> _fetchTimeZoneName(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.https(
      'www.timeapi.io',
      '/api/Time/current/coordinate',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode != 200) {
      throw Exception('تعذر جلب المنطقة الزمنية');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('استجابة غير صالحة');
    }

    final timeZoneName = decoded['timeZone'];

    if (timeZoneName is! String ||
        timeZoneName.trim().isEmpty) {
      throw Exception('اسم المنطقة الزمنية غير موجود');
    }

    final cleanName = timeZoneName.trim();

    tz.getLocation(cleanName);

    return cleanName;
  }

  void _calculatePrayerTimes() {
    if (!mounted) {
      return;
    }

    final localNow =
        tz.TZDateTime.now(_timeZoneLocation);

    final calculationDate = DateTime.utc(
      localNow.year,
      localNow.month,
      localNow.day,
    );

    final coordinates = Coordinates(
      _latitude,
      _longitude,
    );

    final parameters =
        CalculationMethodParameters.ummAlQura();

    final prayerTimes = PrayerTimes(
      date: calculationDate,
      coordinates: coordinates,
      calculationParameters: parameters,
      precision: false,
    );

    final formatter = DateFormat.jm('ar');

    DateTime toLocalTime(DateTime utcTime) {
      return tz.TZDateTime.from(
        utcTime,
        _timeZoneLocation,
      );
    }

    _PrayerTimeItem createItem({
      required String name,
      required DateTime utcTime,
      required IconData icon,
      required Color color,
      bool isSunrise = false,
    }) {
      final localTime = toLocalTime(utcTime);

      return _PrayerTimeItem(
        name: name,
        time: formatter.format(localTime),
        dateTime: localTime,
        icon: icon,
        color: color,
        isSunrise: isSunrise,
      );
    }

    final items = [
      createItem(
        name: 'الفجر',
        utcTime: prayerTimes.fajr,
        icon: Icons.nightlight_round,
        color: const Color(0xFF8DB4FF),
      ),
      createItem(
        name: 'الشروق',
        utcTime: prayerTimes.sunrise,
        icon: Icons.wb_twilight,
        color: gold,
        isSunrise: true,
      ),
      createItem(
        name: 'الظهر',
        utcTime: prayerTimes.dhuhr,
        icon: Icons.wb_sunny,
        color: const Color(0xFFFFD166),
      ),
      createItem(
        name: 'العصر',
        utcTime: prayerTimes.asr,
        icon: Icons.sunny,
        color: const Color(0xFFFFA45B),
      ),
      createItem(
        name: 'المغرب',
        utcTime: prayerTimes.maghrib,
        icon: Icons.wb_twilight,
        color: const Color(0xFFFF876C),
      ),
      createItem(
        name: 'العشاء',
        utcTime: prayerTimes.isha,
        icon: Icons.nightlight,
        color: const Color(0xFFB69CFF),
      ),
    ];

    final prayerItems = items.where(
      (item) => !item.isSunrise,
    );

    _PrayerTimeItem? nextItem;

    for (final item in prayerItems) {
      if (item.dateTime.isAfter(localNow)) {
        nextItem = item;
        break;
      }
    }

    DateTime? nextPrayerTime = nextItem?.dateTime;
    String nextPrayerName = nextItem?.name ?? 'الفجر';

    if (nextItem == null) {
      final tomorrow =
          calculationDate.add(const Duration(days: 1));

      final tomorrowPrayerTimes = PrayerTimes(
        date: tomorrow,
        coordinates: coordinates,
        calculationParameters: parameters,
        precision: false,
      );

      final tomorrowFajr =
          toLocalTime(tomorrowPrayerTimes.fajr);

      nextPrayerTime = tomorrowFajr;
      nextPrayerName = 'الفجر';
    }

    String currentPrayerName = 'قبل الفجر';

    for (final item in prayerItems) {
      if (!localNow.isBefore(item.dateTime)) {
        currentPrayerName = item.name;
      }
    }

    setState(() {
      _prayerItems = items;
      _currentPrayerName = currentPrayerName;
      _nextPrayerName = nextPrayerName;
      _nextPrayerTime = nextPrayerTime;
      _gregorianDate = DateFormat(
        'EEEE، d MMMM yyyy',
        'ar',
      ).format(localNow);
    });
  }

  Future<void> _changeLocation({
    required String cityName,
    required double latitude,
    required double longitude,
    required String successMessage,
  }) async {
    final timeZoneName = await _fetchTimeZoneName(
      latitude,
      longitude,
    );

    final location = tz.getLocation(timeZoneName);

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = cityName;
      _latitude = latitude;
      _longitude = longitude;
      _timeZoneName = timeZoneName;
      _timeZoneLocation = location;
    });

    await _saveLocation(
      cityName,
      latitude,
      longitude,
      timeZoneName,
    );

    if (!mounted) {
      return;
    }

    _calculatePrayerTimes();
    _searchController.clear();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
        ),
      );
  }

  Future<void> _searchCity(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final locations =
          await _geocoding.locationFromAddress(
        cleanQuery,
      );

      if (locations.isEmpty) {
        throw Exception('لم يتم العثور على المدينة');
      }

      final location = locations.first;

      await _changeLocation(
        cityName: cleanQuery,
        latitude: location.latitude,
        longitude: location.longitude,
        successMessage: 'تم التبديل إلى: $cleanQuery',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'لم يتم العثور على المدينة. '
                'اكتب المدينة والدولة معاً.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('خدمة الموقع غير مفعلة');
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        throw Exception('لم يتم السماح بالموقع');
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      var cityName = 'موقعي الحالي';

      try {
        final placemarks =
            await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;

          cityName = placemark.locality ??
              placemark.subAdministrativeArea ??
              placemark.administrativeArea ??
              'موقعي الحالي';
        }
      } catch (_) {}

      await _changeLocation(
        cityName: cityName,
        latitude: position.latitude,
        longitude: position.longitude,
        successMessage: 'تم تحديد موقعك: $cityName',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'تعذر تحديد موقعك. '
                'فعّل GPS واسمح للتطبيق باستخدام الموقع.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatNextPrayerTime() {
    final nextTime = _nextPrayerTime;

    if (nextTime == null) {
      return '--:--';
    }

    return DateFormat.jm('ar').format(nextTime);
  }

  String _formatRemainingTime() {
    final nextTime = _nextPrayerTime;

    if (nextTime == null) {
      return '';
    }

    final now = tz.TZDateTime.now(_timeZoneLocation);
    final difference = nextTime.difference(now);

    if (difference.isNegative) {
      return '';
    }

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    if (hours == 0) {
      return 'متبقي $minutes دقيقة';
    }

    return 'متبقي $hours ساعة و$minutes دقيقة';
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'السلام عليكم',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'مواقيت الصلاة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: IconButton(
            onPressed: _isLoading
                ? null
                : _calculatePrayerTimes,
            icon: const Icon(
              Icons.refresh_rounded,
              color: green,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المنطقة الزمنية: $_timeZoneName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchCity,
            decoration: InputDecoration(
              hintText: 'ابحث عن مدينة أخرى...',
              hintStyle: const TextStyle(
                color: mutedText,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: green,
                size: 21,
              ),
              suffixIcon: IconButton(
                onPressed: _isLoading
                    ? null
                    : _getCurrentLocation,
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: gold,
                  size: 20,
                ),
              ),
              filled: true,
              fillColor: background,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1C7054),
            Color(0xFF0D4033),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: green.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: green.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -35,
            child: Icon(
              Icons.mosque_rounded,
              size: 145,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'الصلاة القادمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: gold,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _nextPrayerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatNextPrayerTime(),
                style: const TextStyle(
                  color: gold,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatRemainingTime(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: gold,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gregorianDate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$_currentPrayerName الآن',
            style: const TextStyle(
              color: green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(_PrayerTimeItem item) {
    final isCurrent =
        item.name == _currentPrayerName;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? green.withValues(alpha: 0.16)
            : cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? green.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.3 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: isCurrent
                        ? green
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCurrent)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'وقت الصلاة الحالية',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            item.time,
            style: TextStyle(
              color: isCurrent
                  ? green
                  : Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF071A16),
              Color(0xFF0A211C),
              Color(0xFF071A16),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: green,
            backgroundColor: cardColor,
            onRefresh: () async {
              _calculatePrayerTimes();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                28,
              ),
              children: [
                _buildTopHeader(),
                const SizedBox(height: 20),
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildNextPrayerCard(),
                const SizedBox(height: 12),
                _buildDateCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'مواقيت اليوم',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'حسب أم القرى',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_prayerItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: green,
                      ),
                    ),
                  )
                else
                  ..._prayerItems.map(
                    (item) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 10),
                      child: _buildPrayerCard(item),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
