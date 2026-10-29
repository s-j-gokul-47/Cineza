import 'dart:async';
import 'package:flutter/material.dart';
import '../models/city.dart';
import '../theme/app_theme.dart';

/// Region Discovery & Multi-Stage Location Selector Screen
/// Implements 3-step sequential flow: Country -> State -> City/District -> Final Confirmation
/// with smooth move-left slide transitions, format filtering, tactile cinema ticket,
/// and Google Stitch Cinema theme (Dark & Bright).
class LocationSelectorScreen extends StatefulWidget {
  final City? currentCity;
  final List<City>? availableCities;
  final ValueChanged<City>? onLocationConfirmed;

  const LocationSelectorScreen({
    super.key,
    this.currentCity,
    this.availableCities,
    this.onLocationConfirmed,
  });

  @override
  State<LocationSelectorScreen> createState() => _LocationSelectorScreenState();
}

class _LocationSelectorScreenState extends State<LocationSelectorScreen>
    with SingleTickerProviderStateMixin {
  // Stepper Stage (1: Country, 2: State, 3: City, 4: Final Confirmation)
  int _currentStep = 1;

  // Slide transition direction: 1 = forward (move left), -1 = backward (move right)
  int _slideDirection = 1;

  // Selected Location
  String _selectedCountry = 'United States';
  String _selectedCountryFlag = '🇺🇸';
  String _selectedState = 'New York';
  String _selectedCity = 'New York City';
  String _cityDetails = '48 Cinemas available (AMC Lincoln Square 13, Regal Times Sq, Alamo)';
  int _selectedCityId = 1;

  // Format Filter ('All', 'IMAX Laser', 'Dolby Atmos', '4DX', 'VIP Lounges')
  String _selectedFormatFilter = 'All';

  // Search Controllers
  final TextEditingController _countrySearchController = TextEditingController();
  final TextEditingController _stateSearchController = TextEditingController();
  final TextEditingController _citySearchController = TextEditingController();

  String _countrySearchQuery = '';
  String _stateSearchQuery = '';
  String _citySearchQuery = '';

  // GPS Simulation state
  bool _isGpsLocating = false;
  String _gpsButtonText = 'Auto-detect GPS';

  // Saving / Confirming animation state
  bool _isConfirming = false;
  String _confirmButtonText = 'Confirm & Start Booking';

  // Dynamic Theme-Aware Palette Tokens (Google Stitch Cinema System)
  bool get isDark => ThemeController.isDark(context);

  Color get kBackground => AppTheme.getBackground(isDark);
  Color get kSurfaceLow => isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceContainer;
  Color get kSurface => isDark ? AppTheme.darkSurfaceContainer : AppTheme.lightSurface;
  Color get kSurfaceHigh => isDark ? AppTheme.darkSurfaceBorder : AppTheme.lightSurfaceBorder;
  Color get kSurfaceHighest => isDark ? AppTheme.darkSurfaceHighest : AppTheme.lightSurfaceHighest;
  Color get kPrimary => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kPrimaryVivid => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kSecondary => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kGold => AppTheme.getGoldAccent(isDark);
  Color get kTextWhite => AppTheme.getTextPrimary(isDark);
  Color get kTextMuted => AppTheme.getTextMuted(isDark);

  /// Argent CF - High-End Cinematic Serif for Headings & Main Titles
  TextStyle _argentHeading({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return AppTheme.argentHeading(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Proxima Nova - Crisp Modern Geometric Grotesque for All Remaining UI & Body Text
  TextStyle _proximaBody({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? fontStyle,
  }) {
    return AppTheme.proximaBody(
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // --- DATA SOURCES ---

  final List<_CountryData> _countries = [
    _CountryData(name: 'United States', flag: '🇺🇸', subtitle: 'AMC, Regal & Cinemark', screenCount: '1200+ Theatres'),
    _CountryData(name: 'India', flag: '🇮🇳', subtitle: 'PVR INOX, Cinepolis', screenCount: '840+ Theatres'),
    _CountryData(name: 'United Kingdom', flag: '🇬🇧', subtitle: 'BFI, Odeon, Vue, Curzon', screenCount: '410+ Theatres'),
    _CountryData(name: 'United Arab Emirates', flag: '🇦🇪', subtitle: 'VOX, Reel Cinemas', screenCount: '190+ Theatres'),
    _CountryData(name: 'Singapore', flag: '🇸🇬', subtitle: 'Shaw Theatres, GV', screenCount: '85+ Theatres'),
    _CountryData(name: 'Canada', flag: '🇨🇦', subtitle: 'Cineplex, Landmark', screenCount: '320+ Theatres'),
    _CountryData(name: 'Australia', flag: '🇦🇺', subtitle: 'Event, Hoyts, Village', screenCount: '280+ Theatres'),
    _CountryData(name: 'Germany', flag: '🇩🇪', subtitle: 'CinemaxX, UCI', screenCount: '350+ Theatres'),
  ];

  final Map<String, List<_StateData>> _statesByCountry = {
    'United States': [
      _StateData(name: 'New York', screens: '142 Screens'),
      _StateData(name: 'California', screens: '185 Screens'),
      _StateData(name: 'Texas', screens: '160 Screens'),
      _StateData(name: 'Florida', screens: '98 Screens'),
      _StateData(name: 'Illinois', screens: '82 Screens'),
      _StateData(name: 'Washington', screens: '64 Screens'),
    ],
    'India': [
      _StateData(name: 'Maharashtra', screens: '148 Screens'),
      _StateData(name: 'Karnataka', screens: '92 Screens'),
      _StateData(name: 'Delhi NCR', screens: '110 Screens'),
      _StateData(name: 'Tamil Nadu', screens: '124 Screens'),
      _StateData(name: 'Telangana', screens: '88 Screens'),
      _StateData(name: 'Gujarat', screens: '64 Screens'),
      _StateData(name: 'West Bengal', screens: '52 Screens'),
      _StateData(name: 'Kerala', screens: '58 Screens'),
      _StateData(name: 'Rajasthan', screens: '36 Screens'),
      _StateData(name: 'Punjab', screens: '42 Screens'),
      _StateData(name: 'Madhya Pradesh', screens: '30 Screens'),
      _StateData(name: 'Uttar Pradesh', screens: '76 Screens'),
    ],
    'United Kingdom': [
      _StateData(name: 'Greater London', screens: '120 Screens'),
      _StateData(name: 'West Midlands', screens: '45 Screens'),
      _StateData(name: 'Greater Manchester', screens: '38 Screens'),
      _StateData(name: 'Scotland', screens: '50 Screens'),
    ],
    'United Arab Emirates': [
      _StateData(name: 'Dubai', screens: '110 Screens'),
      _StateData(name: 'Abu Dhabi', screens: '55 Screens'),
      _StateData(name: 'Sharjah', screens: '25 Screens'),
    ],
    'Canada': [
      _StateData(name: 'Ontario', screens: '160 Screens'),
      _StateData(name: 'British Columbia', screens: '85 Screens'),
      _StateData(name: 'Quebec', screens: '75 Screens'),
    ],
    'Singapore': [
      _StateData(name: 'Central Region', screens: '45 Screens'),
      _StateData(name: 'East Region', screens: '22 Screens'),
      _StateData(name: 'West Region', screens: '18 Screens'),
    ],
    'Australia': [
      _StateData(name: 'New South Wales', screens: '115 Screens'),
      _StateData(name: 'Victoria', screens: '95 Screens'),
      _StateData(name: 'Queensland', screens: '70 Screens'),
    ],
    'Germany': [
      _StateData(name: 'Berlin', screens: '80 Screens'),
      _StateData(name: 'Bavaria', screens: '95 Screens'),
      _StateData(name: 'North Rhine-Westphalia', screens: '120 Screens'),
    ],
  };

  // --- COMPREHENSIVE REGIONAL CINEMA CITIES ---
  final Map<String, List<_CityData>> _citiesByState = {
    // New York / NY
    'New York': [
      _CityData(
        id: 1,
        name: 'New York City',
        screensInfo: '48 Cinemas • Lincoln Square IMAX',
        details: '48 Cinemas available (AMC Lincoln Square 13, Regal Times Sq, Alamo)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'IMAX 70MM',
      ),
      _CityData(
        id: 101,
        name: 'Brooklyn',
        screensInfo: '18 Cinemas • Alamo Downtown',
        details: '18 Cinemas available (Alamo Drafthouse Downtown, Nitehawk Cinema)',
        icon: Icons.movie_filter_rounded,
        badge: 'VIP DINE-IN',
      ),
      _CityData(
        id: 102,
        name: 'Queens',
        screensInfo: '14 Cinemas • Regal UA Midway IMAX',
        details: '14 Cinemas available (Regal UA Midway IMAX, Kaufman Astoria)',
        icon: Icons.theaters_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 103,
        name: 'Buffalo',
        screensInfo: '12 Cinemas • Regal Elmwood & IMAX',
        details: '12 Cinemas available (Regal Elmwood Center, AMC Maple Ridge 8)',
        icon: Icons.domain_rounded,
      ),
      _CityData(
        id: 104,
        name: 'Rochester',
        screensInfo: '10 Cinemas • Cinemark Tinseltown',
        details: '10 Cinemas available (Cinemark Tinseltown IMAX, Little Theatre)',
        icon: Icons.local_activity_rounded,
        badge: 'DOLBY',
      ),
      _CityData(
        id: 105,
        name: 'Albany',
        screensInfo: '8 Cinemas • Regal Colonie Center',
        details: '8 Cinemas available (Regal Colonie Center IMAX, Spectrum 8)',
        icon: Icons.corporate_fare_rounded,
      ),
    ],

    // California / CA
    'California': [
      _CityData(
        id: 17,
        name: 'Los Angeles',
        screensInfo: '54 Cinemas • Universal & TCL Chinese',
        details: '54 Cinemas available (TCL Chinese Theatre, AMC Universal CityWalk)',
        icon: Icons.movie_rounded,
        hasLaser: true,
        badge: 'IMAX LASER',
      ),
      _CityData(
        id: 18,
        name: 'San Francisco',
        screensInfo: '28 Cinemas • Metreon IMAX',
        details: '28 Cinemas available (AMC Metreon 16, Century San Francisco)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 106,
        name: 'San Diego',
        screensInfo: '22 Cinemas • Regal Edwards IMAX',
        details: '22 Cinemas available (Regal Edwards Mira Mesa, AMC Mission Valley)',
        icon: Icons.theaters_rounded,
        badge: '4DX',
      ),
      _CityData(
        id: 107,
        name: 'San Jose',
        screensInfo: '16 Cinemas • Pruneyard Dine-In',
        details: '16 Cinemas available (Pruneyard Dine-In, AMC Eastridge 15)',
        icon: Icons.apartment_rounded,
      ),
      _CityData(
        id: 108,
        name: 'Anaheim',
        screensInfo: '14 Cinemas • AMC Orange 30 IMAX',
        details: '14 Cinemas available (AMC The Outlets Orange, Starlight Cinema City)',
        icon: Icons.attractions_rounded,
        badge: 'IMAX',
      ),
    ],

    // Texas / TX
    'Texas': [
      _CityData(
        id: 109,
        name: 'Austin',
        screensInfo: '24 Cinemas • Alamo Drafthouse Lamar',
        details: '24 Cinemas available (Alamo South Lamar, Bullock Museum IMAX)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'IMAX LASER',
      ),
      _CityData(
        id: 110,
        name: 'Houston',
        screensInfo: "36 Cinemas • Regal Edwards Marq'E",
        details: "36 Cinemas available (Regal Edwards Marq'E IMAX, AMC Gulf Pointe)",
        icon: Icons.domain_rounded,
        badge: '4DX',
      ),
      _CityData(
        id: 111,
        name: 'Dallas',
        screensInfo: '30 Cinemas • Cinemark 17 IMAX',
        details: '30 Cinemas available (Cinemark 17 IMAX, Studio Movie Grill)',
        icon: Icons.theaters_rounded,
        badge: 'IMAX 70MM',
      ),
    ],

    // Illinois / IL
    'Illinois': [
      _CityData(
        id: 112,
        name: 'Chicago',
        screensInfo: '32 Cinemas • AMC River East & Navy Pier',
        details: '32 Cinemas available (AMC River East 21, ShowPlace ICON Dolby)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'DOLBY CINEMA',
      ),
      _CityData(
        id: 113,
        name: 'Naperville',
        screensInfo: '12 Cinemas • Hollywood Palm',
        details: '12 Cinemas available (Hollywood Palm Cinema, AMC Naperville 16)',
        icon: Icons.movie_rounded,
      ),
    ],

    // Florida / FL
    'Florida': [
      _CityData(
        id: 114,
        name: 'Miami',
        screensInfo: '24 Cinemas • Silverspot & Regal South Beach',
        details: '24 Cinemas available (Silverspot Cinema, Regal South Beach IMAX)',
        icon: Icons.apartment_rounded,
        badge: 'VIP DINE-IN',
      ),
      _CityData(
        id: 115,
        name: 'Orlando',
        screensInfo: '20 Cinemas • Regal Pointe IMAX',
        details: '20 Cinemas available (Regal Pointe Orlando IMAX, AMC Disney Springs)',
        icon: Icons.attractions_rounded,
        badge: 'IMAX',
      ),
    ],

    // Washington / WA
    'Washington': [
      _CityData(
        id: 116,
        name: 'Seattle',
        screensInfo: '22 Cinemas • Pacific Science IMAX',
        details: '22 Cinemas available (Boeing IMAX Pacific Science Center, SIFF Cinema)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'IMAX LASER',
      ),
    ],

    // Maharashtra
    'Maharashtra': [
      _CityData(
        id: 2,
        name: 'Mumbai',
        screensInfo: '48 Cinemas • IMAX Laser',
        details: '48 Cinemas available (PVR INOX, Cinepolis, Maison IMAX)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'IMAX LASER',
      ),
      _CityData(
        id: 201,
        name: 'Pune',
        screensInfo: '32 Cinemas • Dolby Atmos & 4DX',
        details: '32 Cinemas available (PVR, Cinepolis, INOX Westend)',
        icon: Icons.account_balance_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 202,
        name: 'Nagpur',
        screensInfo: '16 Cinemas • 4DX Active',
        details: '16 Cinemas available (Cinemax, MovieMax, INOX)',
        icon: Icons.local_activity_rounded,
        badge: '4DX',
      ),
      _CityData(
        id: 203,
        name: 'Thane',
        screensInfo: '19 Cinemas • Viviana IMAX',
        details: '19 Cinemas available (Viviana IMAX, Cinepolis, Carnival)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 204,
        name: 'Navi Mumbai',
        screensInfo: '21 Cinemas • Inorbit INOX',
        details: '21 Cinemas available (Inorbit INOX, Seawoods Cinepolis)',
        icon: Icons.corporate_fare_rounded,
      ),
      _CityData(
        id: 205,
        name: 'Nashik',
        screensInfo: '11 Cinemas • City Pride',
        details: '11 Cinemas available (PVR, Cinemax, City Pride)',
        icon: Icons.movie_rounded,
      ),
      _CityData(
        id: 206,
        name: 'Aurangabad',
        screensInfo: '8 Multiplexes • Prozone INOX',
        details: '8 Cinemas available (Prozone INOX, Mukta A2)',
        icon: Icons.attractions_rounded,
      ),
    ],

    // Karnataka
    'Karnataka': [
      _CityData(
        id: 4,
        name: 'Bengaluru',
        screensInfo: '56 Cinemas • IMAX Laser & 4DX',
        details: '56 Cinemas available (PVR Forum, Vega City IMAX, Cinepolis)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'IMAX LASER',
      ),
      _CityData(
        id: 207,
        name: 'Mysuru',
        screensInfo: '12 Cinemas • DRC Cinemas',
        details: '12 Cinemas available (DRC Cinemas, INOX Garuda)',
        icon: Icons.account_balance_rounded,
        badge: 'DOLBY',
      ),
      _CityData(
        id: 208,
        name: 'Mangaluru',
        screensInfo: '8 Cinemas • Forum Fiza',
        details: '8 Cinemas available (PVR Forum Fiza, Cinepolis)',
        icon: Icons.theaters_rounded,
      ),
    ],

    // Delhi NCR
    'Delhi NCR': [
      _CityData(
        id: 6,
        name: 'New Delhi',
        screensInfo: "52 Cinemas • PVR Director's Cut",
        details: "52 Cinemas available (PVR Plaza, Vegas IMAX, Delite)",
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'DIRECTOR CUT',
      ),
      _CityData(
        id: 209,
        name: 'Gurugram',
        screensInfo: '28 Cinemas • 4DX & Atmos',
        details: '28 Cinemas available (Ambience PVR, MGF Cinepolis)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 210,
        name: 'Noida',
        screensInfo: '22 Cinemas • Logix Superplex',
        details: '22 Cinemas available (PVR Superplex Logix, Wave Cinemas)',
        icon: Icons.corporate_fare_rounded,
        badge: 'IMAX',
      ),
    ],

    // Tamil Nadu
    'Tamil Nadu': [
      _CityData(
        id: 7,
        name: 'Chennai',
        screensInfo: '44 Cinemas • Palazzo & Luxe IMAX',
        details: '44 Cinemas available (SPI Palazzo, Luxe Phoenix, PVR VR)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'DOLBY ATMOS',
      ),
      _CityData(
        id: 211,
        name: 'Coimbatore',
        screensInfo: '18 Cinemas • Broadway IMAX',
        details: '18 Cinemas available (Broadway Cinemas, Inox Prozone)',
        icon: Icons.theaters_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 212,
        name: 'Madurai',
        screensInfo: '12 Cinemas • INOX Vishaal',
        details: '12 Cinemas available (INOX Vishaal de Mal, Jazz Cinemas)',
        icon: Icons.movie_rounded,
      ),
    ],

    // Telangana
    'Telangana': [
      _CityData(
        id: 8,
        name: 'Hyderabad',
        screensInfo: '36 Cinemas • Prasads Large Screen',
        details: '36 Cinemas available (Prasads Multiplex, AMB Cinemas, PVR Irrum)',
        icon: Icons.connected_tv_rounded,
        hasLaser: true,
        badge: 'LARGE SCREEN',
      ),
      _CityData(
        id: 213,
        name: 'Warangal',
        screensInfo: '8 Cinemas • Asian Sridevi',
        details: '8 Cinemas available (Asian Mukund, Radhika Multiplex)',
        icon: Icons.theaters_rounded,
      ),
    ],

    // United Kingdom
    'Greater London': [
      _CityData(
        id: 3,
        name: 'Central London',
        screensInfo: '42 Cinemas • BFI IMAX & Odeon Luxe',
        details: '42 Cinemas available (BFI IMAX, Odeon Luxe Leicester Square)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
        badge: 'BFI 70MM',
      ),
      _CityData(
        id: 301,
        name: 'West End',
        screensInfo: '26 Cinemas • Curzon Mayfair',
        details: '26 Cinemas available (Curzon Mayfair, Picturehouse Central)',
        icon: Icons.movie_filter_rounded,
        badge: 'VIP LUXE',
      ),
      _CityData(
        id: 302,
        name: 'Greenwich',
        screensInfo: '18 Cinemas • Odeon IMAX & O2',
        details: '18 Cinemas available (Odeon IMAX Greenwich, Cineworld O2)',
        icon: Icons.theaters_rounded,
        badge: 'IMAX',
      ),
    ],

    // UAE
    'Dubai': [
      _CityData(
        id: 11,
        name: 'Dubai Downtown',
        screensInfo: '28 Cinemas • VOX Mall of Emirates',
        details: '28 Cinemas available (VOX Mall of Emirates, Reel Dubai Mall)',
        icon: Icons.attractions_rounded,
        hasLaser: true,
        badge: 'VOX LASER',
      ),
      _CityData(
        id: 303,
        name: 'Dubai Marina',
        screensInfo: '14 Cinemas • Reel Marina Mall',
        details: '14 Cinemas available (Reel Cinemas Marina Mall, Roxy Cinemas JBR)',
        icon: Icons.apartment_rounded,
        badge: 'DOLBY',
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _initializeLocationFromInput();

    _countrySearchController.addListener(() {
      setState(() => _countrySearchQuery = _countrySearchController.text.trim().toLowerCase());
    });
    _stateSearchController.addListener(() {
      setState(() => _stateSearchQuery = _stateSearchController.text.trim().toLowerCase());
    });
    _citySearchController.addListener(() {
      setState(() => _citySearchQuery = _citySearchController.text.trim().toLowerCase());
    });
  }

  void _initializeLocationFromInput() {
    if (widget.currentCity != null) {
      final rawCountry = widget.currentCity!.country.trim();
      final normCountry = _normalizeCountry(rawCountry);
      _selectedCountry = normCountry;

      final matchCountry = _countries.firstWhere(
        (c) => c.name.toLowerCase() == _selectedCountry.toLowerCase(),
        orElse: () => _countries.first,
      );
      _selectedCountryFlag = matchCountry.flag;

      final rawState = widget.currentCity!.state.trim();
      final normState = _normalizeState(rawState, _selectedCountry);
      _selectedState = normState;

      final rawCity = widget.currentCity!.name.trim();
      _selectedCityId = widget.currentCity!.id;

      final availableList = _getCitiesForState(_selectedState);
      final found = availableList.firstWhere(
        (c) => c.name.toLowerCase() == rawCity.toLowerCase() ||
               c.name.toLowerCase().contains(rawCity.toLowerCase()) ||
               rawCity.toLowerCase().contains(c.name.toLowerCase()),
        orElse: () => availableList.isNotEmpty
            ? availableList.first
            : _CityData(
                id: _selectedCityId,
                name: rawCity.isNotEmpty ? rawCity : 'Premier Hub',
                screensInfo: 'Cinemas & multiplexes active',
                details: 'Showing cinema chains and showtimes in $_selectedState',
                icon: Icons.apartment_rounded,
              ),
      );

      _selectedCity = found.name;
      _cityDetails = found.details;
    }
  }

  String _normalizeCountry(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'usa' || lower == 'us' || lower == 'united states of america' || lower.contains('united states')) {
      return 'United States';
    }
    if (lower == 'uk' || lower == 'gb' || lower == 'great britain' || lower.contains('united kingdom')) {
      return 'United Kingdom';
    }
    if (lower == 'uae' || lower.contains('emirates')) {
      return 'United Arab Emirates';
    }
    if (lower == 'in' || lower == 'ind' || lower.contains('india')) {
      return 'India';
    }
    if (lower.contains('singapore')) return 'Singapore';
    if (lower.contains('canada')) return 'Canada';
    if (lower.contains('australia')) return 'Australia';
    if (lower.contains('germany')) return 'Germany';

    return 'United States';
  }

  String _normalizeState(String raw, String country) {
    final lower = raw.trim().toLowerCase();

    // US State Abbreviations
    if (lower == 'ny' || lower == 'new york') return 'New York';
    if (lower == 'ca' || lower == 'california') return 'California';
    if (lower == 'tx' || lower == 'texas') return 'Texas';
    if (lower == 'il' || lower == 'illinois') return 'Illinois';
    if (lower == 'fl' || lower == 'florida') return 'Florida';
    if (lower == 'wa' || lower == 'washington') return 'Washington';

    // India State Abbreviations
    if (lower == 'mh' || lower.contains('maharashtra')) return 'Maharashtra';
    if (lower == 'ka' || lower.contains('karnataka')) return 'Karnataka';
    if (lower == 'dl' || lower.contains('delhi')) return 'Delhi NCR';
    if (lower == 'tn' || lower.contains('tamil')) return 'Tamil Nadu';
    if (lower == 'ts' || lower == 'tg' || lower.contains('telangana')) return 'Telangana';
    if (lower == 'gj' || lower.contains('gujarat')) return 'Gujarat';
    if (lower == 'wb' || lower.contains('bengal')) return 'West Bengal';
    if (lower == 'kl' || lower.contains('kerala')) return 'Kerala';

    // UK
    if (lower.contains('london')) return 'Greater London';

    // Fallback to first available state for that country
    final states = _statesByCountry[country];
    if (states != null && states.isNotEmpty) {
      return states.first.name;
    }
    return raw.isNotEmpty ? raw : 'New York';
  }

  List<_CityData> _getCitiesForState(String stateName) {
    if (_citiesByState.containsKey(stateName)) {
      return _citiesByState[stateName]!;
    }
    final norm = _normalizeState(stateName, _selectedCountry);
    if (_citiesByState.containsKey(norm)) {
      return _citiesByState[norm]!;
    }
    for (final entry in _citiesByState.entries) {
      if (entry.key.toLowerCase() == stateName.toLowerCase() ||
          entry.key.toLowerCase().contains(stateName.toLowerCase())) {
        return entry.value;
      }
    }
    if (_selectedCountry == 'India') {
      return _citiesByState['Maharashtra'] ?? [];
    }
    return _citiesByState['New York'] ?? [];
  }

  @override
  void dispose() {
    _countrySearchController.dispose();
    _stateSearchController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  // Navigation with directional slide tracking
  void _goToStep(int step) {
    if (step == _currentStep) return;
    setState(() {
      _slideDirection = step > _currentStep ? 1 : -1;
      _currentStep = step.clamp(1, 4);
    });
  }

  void _selectCountry(String name, String flag) {
    setState(() {
      _selectedCountry = name;
      _selectedCountryFlag = flag;
      final availableStates = _statesByCountry[name];
      if (availableStates != null && availableStates.isNotEmpty) {
        _selectedState = availableStates.first.name;
      } else {
        _selectedState = 'Capital Region';
      }
      _updateCityForCurrentState();
      // Move forward to State with move-left animation
      _slideDirection = 1;
      _currentStep = 2;
    });
  }

  void _selectState(String stateName) {
    setState(() {
      _selectedState = stateName;
      _updateCityForCurrentState();
      // Move forward to City/District with move-left animation
      _slideDirection = 1;
      _currentStep = 3;
    });
  }

  void _updateCityForCurrentState() {
    final availableCities = _getCitiesForState(_selectedState);
    if (availableCities.isNotEmpty) {
      _selectedCity = availableCities.first.name;
      _selectedCityId = availableCities.first.id;
      _cityDetails = availableCities.first.details;
    } else {
      _selectedCity = 'Central $_selectedState';
      _selectedCityId = 100;
      _cityDetails = 'Cinemas and partner multiplexes active in $_selectedState';
    }
  }

  void _selectCity(String cityName, int id, String details) {
    setState(() {
      _selectedCity = cityName;
      _selectedCityId = id;
      _cityDetails = details;
      // Move forward to Final Confirmation with move-left animation!
      _slideDirection = 1;
      _currentStep = 4;
    });
  }

  void _triggerGpsDetection() {
    setState(() {
      _isGpsLocating = true;
      _gpsButtonText = 'Scanning cinema radars...';
    });

    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _isGpsLocating = false;
        _gpsButtonText = 'Nearest IMAX Found!';
        if (_selectedCountry == 'India') {
          _selectedCountry = 'India';
          _selectedCountryFlag = '🇮🇳';
          _selectedState = 'Maharashtra';
          _selectedCity = 'Mumbai';
          _selectedCityId = 2;
          _cityDetails = 'Detected via GPS • 48 Cinemas within 10 km (IMAX Laser & 4DX)';
        } else {
          _selectedCountry = 'United States';
          _selectedCountryFlag = '🇺🇸';
          _selectedState = 'New York';
          _selectedCity = 'New York City';
          _selectedCityId = 1;
          _cityDetails = 'Detected via GPS • 48 Cinemas within 10 km (AMC Lincoln Square 70mm)';
        }
        // Jump directly to Final Confirmation ticket
        _slideDirection = 1;
        _currentStep = 4;
      });
    });
  }

  void _confirmAndReturn() {
    setState(() {
      _isConfirming = true;
      _confirmButtonText = 'Booking Session Ready...';
    });

    final chosenCity = City(
      id: _selectedCityId,
      name: _selectedCity,
      state: _selectedState,
      country: _selectedCountry,
    );

    Timer(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      widget.onLocationConfirmed?.call(chosenCity);
      Navigator.of(context).maybePop(chosenCity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDarkMode = currentMode == ThemeMode.dark;

        return Scaffold(
          backgroundColor: kBackground,
          appBar: _buildTopBar(),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Stack(
                    children: [
                      // Ambient Glow Orbs (Subtle in light, radiant in dark)
                      Positioned(
                        top: -40,
                        left: 200,
                        child: Container(
                          width: 380,
                          height: 180,
                          decoration: BoxDecoration(
                            color: kPrimaryVivid.withValues(alpha: isDarkMode ? 0.14 : 0.06),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 240,
                        right: 40,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            color: kGold.withValues(alpha: isDarkMode ? 0.08 : 0.04),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      // Main Content Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Header Section with Brand Cue & Stepper
                          _buildHeaderSection(),

                          const SizedBox(height: 24),

                          // 2. Main Sequential Panel with Move-Left Slide Transitions
                          _buildMainPanelWithTransitions(),

                          const SizedBox(height: 24),

                          // 3. Partner Guarantee Bar
                          _buildPartnerGuaranteeBar(),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- APP BAR ---

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: kSurfaceLow.withValues(alpha: 0.95),
      elevation: isDark ? 0 : 1,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kSurfaceHigh),
          ),
          child: Icon(Icons.arrow_back_rounded, color: kTextWhite, size: 18),
        ),
        onPressed: () {
          if (_currentStep > 1) {
            _goToStep(_currentStep - 1);
          } else {
            Navigator.of(context).maybePop();
          }
        },
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/cineza_logo_transparent.png',
              height: 26,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.confirmation_number_rounded,
                color: kPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Region Discovery',
              style: _argentHeading(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextWhite,
              ),
            ),
          ],
        ),
      ),
      actions: [
        CinezaThemeToggle(compact: MediaQuery.of(context).size.width < 650),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _confirmAndReturn,
          icon: Icon(Icons.check_rounded, color: kPrimary, size: 18),
          label: Text(
            'Apply',
            style: _proximaBody(
              color: kPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kSurfaceHigh, height: 1),
      ),
    );
  }

  // --- HEADER SECTION & STEPPER ---

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Cineza Brand Cue Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: kSurfaceLow.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kSurfaceHigh),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.confirmation_number_rounded, color: kSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'CINEZA',
                style: _argentHeading(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(width: 6),
              Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.5))),
              const SizedBox(width: 6),
              Icon(Icons.my_location_rounded, color: kPrimary, size: 14),
              const SizedBox(width: 4),
              Text(
                'REGION DISCOVERY',
                style: _argentHeading(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Headline
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: _argentHeading(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: kTextWhite,
              letterSpacing: -0.5,
              height: 1.25,
            ),
            children: [
              const TextSpan(text: 'Where are you catching '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF18A0FB), Color(0xFF0062FF), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'movies today?',
                    style: _argentHeading(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            'Choose your country, state, and city to discover nearby auditoriums, IMAX Laser experiences, and exclusive premieres.',
            textAlign: TextAlign.center,
            style: _proximaBody(
              fontSize: 13.5,
              color: kTextMuted,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Interactive Stepper
        _buildStepperBar(),
      ],
    );
  }

  Widget _buildStepperBar() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base Background Track Line
          Positioned(
            left: 45,
            right: 45,
            top: 18,
            child: Container(
              height: 2,
              color: kSurfaceHighest,
            ),
          ),

          // Dynamic Active Progress Line
          Positioned(
            left: 45,
            right: 45,
            top: 18,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double progress = _currentStep >= 4
                    ? 1.0
                    : ((_currentStep - 1) / 2.0).clamp(0.0, 1.0);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      color: kPrimaryVivid,
                      boxShadow: [
                        BoxShadow(
                          color: kPrimaryVivid.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3 Step Nodes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepNode(stepNumber: 1, title: '1. Country'),
              _buildStepNode(stepNumber: 2, title: '2. State'),
              _buildStepNode(stepNumber: 3, title: '3. City / District'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({required int stepNumber, required String title}) {
    final bool isPassed = stepNumber < _currentStep || _currentStep == 4;
    final bool isActive = stepNumber == _currentStep;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Allow clicking previous steps to smoothly slide back
          if (stepNumber < _currentStep || _currentStep == 4) {
            _goToStep(stepNumber);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPassed
                      ? kPrimaryVivid
                      : isActive
                          ? kPrimaryVivid
                          : kSurfaceHighest,
                  border: Border.all(
                    color: isActive ? kPrimaryVivid : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: kPrimaryVivid.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isPassed
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : Text(
                          '$stepNumber',
                          style: _argentHeading(
                            fontWeight: FontWeight.bold,
                            color: (isActive || isPassed) ? Colors.white : kTextMuted,
                            fontSize: 13,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: _argentHeading(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? kSecondary
                      : isPassed
                          ? kTextWhite
                          : kTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MAIN PANEL WITH MOVE-LEFT SLIDE TRANSITIONS ---

  Widget _buildMainPanelWithTransitions() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final offsetTween = Tween<Offset>(
          begin: Offset(_slideDirection * 0.35, 0.0),
          end: Offset.zero,
        );
        return SlideTransition(
          position: offsetTween.animate(animation),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      child: _buildCurrentStageView(),
    );
  }

  Widget _buildCurrentStageView() {
    switch (_currentStep) {
      case 1:
        return _buildPanelContainer(
          key: const ValueKey('stage-1-country'),
          child: _buildCountryStage(),
        );
      case 2:
        return _buildPanelContainer(
          key: const ValueKey('stage-2-state'),
          child: _buildStateStage(),
        );
      case 3:
        return _buildPanelContainer(
          key: const ValueKey('stage-3-city'),
          child: _buildCityStage(),
        );
      case 4:
      default:
        return _buildConfirmationStage(
          key: const ValueKey('stage-4-confirm'),
        );
    }
  }

  Widget _buildPanelContainer({required Key key, required Widget child}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: kSurfaceLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  // --- STAGE 1: COUNTRY SELECTOR ---

  Widget _buildCountryStage() {
    final filtered = _countrySearchQuery.isEmpty
        ? _countries
        : _countries.where((c) => c.name.toLowerCase().contains(_countrySearchQuery)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.public_rounded,
          title: 'Select Target Country',
          subtitle: 'We support regional film ratings, currency standards, and language preferences.',
          searchController: _countrySearchController,
          hint: 'Search country...',
          extraAction: ElevatedButton.icon(
            onPressed: _isGpsLocating ? null : _triggerGpsDetection,
            icon: _isGpsLocating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.near_me_rounded, size: 16, color: kSecondary),
            label: Text(
              _gpsButtonText,
              style: _argentHeading(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kSurfaceHighest,
              foregroundColor: kTextWhite,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: kSurfaceHigh),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 520
                    ? 3
                    : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.1,
              ),
              itemBuilder: (context, index) {
                final country = filtered[index];
                final isSelected = country.name.toLowerCase() == _selectedCountry.toLowerCase();

                return InkWell(
                  onTap: () => _selectCountry(country.name, country.flag),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kSurfaceHigh : kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSecondary : kSurfaceHigh,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(country.flag, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                country.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _argentHeading(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kTextWhite,
                                ),
                              ),
                              Text(
                                country.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _proximaBody(
                                  fontSize: 10.5,
                                  color: isSelected ? kSecondary : kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: kSecondary, size: 18)
                        else
                          Icon(Icons.radio_button_unchecked_rounded, color: kTextMuted, size: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- STAGE 2: STATE SELECTOR ---

  Widget _buildStateStage() {
    final stateList = _statesByCountry[_selectedCountry] ?? [];
    final filtered = _stateSearchQuery.isEmpty
        ? stateList
        : stateList.where((s) => s.name.toLowerCase().contains(_stateSearchQuery)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.map_rounded,
          title: 'Select State / Region',
          subtitle: 'Active film distribution zones and auditoriums in $_selectedCountryFlag $_selectedCountry.',
          searchController: _stateSearchController,
          hint: 'Search state or province...',
          extraAction: TextButton.icon(
            onPressed: () => _goToStep(1),
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: Text(
              'Change Country',
              style: _proximaBody(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: kSecondary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 520
                    ? 3
                    : 2;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemBuilder: (context, index) {
                final stateData = filtered[index];
                final isSelected = stateData.name.toLowerCase() == _selectedState.toLowerCase();

                return InkWell(
                  onTap: () => _selectState(stateData.name),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kSurfaceHigh : kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? kSecondary : kSurfaceHigh,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stateData.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _argentHeading(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: kTextWhite,
                            ),
                          ),
                        ),
                        Text(
                          stateData.screens,
                          style: _proximaBody(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kSecondary : kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // --- STAGE 3: CITY / DISTRICT SELECTOR (BENTO GRID WITH FORMAT FILTERS) ---

  Widget _buildCityStage() {
    final rawList = _getCitiesForState(_selectedState);

    // Apply format filter
    List<_CityData> formatFiltered = rawList;
    if (_selectedFormatFilter == 'IMAX Laser') {
      formatFiltered = rawList.where((c) => c.hasLaser || (c.badge?.contains('IMAX') ?? false) || c.screensInfo.toLowerCase().contains('imax')).toList();
    } else if (_selectedFormatFilter == 'Dolby Atmos') {
      formatFiltered = rawList.where((c) => c.screensInfo.toLowerCase().contains('dolby') || c.screensInfo.toLowerCase().contains('atmos') || (c.badge?.contains('DOLBY') ?? false)).toList();
    } else if (_selectedFormatFilter == '4DX') {
      formatFiltered = rawList.where((c) => c.screensInfo.toLowerCase().contains('4dx') || (c.badge?.contains('4DX') ?? false)).toList();
    } else if (_selectedFormatFilter == 'VIP') {
      formatFiltered = rawList.where((c) => c.screensInfo.toLowerCase().contains('director') || c.screensInfo.toLowerCase().contains('luxe') || (c.badge?.contains('VIP') ?? false)).toList();
    }

    // Apply search query
    final filtered = _citySearchQuery.isEmpty
        ? formatFiltered
        : formatFiltered.where((c) => c.name.toLowerCase().contains(_citySearchQuery)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.location_city_rounded,
          title: 'Select Your City / District',
          subtitle: 'Listing cinemas and multiplex chains across $_selectedState.',
          searchController: _citySearchController,
          hint: 'Search city or town...',
          extraAction: TextButton.icon(
            onPressed: () => _goToStep(2),
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: Text(
              'Change State',
              style: _proximaBody(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              foregroundColor: kSecondary,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Cinema Experience Format Filter Chips
        _buildCinemaFormatFilterRow(),

        const SizedBox(height: 16),

        if (filtered.isEmpty) ...[
          _buildEmptyCityState(),
        ] else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 520
                      ? 3
                      : 2;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  final city = filtered[index];
                  final isSelected = city.name.toLowerCase() == _selectedCity.toLowerCase();

                  return InkWell(
                    onTap: () => _selectCity(city.name, city.id, city.details),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? kSurfaceHigh : kSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? kSecondary.withValues(alpha: 0.8) : kSurfaceHigh,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: kPrimaryVivid.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? kPrimaryVivid.withValues(alpha: 0.2)
                                            : kSurfaceHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        city.icon,
                                        size: 18,
                                        color: isSelected ? kSecondary : kTextMuted,
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: kSecondary,
                                        size: 18,
                                      )
                                    else if (city.badge != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kSurfaceHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          city.badge!,
                                          style: _proximaBody(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: kGold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _argentHeading(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: kTextWhite,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      city.screensInfo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _proximaBody(
                                        fontSize: 10.5,
                                        color: isSelected ? kSecondary : kTextMuted,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Active Bottom Accent Bar
                          if (isSelected)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kPrimaryVivid,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCinemaFormatFilterRow() {
    final filters = ['All', 'IMAX Laser', 'Dolby Atmos', '4DX', 'VIP'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFormatFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedFormatFilter = f),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? kPrimaryVivid.withValues(alpha: 0.2)
                      : kSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? kPrimaryVivid : kSurfaceHigh,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (f == 'IMAX Laser') ...[
                      Icon(Icons.movie_creation_rounded, size: 12, color: isSelected ? kPrimaryVivid : kGold),
                      const SizedBox(width: 4),
                    ],
                    if (f == 'Dolby Atmos') ...[
                      Icon(Icons.speaker_rounded, size: 12, color: isSelected ? kPrimaryVivid : kTextMuted),
                      const SizedBox(width: 4),
                    ],
                    if (f == '4DX') ...[
                      Icon(Icons.local_activity_rounded, size: 12, color: isSelected ? kPrimaryVivid : kTextMuted),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      f,
                      style: _proximaBody(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? kPrimaryVivid : kTextWhite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCityState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceHigh),
      ),
      child: Column(
        children: [
          Icon(Icons.theaters_outlined, color: kGold, size: 36),
          const SizedBox(height: 10),
          Text(
            'No cities matching "$_citySearchQuery" in $_selectedState',
            style: _proximaBody(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try resetting the format filter or select from popular movie destinations below:',
            style: _proximaBody(fontSize: 12, color: kTextMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Reset Format Filters'),
                backgroundColor: kSurfaceHighest,
                labelStyle: _proximaBody(fontSize: 11, color: kTextWhite),
                onPressed: () {
                  setState(() {
                    _selectedFormatFilter = 'All';
                    _citySearchController.clear();
                  });
                },
              ),
              ActionChip(
                label: const Text('🎬 Switch to New York'),
                backgroundColor: kPrimaryVivid.withValues(alpha: 0.2),
                labelStyle: _proximaBody(fontSize: 11, color: kSecondary),
                onPressed: () {
                  _selectCountry('United States', '🇺🇸');
                  _selectState('New York');
                },
              ),
              ActionChip(
                label: const Text('🎬 Switch to Mumbai'),
                backgroundColor: kPrimaryVivid.withValues(alpha: 0.2),
                labelStyle: _proximaBody(fontSize: 11, color: kSecondary),
                onPressed: () {
                  _selectCountry('India', '🇮🇳');
                  _selectState('Maharashtra');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STAGE 4: FINAL LOCATION CONFIRMATION (SHOWN ONLY AFTER CITY IS SELECTED) ---

  Widget _buildConfirmationStage({required Key key}) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: kSurfaceLow.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verified Status Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'LOCATION READY FOR SHOWTIMES',
                    style: _argentHeading(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "You're all set to catch movies in $_selectedCity!",
            textAlign: TextAlign.center,
            style: _argentHeading(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: kTextWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Auditoriums, IMAX Laser screens, and seat reservations are ready to load.',
            textAlign: TextAlign.center,
            style: _proximaBody(
              fontSize: 13,
              color: kTextMuted,
            ),
          ),

          const SizedBox(height: 24),

          // The Exact Tactile Perforated Cinema Ticket Card (Image 3)
          _buildTactileTicketFooter(),

          const SizedBox(height: 18),

          // Quick Edit / Change Location buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _goToStep(1),
                icon: Icon(Icons.public_rounded, size: 14, color: kTextMuted),
                label: Text(
                  'Change Country ($_selectedCountry)',
                  style: _proximaBody(fontSize: 11.5, color: kTextMuted),
                ),
              ),
              TextButton.icon(
                onPressed: () => _goToStep(2),
                icon: Icon(Icons.map_rounded, size: 14, color: kTextMuted),
                label: Text(
                  'Change State ($_selectedState)',
                  style: _proximaBody(fontSize: 11.5, color: kTextMuted),
                ),
              ),
              TextButton.icon(
                onPressed: () => _goToStep(3),
                icon: Icon(Icons.location_city_rounded, size: 14, color: kSecondary),
                label: Text(
                  'Change City ($_selectedCity)',
                  style: _proximaBody(fontSize: 11.5, color: kSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController searchController,
    required String hint,
    Widget? extraAction,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kSecondary, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _argentHeading(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextWhite,
                  ),
                ),
                Text(
                  subtitle,
                  style: _proximaBody(
                    fontSize: 11.5,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (extraAction != null) ...[
              extraAction,
              const SizedBox(width: 10),
            ],

            // Search Input with Clear Button
            Container(
              width: 200,
              height: 38,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kSurfaceHigh),
              ),
              child: TextField(
                controller: searchController,
                style: _proximaBody(fontSize: 12, color: kTextWhite),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: _proximaBody(fontSize: 12, color: kTextMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: kTextMuted),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, size: 14, color: kTextMuted),
                          onPressed: () => searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TACTILE PERFORATED CINEMA TICKET FOOTER (IMAGE 3) ---

  Widget _buildTactileTicketFooter() {
    return ClipPath(
      clipper: _TicketNotchClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kSurfaceHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 14,
          children: [
            // Left Ticket Details
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kPrimaryVivid.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimaryVivid.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.verified_rounded, color: kSecondary, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONFIRMED SELECTION',
                      style: _argentHeading(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_selectedCity, $_selectedState ($_selectedCountry)',
                      style: _argentHeading(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _cityDetails,
                          style: _proximaBody(
                            fontSize: 11.5,
                            color: kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Action Button
            ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmAndReturn,
                  icon: _isConfirming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    _confirmButtonText,
                    style: _argentHeading(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryVivid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    shadowColor: kPrimaryVivid.withValues(alpha: 0.5),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // --- CINEMA PARTNER GUARANTEES FOOTER ---

  Widget _buildPartnerGuaranteeBar() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildGuaranteeItem(
          icon: Icons.verified_user_rounded,
          text: 'Official Partner of PVR-INOX, AMC, Regal & Cinepolis',
          color: kGold,
        ),
        Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.4))),
        _buildGuaranteeItem(
          icon: Icons.pin_drop_rounded,
          text: 'Real-time Seat Matrices & Pricing',
          color: kSecondary,
        ),
        Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.4))),
        _buildGuaranteeItem(
          icon: Icons.local_movies_rounded,
          text: 'Subtitles & Audio Track Format Filtering',
          color: kGold,
        ),
      ],
    );
  }

  Widget _buildGuaranteeItem({required IconData icon, required String text, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: _proximaBody(
            fontSize: 11,
            color: kTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- DATA TRANSFER MODELS ---

class _CountryData {
  final String name;
  final String flag;
  final String subtitle;
  final String screenCount;

  _CountryData({
    required this.name,
    required this.flag,
    required this.subtitle,
    required this.screenCount,
  });
}

class _StateData {
  final String name;
  final String screens;

  _StateData({required this.name, required this.screens});
}

class _CityData {
  final int id;
  final String name;
  final String screensInfo;
  final String details;
  final IconData icon;
  final String? badge;
  final bool hasLaser;

  _CityData({
    required this.id,
    required this.name,
    required this.screensInfo,
    required this.details,
    required this.icon,
    this.badge,
    this.hasLaser = false,
  });
}

/// Custom clipper that punches semi-circle notches into the left and right edges
/// giving the authentic perforated cinema ticket shape.
class _TicketNotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notchRadius = 10.0;
    final path = Path();

    // Top edge
    path.lineTo(size.width, 0);

    // Right edge with center notch
    path.lineTo(size.width, size.height / 2 - notchRadius);
    path.arcToPoint(
      Offset(size.width, size.height / 2 + notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, size.height);

    // Bottom edge
    path.lineTo(0, size.height);

    // Left edge with center notch
    path.lineTo(0, size.height / 2 + notchRadius);
    path.arcToPoint(
      Offset(0, size.height / 2 - notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
