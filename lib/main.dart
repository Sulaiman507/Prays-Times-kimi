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
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF1E293B),
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

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  String _cityName = 'جدة';
  double _latitude = 21.5433;
  double _longitude = 39.1728;

  String _timeZoneName = 'Asia/Riyadh';
  late tz.Location _timeZoneLocation;

  Map<String, String> _prayerTimes = {};
  String _gregorianDate = '';
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
      final detectedTimeZone = await _fetchTimeZoneName(
        _latitude,
        _longitude,
      );

      if (!mounted) {
        return;
      }

      final detectedLocation =
          tz.getLocation(detectedTimeZone);

      if (_timeZoneName != detectedTimeZone) {
        setState(() {
          _timeZoneName = detectedTimeZone;
          _timeZoneLocation = detectedLocation;
        });

        _calculatePrayerTimes();

        await _saveLocation(
          _cityName,
          _latitude,
          _longitude,
          _timeZoneName,
        );
      }
    } catch (_) {
      _calculatePrayerTimes();
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();

    final savedCity =
        prefs.getString('saved_city_name') ?? 'جدة';

    final savedLatitude =
        prefs.getDouble('saved_lat') ?? 21.5433;

    final savedLongitude =
        prefs.getDouble('saved_lng') ?? 39.1728;

    final savedTimeZone =
        prefs.getString('saved_timezone_name') ??
            'Asia/Riyadh';

    tz.Location savedLocation;

    try {
      savedLocation = tz.getLocation(savedTimeZone);
    } catch (_) {
      savedLocation = tz.getLocation('Asia/Riyadh');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = savedCity;
      _latitude = savedLatitude;
      _longitude = savedLongitude;
      _timeZoneName = savedTimeZone;
      _timeZoneLocation = savedLocation;
    });
  }

  Future<void> _saveLocation(
    String cityName,
    double latitude,
    double longitude,
    String timeZoneName,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'saved_city_name',
      cityName,
    );

    await prefs.setDouble(
      'saved_lat',
      latitude,
    );

    await prefs.setDouble(
      'saved_lng',
      longitude,
    );

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

    final cleanTimeZoneName = timeZoneName.trim();

    tz.getLocation(cleanTimeZoneName);

    return cleanTimeZoneName;
  }

  void _calculatePrayerTimes() {
    if (!mounted) {
      return;
    }

    final localDateTime =
        tz.TZDateTime.now(_timeZoneLocation);

    final calculationDate = DateTime.utc(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );

    final coordinates = Coordinates(
      _latitude,
      _longitude,
    );

    final calculationParameters =
        CalculationMethodParameters.ummAlQura();

    final prayerTimes = PrayerTimes(
      date: calculationDate,
      coordinates: coordinates,
      calculationParameters: calculationParameters,
      precision: false,
    );

    final formatter = DateFormat.jm('ar');

    String formatPrayerTime(DateTime utcTime) {
      final cityTime = tz.TZDateTime.from(
        utcTime,
        _timeZoneLocation,
      );

      return formatter.format(cityTime);
    }

    final dateFormatter = DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    );

    setState(() {
      _prayerTimes = {
        'الفجر': formatPrayerTime(prayerTimes.fajr),
        'الشروق': formatPrayerTime(prayerTimes.sunrise),
        'الظهر': formatPrayerTime(prayerTimes.dhuhr),
        'العصر': formatPrayerTime(prayerTimes.asr),
        'المغرب': formatPrayerTime(prayerTimes.maghrib),
        'العشاء': formatPrayerTime(prayerTimes.isha),
      };

      _gregorianDate = dateFormatter.format(
        localDateTime,
      );
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

    final timeZoneLocation =
        tz.getLocation(timeZoneName);

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = cityName;
      _latitude = latitude;
      _longitude = longitude;
      _timeZoneName = timeZoneName;
      _timeZoneLocation = timeZoneLocation;
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
                'اكتب اسم المدينة والدولة، مثل: جدة، السعودية',
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

      var detectedCity = 'موقعي الحالي';

      try {
        final placemarks =
            await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;

          detectedCity = placemark.locality ??
              placemark.subAdministrativeArea ??
              placemark.administrativeArea ??
              'موقعي الحالي';
        }
      } catch (_) {
        detectedCity = 'موقعي الحالي';
      }

      await _changeLocation(
        cityName: detectedCity,
        latitude: position.latitude,
        longitude: position.longitude,
        successMessage: 'تم تحديد موقعك: $detectedCity',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'تعذر تحديد موقعك. '
                'تأكد من تفعيل GPS ومنح التطبيق صلاحية الموقع.',
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

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مواقيت الصلاة',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction:
                          TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            'ابحث عن أي مدينة في العالم...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF10B981),
                        ),
                        filled: true,
                        fillColor: surfaceColor,
                        contentPadding:
                            const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.white12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                      onSubmitted: _searchCity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : _getCurrentLocation,
                    icon: const Icon(
                      Icons.my_location,
                      color: Color(0xFF10B981),
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: surfaceColor,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المدينة الحالية: $_cityName',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المنطقة الزمنية: $_timeZoneName',
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981)
                          .withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'مواقيت اليوم',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _gregorianDate,
                      textAlign: TextAlign.center,
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
              Expanded(
                child: _prayerTimes.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF10B981),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _prayerTimes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final name =
                              _prayerTimes.keys.elementAt(
                            index,
                          );

                          final time =
                              _prayerTimes.values.elementAt(
                            index,
                          );

                          final isSunrise =
                              name == 'الشروق';

                          return Container(
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.05),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSunrise
                                    ? Colors.orange
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFF10B981)
                                        .withValues(alpha: 0.2),
                                child: Icon(
                                  isSunrise
                                      ? Icons.wb_sunny
                                      : Icons
                                          .access_time_filled,
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
