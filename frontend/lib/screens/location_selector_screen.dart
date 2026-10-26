import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/city.dart';

/// Region Discovery & Multi-Stage Location Selector Screen
/// Implements 3-step cascade: Country -> State -> City with GPS auto-detection,
/// tactile cinema ticket footer, and Royal Cinema Blue theme.
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
  // Stepper Stage (1: Country, 2: State, 3: City)
  int _currentStep = 3;

  // Selected State
  String _selectedCountry = 'India';
  String _selectedCountryFlag = '🇮🇳';
  String _selectedState = 'Maharashtra';
  String _selectedCity = 'Mumbai';
  String _cityDetails = '48 Cinemas available (PVR INOX, Cinepolis, IMAX Laser)';
  int _selectedCityId = 1;

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

  // Saving animation state
  bool _isConfirming = false;
  String _confirmButtonText = 'Confirm & Start Booking';

  // Royal Cinema Blue Palette tokens (matching Cineza theme)
  static const Color kBackground = Color(0xFF090A0F);
  static const Color kSurfaceLow = Color(0xFF141722);
  static const Color kSurface = Color(0xFF1E2336);
  static const Color kSurfaceHigh = Color(0xFF262B40);
  static const Color kSurfaceHighest = Color(0xFF333A56);
  static const Color kPrimary = Color(0xFF60A5FA); // Sky Blue Accent
  static const Color kPrimaryVivid = Color(0xFF0062FF); // Vivid Royal Cinema Blue
  static const Color kSecondary = Color(0xFF38BDF8); // Electric Cyan
  static const Color kGold = Color(0xFFFFB800); // Cineza Gold
  static const Color kTextWhite = Color(0xFFF8FAFC);
  static const Color kTextMuted = Color(0xFF94A3B8);

  // --- DATA SOURCES ---

  final List<_CountryData> _countries = [
    _CountryData(name: 'India', flag: '🇮🇳', subtitle: '840+ Theatres', screenCount: '840+ Theatres'),
    _CountryData(name: 'United States', flag: '🇺🇸', subtitle: 'AMC, Regal & Cinemark', screenCount: '1200+ Theatres'),
    _CountryData(name: 'United Kingdom', flag: '🇬🇧', subtitle: 'Odeon, Vue, Curzon', screenCount: '410+ Theatres'),
    _CountryData(name: 'United Arab Emirates', flag: '🇦🇪', subtitle: 'VOX, Reel Cinemas', screenCount: '190+ Theatres'),
    _CountryData(name: 'Singapore', flag: '🇸🇬', subtitle: 'Shaw Theatres, GV', screenCount: '85+ Theatres'),
    _CountryData(name: 'Canada', flag: '🇨🇦', subtitle: 'Cineplex, Landmark', screenCount: '320+ Theatres'),
    _CountryData(name: 'Australia', flag: '🇦🇺', subtitle: 'Event, Hoyts, Village', screenCount: '280+ Theatres'),
    _CountryData(name: 'Germany', flag: '🇩🇪', subtitle: 'CinemaxX, UCI', screenCount: '350+ Theatres'),
  ];

  final Map<String, List<_StateData>> _statesByCountry = {
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
    'United States': [
      _StateData(name: 'California', screens: '185 Screens'),
      _StateData(name: 'New York', screens: '142 Screens'),
      _StateData(name: 'Texas', screens: '160 Screens'),
      _StateData(name: 'Florida', screens: '98 Screens'),
      _StateData(name: 'Illinois', screens: '82 Screens'),
      _StateData(name: 'Washington', screens: '64 Screens'),
    ],
    'United Kingdom': [
      _StateData(name: 'Greater London', screens: '120 Screens'),
      _StateData(name: 'West Midlands', screens: '45 Screens'),
      _StateData(name: 'Greater Manchester', screens: '38 Screens'),
      _StateData(name: 'Scotland', screens: '50 Screens'),
    ],
  };

  final Map<String, List<_CityData>> _citiesByState = {
    'Maharashtra': [
      _CityData(
        id: 1,
        name: 'Mumbai',
        screensInfo: '48 Cinemas • IMAX Laser',
        details: '48 Cinemas available (PVR INOX, Cinepolis, IMAX Laser)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
      ),
      _CityData(
        id: 2,
        name: 'Pune',
        screensInfo: '32 Cinemas • Dolby Atmos',
        details: '32 Cinemas available (PVR, Cinepolis, INOX Westend)',
        icon: Icons.account_balance_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 3,
        name: 'Nagpur',
        screensInfo: '16 Cinemas • 4DX Active',
        details: '16 Cinemas available (Cinemax, MovieMax, INOX)',
        icon: Icons.local_activity_rounded,
      ),
      _CityData(
        id: 4,
        name: 'Nashik',
        screensInfo: '11 Cinemas',
        details: '11 Cinemas available (PVR, Cinemax, City Pride)',
        icon: Icons.movie_rounded,
      ),
      _CityData(
        id: 5,
        name: 'Thane',
        screensInfo: '19 Cinemas • 4DX',
        details: '19 Cinemas available (Viviana IMAX, Cinepolis, Carnival)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 6,
        name: 'Navi Mumbai',
        screensInfo: '21 Cinemas',
        details: '21 Cinemas available (Inorbit INOX, Seawoods Cinepolis)',
        icon: Icons.corporate_fare_rounded,
      ),
      _CityData(
        id: 7,
        name: 'Aurangabad',
        screensInfo: '8 Multiplexes',
        details: '8 Cinemas available (Prozone INOX, Mukta A2)',
        icon: Icons.attractions_rounded,
      ),
      _CityData(
        id: 8,
        name: 'Kolhapur',
        screensInfo: '7 Multiplexes',
        details: '7 Cinemas available (INOX DYP City, Padma)',
        icon: Icons.theaters_rounded,
      ),
    ],
    'Karnataka': [
      _CityData(
        id: 9,
        name: 'Bengaluru',
        screensInfo: '56 Cinemas • IMAX Laser & 4DX',
        details: '56 Cinemas available (PVR Forum, Vega City IMAX, Cinepolis)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
      ),
      _CityData(
        id: 10,
        name: 'Mysuru',
        screensInfo: '12 Cinemas • Dolby Atmos',
        details: '12 Cinemas available (DRC Cinemas, INOX Garuda)',
        icon: Icons.account_balance_rounded,
      ),
      _CityData(
        id: 11,
        name: 'Mangaluru',
        screensInfo: '8 Cinemas',
        details: '8 Cinemas available (PVR Forum Fiza, Cinepolis)',
        icon: Icons.theaters_rounded,
      ),
    ],
    'Delhi NCR': [
      _CityData(
        id: 12,
        name: 'New Delhi',
        screensInfo: '52 Cinemas • PVR Director\'s Cut',
        details: '52 Cinemas available (PVR Plaza, Vegas IMAX, Delite)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
      ),
      _CityData(
        id: 13,
        name: 'Gurugram',
        screensInfo: '28 Cinemas • 4DX & Atmos',
        details: '28 Cinemas available (Ambience PVR, MGF Cinepolis)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
      _CityData(
        id: 14,
        name: 'Noida',
        screensInfo: '22 Cinemas • Logix IMAX',
        details: '22 Cinemas available (PVR Superplex Logix, Wave Cinemas)',
        icon: Icons.corporate_fare_rounded,
        badge: 'IMAX',
      ),
    ],
    'Tamil Nadu': [
      _CityData(
        id: 15,
        name: 'Chennai',
        screensInfo: '44 Cinemas • Palazzo & Luxe IMAX',
        details: '44 Cinemas available (SPI Palazzo, Luxe Phoenix, PVR VR)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
      ),
      _CityData(
        id: 16,
        name: 'Coimbatore',
        screensInfo: '18 Cinemas • Broadway IMAX',
        details: '18 Cinemas available (Broadway Cinemas, Inox Prozone)',
        icon: Icons.theaters_rounded,
      ),
    ],
    'California': [
      _CityData(
        id: 17,
        name: 'Los Angeles',
        screensInfo: '40 Cinemas • Universal IMAX',
        details: '40 Cinemas available (AMC Universal, TCL Chinese Theatre)',
        icon: Icons.movie_rounded,
        hasLaser: true,
      ),
      _CityData(
        id: 18,
        name: 'San Francisco',
        screensInfo: '25 Cinemas • Metreon IMAX',
        details: '25 Cinemas available (AMC Metreon 16, Century San Francisco)',
        icon: Icons.domain_rounded,
        badge: 'IMAX',
      ),
    ],
    'New York': [
      _CityData(
        id: 19,
        name: 'New York City',
        screensInfo: '45 Cinemas • Lincoln Square IMAX',
        details: '45 Cinemas available (AMC Lincoln Square 13, Regal Union Square)',
        icon: Icons.apartment_rounded,
        hasLaser: true,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    if (widget.currentCity != null) {
      _selectedCity = widget.currentCity!.name;
      _selectedCityId = widget.currentCity!.id;
      if (widget.currentCity!.state.isNotEmpty) {
        _selectedState = widget.currentCity!.state;
      }
      if (widget.currentCity!.country.isNotEmpty) {
        _selectedCountry = widget.currentCity!.country;
        final match = _countries.firstWhere(
          (c) => c.name.toLowerCase() == _selectedCountry.toLowerCase(),
          orElse: () => _countries.first,
        );
        _selectedCountryFlag = match.flag;
      }
    }

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

  @override
  void dispose() {
    _countrySearchController.dispose();
    _stateSearchController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  void _switchStage(int stage) {
    setState(() {
      _currentStep = stage.clamp(1, 3);
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
      _currentStep = 2;
    });
  }

  void _selectState(String stateName) {
    setState(() {
      _selectedState = stateName;
      _updateCityForCurrentState();
      _currentStep = 3;
    });
  }

  void _updateCityForCurrentState() {
    final availableCities = _citiesByState[_selectedState];
    if (availableCities != null && availableCities.isNotEmpty) {
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
    });
  }

  void _triggerGpsDetection() {
    setState(() {
      _isGpsLocating = true;
      _gpsButtonText = 'Pinging GPS coordinates...';
    });

    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isGpsLocating = false;
        _gpsButtonText = 'Located: Mumbai, Suburban';
        _selectedCountry = 'India';
        _selectedCountryFlag = '🇮🇳';
        _selectedState = 'Maharashtra';
        _selectedCity = 'Mumbai';
        _selectedCityId = 1;
        _cityDetails = 'Detected via GPS • 48 Cinemas within 10 km';
        _currentStep = 3;
      });
    });
  }

  void _confirmAndReturn() {
    setState(() {
      _isConfirming = true;
      _confirmButtonText = 'Saving & Loading Movies...';
    });

    final chosenCity = City(
      id: _selectedCityId,
      name: _selectedCity,
      state: _selectedState,
      country: _selectedCountry,
    );

    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      widget.onLocationConfirmed?.call(chosenCity);
      Navigator.of(context).maybePop(chosenCity);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  // Ambient Glow Orbs
                  Positioned(
                    top: -40,
                    left: 200,
                    child: Container(
                      width: 380,
                      height: 180,
                      decoration: BoxDecoration(
                        color: kPrimaryVivid.withValues(alpha: 0.12),
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
                        color: kGold.withValues(alpha: 0.05),
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

                      // 2. Glassmorphic Panel (Cascade breadcrumb + Active Stage)
                      _buildMainGlassmorphicPanel(),

                      const SizedBox(height: 24),

                      // 3. Tactile Perforated Cinema Ticket Footer Card
                      _buildTactileTicketFooter(),

                      const SizedBox(height: 20),

                      // 4. Partner Guarantee Bar
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
  }

  // --- APP BAR ---

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: kSurfaceLow.withValues(alpha: 0.95),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kSurfaceHigh),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: kTextWhite, size: 18),
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/cineza_logo_transparent.png',
            height: 26,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.confirmation_number_rounded,
              color: kSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Region Discovery',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kTextWhite,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _confirmAndReturn,
          icon: const Icon(Icons.check_rounded, color: kSecondary, size: 18),
          label: Text(
            'Apply',
            style: GoogleFonts.inter(
              color: kSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
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
              const Icon(Icons.confirmation_number_rounded, color: kSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                'CINEZA',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.8,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(width: 6),
              Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.5))),
              const SizedBox(width: 6),
              const Icon(Icons.my_location_rounded, color: kPrimary, size: 14),
              const SizedBox(width: 4),
              Text(
                'REGION DISCOVERY',
                style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
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
                    colors: [Color(0xFF38BDF8), Color(0xFF0062FF), Color(0xFFFFB800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'movies today?',
                    style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: kTextMuted,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Stepper Indicator
        _buildStepperIndicator(),
      ],
    );
  }

  Widget _buildStepperIndicator() {
    final progressFraction = _currentStep == 1
        ? 0.0
        : _currentStep == 2
            ? 0.5
            : 1.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Base Connecting Line
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              height: 2,
              color: kSurfaceHighest,
            ),

            // Animated Progress Line
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 40),
                height: 2,
                width: 460 * progressFraction,
                color: kPrimaryVivid,
              ),
            ),

            // Steps Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepBadge(stepNumber: 1, title: '1. Country'),
                _buildStepBadge(stepNumber: 2, title: '2. State'),
                _buildStepBadge(stepNumber: 3, title: '3. City'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepBadge({required int stepNumber, required String title}) {
    final isPassed = _currentStep > stepNumber;
    final isActive = _currentStep == stepNumber;

    return InkWell(
      onTap: () => _switchStage(stepNumber),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? kPrimaryVivid
                    : isPassed
                        ? kPrimary
                        : kSurfaceHighest,
                border: isActive
                    ? Border.all(color: kSecondary.withValues(alpha: 0.6), width: 3)
                    : null,
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
                        style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
    );
  }

  // --- MAIN GLASSMORPHIC PANEL ---

  Widget _buildMainGlassmorphicPanel() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Cascade Breadcrumb Trail & GPS Button
          _buildBreadcrumbAndGpsBar(),

          const SizedBox(height: 20),

          // Active Stage
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _currentStep == 1
                ? _buildCountryStage()
                : _currentStep == 2
                    ? _buildStateStage()
                    : _buildCityStage(),
          ),

          const SizedBox(height: 20),

          // GPS Proximity Discovery Teaser
          _buildGpsProximityBanner(),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbAndGpsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSurfaceHigh.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // Breadcrumb Trail
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LOCATION: ',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: kTextMuted,
                ),
              ),
              _buildBreadcrumbChip(
                label: '$_selectedCountryFlag $_selectedCountry',
                onTap: () => _switchStage(1),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('/', style: TextStyle(color: kTextMuted, fontSize: 13)),
              ),
              _buildBreadcrumbChip(
                label: _selectedState,
                onTap: () => _switchStage(2),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('/', style: TextStyle(color: kTextMuted, fontSize: 13)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryVivid.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kPrimaryVivid.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.theater_comedy_rounded, size: 14, color: kSecondary),
                    const SizedBox(width: 5),
                    Text(
                      _selectedCity,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Quick GPS Trigger Button
          InkWell(
            onTap: _isGpsLocating ? null : _triggerGpsDetection,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kSurfaceHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kSurfaceHigh),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isGpsLocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kSecondary),
                        )
                      : const Icon(Icons.near_me_rounded, color: kPrimary, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    _gpsButtonText,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: kTextWhite,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: kSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: kSurfaceHigh,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: kTextWhite,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_rounded, size: 11, color: kTextMuted),
          ],
        ),
      ),
    );
  }

  // --- STAGE 1: COUNTRY SELECTOR ---

  Widget _buildCountryStage() {
    final filtered = _countrySearchQuery.isEmpty
        ? _countries
        : _countries.where((c) {
            return c.name.toLowerCase().contains(_countrySearchQuery);
          }).toList();

    return Column(
      key: const ValueKey('country-stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.public_rounded,
          title: 'Select Target Country',
          subtitle: 'We support regional film ratings, currency standards, and language preferences.',
          searchController: _countrySearchController,
          hint: 'Search country...',
        ),
        const SizedBox(height: 16),
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
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final country = filtered[index];
                final isSelected = country.name == _selectedCountry;

                return InkWell(
                  onTap: () => _selectCountry(country.name, country.flag),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? kSurfaceHigh : kSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kSecondary.withValues(alpha: 0.6) : kSurfaceHigh,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kPrimaryVivid.withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
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
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: kTextWhite,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                country.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isSelected ? kSecondary : kTextMuted,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: isSelected ? kSecondary : kTextMuted,
                          size: 18,
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

  // --- STAGE 2: STATE SELECTOR ---

  Widget _buildStateStage() {
    final stateList = _statesByCountry[_selectedCountry] ?? [];
    final filtered = _stateSearchQuery.isEmpty
        ? stateList
        : stateList.where((s) => s.name.toLowerCase().contains(_stateSearchQuery)).toList();

    return Column(
      key: const ValueKey('state-stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.map_rounded,
          title: 'Select State / Province',
          subtitle: 'Showing active film distribution zones in $_selectedCountry.',
          searchController: _stateSearchController,
          hint: 'Search state or region...',
        ),
        const SizedBox(height: 16),
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
                final stateItem = filtered[index];
                final isSelected = stateItem.name == _selectedState;

                return InkWell(
                  onTap: () => _selectState(stateItem.name),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? kSurfaceHigh : kSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? kSecondary.withValues(alpha: 0.6) : kSurfaceHigh,
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stateItem.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: kTextWhite,
                            ),
                          ),
                        ),
                        Text(
                          stateItem.screens,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  // --- STAGE 3: CITY SELECTOR (BENTO GRID) ---

  Widget _buildCityStage() {
    final cityList = _citiesByState[_selectedState] ?? [];
    final filtered = _citySearchQuery.isEmpty
        ? cityList
        : cityList.where((c) => c.name.toLowerCase().contains(_citySearchQuery)).toList();

    return Column(
      key: const ValueKey('city-stage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStageHeader(
          icon: Icons.location_city_rounded,
          title: 'Select Your City',
          subtitle: 'Listing cinemas and multiplex chains across $_selectedState.',
          searchController: _citySearchController,
          hint: 'Search city or town...',
        ),
        const SizedBox(height: 16),
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
                childAspectRatio: 1.6,
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
                        color: isSelected ? kSecondary.withValues(alpha: 0.6) : kSurfaceHigh,
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
                                    const Icon(
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
                                        style: GoogleFonts.inter(
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
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kTextWhite,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    city.screensInfo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
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
                            child: Container(
                              height: 3,
                              decoration: const BoxDecoration(
                                color: kSecondary,
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
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
    );
  }

  Widget _buildStageHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required TextEditingController searchController,
    required String hint,
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextWhite,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Search Input
        Container(
          width: 240,
          height: 38,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kSurfaceHigh),
          ),
          child: TextField(
            controller: searchController,
            style: GoogleFonts.inter(fontSize: 12, color: kTextWhite),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(fontSize: 12, color: kTextMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kTextMuted),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  // --- GPS PROXIMITY DISCOVERY BANNER ---

  Widget _buildGpsProximityBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceHigh),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.radar_rounded, color: kGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proximity Search Enabled',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: kTextWhite,
                  ),
                ),
                Text(
                  'We prioritize theatres within 10 km with live recliner availability and fast snack delivery.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 6,
            children: [
              _buildTag('Dolby 7.1', kSurfaceHighest, kTextMuted),
              _buildTag('IMAX with Laser', kGold.withValues(alpha: 0.15), kGold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  // --- TACTILE PERFORATED CINEMA TICKET FOOTER ---

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
                  child: const Icon(Icons.verified_rounded, color: kSecondary, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONFIRMED SELECTION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_selectedCity, $_selectedState ($_selectedCountry)',
                      style: GoogleFonts.plusJakartaSans(
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
                          style: GoogleFonts.inter(
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

            // Action Buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isConfirming ? null : _confirmAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryVivid,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    shadowColor: kPrimaryVivid.withValues(alpha: 0.5),
                  ),
                  child: _isConfirming
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _confirmButtonText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Confirm & Start Booking',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- PARTNER GUARANTEE BAR ---

  Widget _buildPartnerGuaranteeBar() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildGuaranteeItem(Icons.verified_user_rounded, 'Official Partner of PVR-INOX, Cinepolis & Carnival', kGold),
        Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.5))),
        _buildGuaranteeItem(Icons.pin_drop_rounded, 'Real-time Seat Matrices & Pricing', kSecondary),
        Text('•', style: TextStyle(color: kTextMuted.withValues(alpha: 0.5))),
        _buildGuaranteeItem(Icons.local_movies_rounded, 'Subtitles & Audio Track Format Filtering', kGold),
      ],
    );
  }

  Widget _buildGuaranteeItem(IconData icon, String label, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: kTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- HELPER CLASSES & CLIPPERS ---

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
