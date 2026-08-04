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
import 'package:worldtime/worldtime.dart';

void main() {
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
        primaryColor: const Color(0xFF10B981),
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

class _TimeZoneInfo {
  const _TimeZoneInfo({
    required this.name,
    required this.offset,
  });

  final String name;
  final Duration offset;
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

  String _timeZoneName = 'Asia/Riyadh';
  Duration _utcOffset = const Duration(hours: 3);

  Map<String, String> _prayerTimes = {};
  String _gregorianDate = '';
  bool _isLoading = false;

  final TextEditingController _searchController =
      TextEditingController();

  final Geocoding _geocoding = Geocoding();

  @override
  void initState() {
    super.initState();
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
      final timeZoneInfo = await _fetchTimeZoneInfo(
        _lat,
        _lng,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _timeZoneName = timeZoneInfo.name;
        _utcOffset = timeZoneInfo.offset;
      });

      _calculatePrayerTimes();

      await _saveLocation(
        _cityName,
        _lat,
        _lng,
        _timeZoneName,
        _utcOffset,
      );
    } catch (_) {
      _calculatePrayerTimes();
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();

    final savedOffsetMinutes =
        prefs.getInt('saved_timezone_offset_minutes');

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = prefs.getString('saved_city_name') ?? 'جدة';
      _lat = prefs.getDouble('saved_lat') ?? 21.5433;
      _lng = prefs.getDouble('saved_lng') ?? 39.1728;

      _timeZoneName =
          prefs.getString('saved_timezone_name') ?? 'Asia/Riyadh';

      _utcOffset = Duration(
        minutes: savedOffsetMinutes ?? 180,
      );
    });
  }

  Future<void> _saveLocation(
    String name,
    double latitude,
    double longitude,
    String timeZoneName,
    Duration utcOffset,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('saved_city_name', name);
    await prefs.setDouble('saved_lat', latitude);
    await prefs.setDouble('saved_lng', longitude);
    await prefs.setString('saved_timezone_name', timeZoneName);
    await prefs.setInt(
      'saved_timezone_offset_minutes',
      utcOffset.inMinutes,
    );
  }

  Future<_TimeZoneInfo> _fetchTimeZoneInfo(
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
      throw Exception('استجابة غير صالحة من خدمة التوقيت');
    }

    final timeZoneName = decoded['timeZone'] as String?;
    final dateTimeValue = decoded['dateTime'] as String?;

    if (timeZoneName == null ||
        timeZoneName.isEmpty ||
        dateTimeValue == null ||
        dateTimeValue.isEmpty) {
      throw Exception('بيانات المنطقة الزمنية ناقصة');
    }

    final remoteLocalDateTime =
        DateTime.tryParse(dateTimeValue);

    if (remoteLocalDateTime == null) {
      throw Exception('تعذر قراءة الوقت المحلي للمدينة');
    }

    final remoteTimeAsUtc = DateTime.utc(
      remoteLocalDateTime.year,
      remoteLocalDateTime.month,
      remoteLocalDateTime.day,
      remoteLocalDateTime.hour,
      remoteLocalDateTime.minute,
      remoteLocalDateTime.second,
    );

    final currentUtcTime = DateTime.now().toUtc();

    final approximateOffset =
        remoteTimeAsUtc.difference(currentUtcTime);

    final offsetMinutes =
        (approximateOffset.inSeconds / 60).round();

    return _TimeZoneInfo(
      name: timeZoneName,
      offset: Duration(minutes: offsetMinutes),
    );
  }

  void _calculatePrayerTimes() {
    final localNow = DateTime.now().toUtc().add(_utcOffset);

    final calculationDate = DateTime.utc(
      localNow.year,
      localNow.month,
      localNow.day,
    );

    final coordinates = Coordinates(_lat, _lng);

    final calculationParameters =
        CalculationMethodParameters.ummAlQura();

    final prayerTimes = PrayerTimes(
      date: calculationDate,
      coordinates: coordinates,
      calculationParameters: calculationParameters,
      precision: false,
    );

    final timeFormatter = DateFormat.jm('ar');

    String formatPrayerTime(DateTime utcPrayerTime) {
      final localPrayerTime =
          utcPrayerTime.add(_utcOffset);

      return timeFormatter.format(localPrayerTime);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _prayerTimes = {
        'الفجر': formatPrayerTime(prayerTimes.fajr),
        'الشروق': formatPrayerTime(prayerTimes.sunrise),
        'الظهر': formatPrayerTime(prayerTimes.dhuhr),
        'العصر': formatPrayerTime(prayerTimes.asr),
        'المغرب': formatPrayerTime(prayerTimes.maghrib),
        'العشاء': formatPrayerTime(prayerTimes.isha),
      };

      _gregorianDate = DateFormat(
        'EEEE، d MMMM yyyy',
        'ar',
      ).format(localNow);
    });
  }

  Future<void> _applyLocation({
    required String name,
    required double latitude,
    required double longitude,
    required String successMessage,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final timeZoneInfo = await _fetchTimeZoneInfo(
        latitude,
        longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cityName = name;
        _lat = latitude;
        _lng = longitude;
        _timeZoneName = timeZoneInfo.name;
        _utcOffset = timeZoneInfo.offset;
      });

      await _saveLocation(
        name,
        latitude,
        longitude,
        timeZoneInfo.name,
        timeZoneInfo.offset,
      );

      _calculatePrayerTimes();
      _searchController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديد المنطقة الزمنية لهذه المدينة. '
              'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
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

  Future<void> _searchCity(String query) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await _geocoding.locationFromAddress(
        cleanQuery,
      );

      if (locations.isEmpty) {
        throw Exception('لم يتم العثور على المدينة');
      }

      final location = locations.first;

      await _applyLocation(
        name: cleanQuery,
        latitude: location.latitude,
        longitude: location.longitude,
        successMessage: 'تم التبديل إلى: $cleanQuery',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    if (!mounted || _isLoading) {
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

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('لم يتم السماح باستخدام الموقع');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      var detectedName = 'موقعي الحالي';

      try {
        final placemarks =
            await _geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;

          detectedName = placemark.locality ??
              placemark.subAdministrativeArea ??
              placemark.administrativeArea ??
              'موقعي الحالي';
        }
      } catch (_) {
        detectedName = 'موقعي الحالي';
      }

      await _applyLocation(
        name: detectedName,
        latitude: position.latitude,
        longitude: position.longitude,
        successMessage: 'تم تحديد موقعك: $detectedName',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  String _formatUtcOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final absoluteMinutes = totalMinutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;

    return 'UTC$sign'
        '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
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
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن أي مدينة في العالم...',
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'المنطقة الزمنية: $_timeZoneName '
                            '(${_formatUtcOffset(_utcOffset)})',
                            overflow: TextOverflow.ellipsis,
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
                          .withOpacity(0.3),
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
                              _prayerTimes.keys.elementAt(index);
                          final time =
                              _prayerTimes.values.elementAt(index);
                          final isSunrise = name == 'الشروق';

                          return Container(
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius:
                                  BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white
                                    .withOpacity(0.05),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isSunrise
                                    ? Colors.orange
                                        .withOpacity(0.2)
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
