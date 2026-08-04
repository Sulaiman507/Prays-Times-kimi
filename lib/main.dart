import 'dart:async';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _lat = 21.5433;
  double _lng = 39.1728;

  Map<String, String> _prayerTimes = const <String, String>{};
  String _gregorianDate = '';
  bool _isLoading = false;

  final TextEditingController _searchController =
      TextEditingController();

  final Geocoding _geocoding = Geocoding();

  @override
  void initState() {
    super.initState();
    unawaited(_initializeApp());
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
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _cityName = prefs.getString('saved_city_name') ?? 'جدة';
      _lat = prefs.getDouble('saved_lat') ?? 21.5433;
      _lng = prefs.getDouble('saved_lng') ?? 39.1728;
    });
  }

  Future<void> _saveLocation(
    String name,
    double latitude,
    double longitude,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('saved_city_name', name);
    await prefs.setDouble('saved_lat', latitude);
    await prefs.setDouble('saved_lng', longitude);
  }

  void _calculatePrayerTimes() {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);

    final coordinates = Coordinates(_lat, _lng);

    final calculationParameters =
        CalculationMethodParameters.ummAlQura();

    final prayerTimes = PrayerTimes(
      date: date,
      coordinates: coordinates,
      calculationParameters: calculationParameters,
    );

    final timeFormatter = DateFormat.jm('ar_SA');
    final dateFormatter =
        DateFormat('EEEE، d MMMM yyyy', 'ar_SA');

    setState(() {
      _prayerTimes = {
        'الفجر': timeFormatter.format(prayerTimes.fajr),
        'الشروق': timeFormatter.format(prayerTimes.sunrise),
        'الظهر': timeFormatter.format(prayerTimes.dhuhr),
        'العصر': timeFormatter.format(prayerTimes.asr),
        'المغرب': timeFormatter.format(prayerTimes.maghrib),
        'العشاء': timeFormatter.format(prayerTimes.isha),
      };

      _gregorianDate = dateFormatter.format(now);
    });
  }

  Future<void> _searchCity(String query) async {
    final cityQuery = query.trim();

    if (cityQuery.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await _geocoding.locationFromAddress(
        cityQuery,
      );

      if (!mounted) {
        return;
      }

      if (locations.isEmpty) {
        _showMessage(
          'لم يتم العثور على المدينة، جرّب اسماً آخر',
        );
        return;
      }

      final location = locations.first;

      setState(() {
        _cityName = cityQuery;
        _lat = location.latitude;
        _lng = location.longitude;
      });

      await _saveLocation(
        cityQuery,
        location.latitude,
        location.longitude,
      );

      if (!mounted) {
        return;
      }

      _calculatePrayerTimes();
      _searchController.clear();

      _showMessage('تم التبديل إلى: $cityQuery');
    } catch (_) {
      if (mounted) {
        _showMessage(
          'لم يتم العثور على المدينة، جرّب اسماً آخر',
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
        if (mounted) {
          _showMessage('يرجى تفعيل خدمة تحديد الموقع');
        }
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage('تم رفض إذن تحديد الموقع');
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showMessage(
            'تم رفض الإذن نهائياً. فعّل الموقع من إعدادات التطبيق',
          );
        }
        return;
      }

      final position =
          await Geolocator.getCurrentPosition();

      final placemarks =
          await _geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      var detectedName = 'موقعي الحالي';

      if (placemarks.isNotEmpty) {
        detectedName =
            placemarks.first.locality ??
            placemarks.first.subAdministrativeArea ??
            placemarks.first.administrativeArea ??
            'موقعي الحالي';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _cityName = detectedName;
        _lat = position.latitude;
        _lng = position.longitude;
      });

      await _saveLocation(
        detectedName,
        position.latitude,
        position.longitude,
      );

      if (!mounted) {
        return;
      }

      _calculatePrayerTimes();
      _showMessage('تم تحديث الموقع الحالي');
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر تحديد الموقع تلقائياً');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'مواقيت الصلاة',
          style: TextStyle(fontWeight: FontWeight.bold),
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
                    onPressed:
                        _isLoading ? null : _getCurrentLocation,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                      child: Text(
                        'المدينة الحالية: $_cityName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 16,
                        height: 16,
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
