import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  await _initializeNotifications();
  runApp(const PrayerTimesApp());
}

Future<void> _initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('app_icon');
  const settings = InitializationSettings(android: androidSettings);

  await notificationsPlugin.initialize(settings: settings);

  final android = notificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();

  try {
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final identifier = timezoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(identifier));
  } catch (_) {
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
  }
}

const NotificationDetails _prayerNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'prayer_times_channel',
    'مواقيت الصلاة',
    channelDescription: 'تنبيهات الأذان والإقامة والشروق',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  ),
);

class PrayerTimesApp extends StatefulWidget {
  const PrayerTimesApp({super.key});

  @override
  State<PrayerTimesApp> createState() => _PrayerTimesAppState();
}

class _PrayerTimesAppState extends State<PrayerTimesApp> {
  bool _is24Hour = false;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    _loadAppSettings();
  }

  Future<void> _loadAppSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      _is24Hour = prefs.getBool('is_24_hour') ?? false;
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    });
  }

  Future<void> _changeTimeFormat(bool value) async {
    setState(() {
      _is24Hour = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_24_hour', value);
  }

  Future<void> _changeTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
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
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F8F5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF087F5B),
        secondary: Color(0xFFC08A16),
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme(
        ThemeData.light().textTheme,
      ),
      useMaterial3: true,
    );
  }

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
      themeMode: _isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light,
      darkTheme: _buildDarkTheme(),
      theme: _buildLightTheme(),
      home: PrayerTimesScreen(
        is24Hour: _is24Hour,
        isDarkMode: _isDarkMode,
        onTimeFormatChanged: _changeTimeFormat,
        onThemeChanged: _changeTheme,
      ),
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
    required this.iqamaTime,
  });

  final String name;
  final String time;
  final DateTime dateTime;
  final IconData icon;
  final Color color;
  final bool isSunrise;
  final DateTime? iqamaTime;
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({
    super.key,
    required this.is24Hour,
    required this.isDarkMode,
    required this.onTimeFormatChanged,
    required this.onThemeChanged,
  });

  final bool is24Hour;
  final bool isDarkMode;
  final ValueChanged<bool> onTimeFormatChanged;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  static const Color darkBackground = Color(0xFF071A16);
  static const Color darkCard = Color(0xFF102B25);
  static const Color lightBackground = Color(0xFFF1F8F5);
  static const Color lightCard = Colors.white;
  static const Color green = Color(0xFF35D399);
  static const Color darkGreen = Color(0xFF087F5B);
  static const Color gold = Color(0xFFE6B85C);

  String _cityName = 'جدة';
  double _latitude = 21.5433;
  double _longitude = 39.1728;

  String _timeZoneName = 'Asia/Riyadh';
  static const Map<String, int> _iqamaDelays = {
    'الفجر': 20,
    'الظهر': 10,
    'العصر': 10,
    'المغرب': 7,
    'العشاء': 10,
  };
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

  bool get _isDark => widget.isDarkMode;

  Color get _background =>
      _isDark ? darkBackground : lightBackground;

  Color get _cardColor =>
      _isDark ? darkCard : lightCard;

  Color get _primaryColor =>
      _isDark ? green : darkGreen;

  Color get _mainText =>
      _isDark ? Colors.white : const Color(0xFF10231D);

  Color get _mutedText =>
      _isDark ? const Color(0xFFA9C2BA) : const Color(0xFF6A8078);

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

  Future<void> _scheduleNotifications(List<_PrayerTimeItem> items) async {
    await notificationsPlugin.cancelAll();
    var id = 100;
    final today = tz.TZDateTime.now(_timeZoneLocation);

    Future<void> scheduleDay(DateTime date) async {
      final coordinates = Coordinates(_latitude, _longitude);
      final parameters = CalculationMethodParameters.ummAlQura();
      final times = PrayerTimes(
        date: DateTime.utc(date.year, date.month, date.day),
        coordinates: coordinates,
        calculationParameters: parameters,
        precision: false,
      );

      final events = <Map<String, dynamic>>[
        {'name': 'الفجر', 'time': times.fajr},
        {'name': 'الشروق', 'time': times.sunrise, 'sunrise': true},
        {'name': 'الظهر', 'time': times.dhuhr},
        {'name': 'العصر', 'time': times.asr},
        {'name': 'المغرب', 'time': times.maghrib},
        {'name': 'العشاء', 'time': times.isha},
      ];

      for (final event in events) {
        final localTime = tz.TZDateTime.from(
          event['time'] as DateTime,
          _timeZoneLocation,
        );
        final name = event['name'] as String;
        final isSunrise = event['sunrise'] == true;

        await _scheduleNotification(
          id: id++,
          time: localTime,
          title: isSunrise ? 'حان وقت الشروق' : 'حان الآن أذان $name',
          body: isSunrise
              ? 'نسأل الله لكم يوماً مباركاً'
              : 'حان وقت صلاة $name في $_cityName',
        );

        if (!isSunrise) {
          final delay = _iqamaDelays[name] ?? 10;
          await _scheduleNotification(
            id: id++,
            time: localTime.add(Duration(minutes: delay)),
            title: 'حان الآن وقت إقامة $name',
            body: 'حان وقت إقامة صلاة $name',
          );
        }
      }
    }

    await scheduleDay(today);
    await scheduleDay(today.add(const Duration(days: 1)));
  }

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime time,
    required String title,
    required String body,
  }) async {
    if (!time.isAfter(tz.TZDateTime.now(_timeZoneLocation))) {
      return;
    }

    try {
      await notificationsPlugin.zonedSchedule(
        id: id,
        scheduledDate: time,
        notificationDetails: _prayerNotificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (_) {}
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

    final formatter = widget.is24Hour
        ? DateFormat('HH:mm', 'ar')
        : DateFormat.jm('ar');

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
        iqamaTime: isSunrise
            ? null
            : localTime.add(Duration(minutes: _iqamaDelays[name] ?? 10)),
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

      nextPrayerTime = toLocalTime(
        tomorrowPrayerTimes.fajr,
      );

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
    _scheduleNotifications(items);
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

    final formatter = widget.is24Hour
        ? DateFormat('HH:mm', 'ar')
        : DateFormat.jm('ar');

    return formatter.format(nextTime);
  }

  String _formatRemainingTime() {
    final nextTime = _nextPrayerTime;

    if (nextTime == null) {
      return '';
    }

    final now =
        tz.TZDateTime.now(_timeZoneLocation);

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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          is24Hour: widget.is24Hour,
          isDarkMode: widget.isDarkMode,
          onTimeFormatChanged:
              widget.onTimeFormatChanged,
          onThemeChanged: widget.onThemeChanged,
        ),
      ),
    );

    if (mounted) {
      _calculatePrayerTimes();
    }
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'مواقيت الصلاة',
            style: TextStyle(
              color: _mainText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _mainText.withValues(alpha: 0.08),
            ),
          ),
          child: IconButton(
            onPressed: _openSettings,
            icon: Icon(
              Icons.settings_rounded,
              color: _primaryColor,
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _mainText.withValues(alpha: 0.08),
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
                  color: _primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: _primaryColor,
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
                      style: TextStyle(
                        color: _mainText,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'المنطقة الزمنية: $_timeZoneName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchCity,
            style: TextStyle(color: _mainText),
            decoration: InputDecoration(
              hintText: 'ابحث عن مدينة أخرى...',
              hintStyle: TextStyle(
                color: _mutedText,
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _primaryColor,
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
              fillColor: _background,
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
        gradient: LinearGradient(
          colors: _isDark
              ? const [
                  Color(0xFF1C7054),
                  Color(0xFF0D4033),
                ]
              : const [
                  Color(0xFF0E9F6E),
                  Color(0xFF087F5B),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.18),
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _mainText.withValues(alpha: 0.08),
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
              style: TextStyle(
                color: _mainText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$_currentPrayerName الآن',
            style: TextStyle(
              color: _primaryColor,
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
            ? _primaryColor.withValues(alpha: 0.16)
            : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrent
              ? _primaryColor.withValues(alpha: 0.65)
              : _mainText.withValues(alpha: 0.08),
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
                        ? _primaryColor
                        : _mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'وقت الصلاة الحالية',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.time,
                style: TextStyle(
                  color: isCurrent ? _primaryColor : _mainText,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!item.isSunrise && item.iqamaTime != null)
                Text(
                  'الإقامة ${DateFormat(widget.is24Hour ? 'HH:mm' : 'jm', 'ar').format(item.iqamaTime!)}',
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _primaryColor,
          backgroundColor: _cardColor,
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
                  Expanded(
                    child: Text(
                      'مواقيت اليوم',
                      style: TextStyle(
                        color: _mainText,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'حسب أم القرى',
                    style: TextStyle(
                      color: _mutedText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_prayerItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _primaryColor,
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
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.is24Hour,
    required this.isDarkMode,
    required this.onTimeFormatChanged,
    required this.onThemeChanged,
  });

  final bool is24Hour;
  final bool isDarkMode;
  final ValueChanged<bool> onTimeFormatChanged;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _is24Hour;
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();

    _is24Hour = widget.is24Hour;
    _isDarkMode = widget.isDarkMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness ==
        Brightness.dark;

    final cardColor = isDark
        ? const Color(0xFF102B25)
        : Colors.white;

    final background = isDark
        ? const Color(0xFF071A16)
        : const Color(0xFFF1F8F5);

    final mainText = isDark
        ? Colors.white
        : const Color(0xFF10231D);

    final mutedText = isDark
        ? const Color(0xFFA9C2BA)
        : const Color(0xFF6A8078);

    final primaryColor = isDark
        ? const Color(0xFF35D399)
        : const Color(0xFF087F5B);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: mainText,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: mainText.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: primaryColor,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تخصيص التطبيق',
                        style: TextStyle(
                          color: mainText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'اختر طريقة عرض الوقت والمظهر المناسب لك',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'إعدادات الوقت',
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mainText.withValues(alpha: 0.08),
              ),
            ),
            child: SwitchListTile(
              value: _is24Hour,
              onChanged: (value) {
                setState(() {
                  _is24Hour = value;
                });

                widget.onTimeFormatChanged(value);
              },
              activeColor: primaryColor,
              secondary: Icon(
                Icons.access_time_rounded,
                color: primaryColor,
              ),
              title: Text(
                'نظام 24 ساعة',
                style: TextStyle(
                  color: mainText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _is24Hour
                    ? 'مثال: 19:01'
                    : 'مثال: 7:01 م',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'المظهر',
            style: TextStyle(
              color: primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mainText.withValues(alpha: 0.08),
              ),
            ),
            child: SwitchListTile(
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });

                widget.onThemeChanged(value);
              },
              activeColor: primaryColor,
              secondary: Icon(
                _isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                color: _isDarkMode
                    ? const Color(0xFFB69CFF)
                    : const Color(0xFFE0A51A),
              ),
              title: Text(
                'الوضع الليلي',
                style: TextStyle(
                  color: mainText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _isDarkMode
                    ? 'ألوان داكنة مريحة للعين'
                    : 'ألوان فاتحة وواضحة',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              'مواقيت الصلاة',
              style: TextStyle(
                color: mutedText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
