import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Screen displaying Cineza's official Terms of Service and Privacy Policy.
/// Allows direct tab switching, live clause filtering/search, and seamless return to caller.
class TermsPolicyScreen extends StatefulWidget {
  final int initialTab;

  const TermsPolicyScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<TermsPolicyScreen> createState() => _TermsPolicyScreenState();
}

class _TermsPolicyScreenState extends State<TermsPolicyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;

  // Dynamic Theme Tokens Aligned with Google Stitch Cineza
  bool get isDark => ThemeController.isDark(context);

  Color get kBackground => AppTheme.getBackground(isDark);
  Color get kSurfaceLow => isDark ? AppTheme.darkSurface : AppTheme.lightSurfaceContainer;
  Color get kSurface => isDark ? AppTheme.darkSurfaceContainer : AppTheme.lightSurface;
  Color get kSurfaceBorder => isDark ? AppTheme.darkSurfaceBorder : AppTheme.lightSurfaceBorder;
  Color get kPrimary => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kPrimaryVivid => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kSecondaryCyan => isDark ? AppTheme.accent : AppTheme.lightPrimary;
  Color get kGold => AppTheme.getGoldAccent(isDark);
  Color get kTextWhite => AppTheme.getTextPrimary(isDark);
  Color get kTextMuted => AppTheme.getTextMuted(isDark);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Allow route arguments to override initial tab:
    // e.g. Navigator.pushNamed(context, '/terms-policy', arguments: 1) or 'privacy'
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args < 2) {
      if (_tabController.index != args) {
        _tabController.index = args;
      }
    } else if (args is String) {
      if (args.toLowerCase().contains('priv') && _tabController.index != 1) {
        _tabController.index = 1;
      } else if (args.toLowerCase().contains('term') && _tabController.index != 0) {
        _tabController.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        return Scaffold(
          backgroundColor: kBackground,
          appBar: _buildAppBar(),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  children: [
                    // 1. Hero Header & Quick Stats Strip
                    _buildHeroHeader(),

                    // 2. Segmented Navigation Tabs
                    _buildSegmentedTabBar(),

                    // 3. Search Bar (collapsible or active)
                    if (_isSearchExpanded) _buildSearchBar(),

                    // 4. Tab Views (Terms vs Privacy)
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTermsTab(),
                          _buildPrivacyTab(),
                        ],
                      ),
                    ),

                    // 5. Bottom Sticky Agreement / Return Bar
                    _buildBottomActionBar(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- APP BAR ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kSurfaceLow.withValues(alpha: 0.95),
      elevation: 0,
      centerTitle: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kSurfaceBorder),
            ),
            child: Icon(Icons.arrow_back_rounded, color: kTextWhite, size: 18),
          ),
          tooltip: 'Return to Cineza',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/cineza_logo_transparent.png',
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.confirmation_number_rounded,
              color: kSecondaryCyan,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Cineza Legal & Trust',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kTextWhite,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: kPrimaryVivid.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kPrimaryVivid.withValues(alpha: 0.4)),
            ),
            child: Text(
              'v2.4 (2026)',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: kSecondaryCyan,
              ),
            ),
          ),
        ],
      ),
    ),
      actions: [
        CinezaThemeToggle(compact: MediaQuery.of(context).size.width < 700),
        const SizedBox(width: 4),
        IconButton(
          tooltip: _isSearchExpanded ? 'Close Search' : 'Search clauses',
          icon: Icon(
            _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
            color: _isSearchExpanded ? kSecondaryCyan : kTextMuted,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isSearchExpanded = !_isSearchExpanded;
              if (!_isSearchExpanded) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        IconButton(
          tooltip: 'Copy policy link',
          icon: Icon(Icons.link_rounded, color: kTextMuted, size: 20),
          onPressed: () {
            Clipboard.setData(
              const ClipboardData(text: AppConfig.termsPolicyUrl),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: kSecondaryCyan, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Policy URL copied to clipboard!',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
                backgroundColor: kSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: kSurfaceBorder),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kSurfaceBorder, height: 1),
      ),
    );
  }

  // --- HERO HEADER & SUMMARY CARDS ---

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: kSurfaceLow,
        border: Border(
          bottom: BorderSide(color: kSurfaceBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Governance & User Trust',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kTextWhite,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome to Cineza. We are committed to complete transparency regarding your ticket bookings, 10-minute high-concurrency seat locks, zero-knowledge payment encryption, and data protection.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: kTextMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick trust guarantee badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTrustPill(
                icon: Icons.timer_outlined,
                label: '10-Min Redis Seat Lock',
                color: kSecondaryCyan,
              ),
              _buildTrustPill(
                icon: Icons.lock_outline_rounded,
                label: '256-Bit Bank Encryption',
                color: kPrimary,
              ),
              _buildTrustPill(
                icon: Icons.credit_card_off_rounded,
                label: 'Zero Card Data Storage',
                color: const Color(0xFF10B981),
              ),
              _buildTrustPill(
                icon: Icons.qr_code_rounded,
                label: 'Instant E-Tickets & SMS',
                color: kGold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- SEGMENTED TAB BAR ---

  Widget _buildSegmentedTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kSurfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kPrimaryVivid.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: kTextMuted,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gavel_rounded, size: 16),
                SizedBox(width: 8),
                Text('Terms of Service'),
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 16),
                SizedBox(width: 8),
                Text('Privacy Policy'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH BAR ---

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSecondaryCyan.withValues(alpha: 0.4)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(fontSize: 13, color: kTextWhite),
        decoration: InputDecoration(
          hintText: 'Search terms (e.g. "cancellation", "lock", "refund", "card", "otp")...',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: kTextMuted),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: kSecondaryCyan),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: kTextMuted),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // --- TAB 1: TERMS OF SERVICE ---

  Widget _buildTermsTab() {
    final clauses = [
      _PolicyClause(
        number: '01',
        title: 'Agreement & Digital Acceptance',
        icon: Icons.handshake_outlined,
        content:
            'By accessing or utilizing the Cineza movie ticketing portal (web or mobile), authenticating via Mobile OTP, or reserving seats, you enter into a legally binding digital contract with Cineza Cinemas Pvt. Ltd. If you do not concur with any portion of these Terms, you must discontinue your booking immediately.',
      ),
      _PolicyClause(
        number: '02',
        title: 'High-Concurrency 10-Minute Seat Lock (Redis TTL)',
        icon: Icons.timer_rounded,
        highlight: true,
        content:
            'To ensure fair access during blockbuster releases, selected seats are locked under an exclusive distributed Redis cache with a strict 10-Minute Time-To-Live (TTL).\n\n'
            '• Unbroken Hold: During these 10 minutes, no other moviegoer worldwide can purchase your selected seats.\n'
            '• Automatic Expiry: If the checkout is not successfully authorized within 10 minutes, the lock expires automatically and the seats are released back to the general pool.\n'
            '• Final Confirmation: A booking is deemed confirmed only after successful payment gateway callback and generation of a unique 12-digit Cineza Booking ID with an encrypted QR code.',
      ),
      _PolicyClause(
        number: '03',
        title: 'Pricing, Convenience Fees & Taxation',
        icon: Icons.monetization_on_outlined,
        content:
            'All ticket prices reflect cinema exhibitor tariffs (including IMAX, Dolby Atmos, 4DX, and Premiere Recliner surcharges). Convenience fees, internet handling charges, and applicable Goods and Services Tax (GST) are transparently itemized prior to checkout. Internet handling fees are non-refundable once transaction processing is initiated.',
      ),
      _PolicyClause(
        number: '04',
        title: 'CBFC Movie Certifications & Mandatory Age Verification',
        icon: Icons.verified_user_outlined,
        content:
            'Cinematograph films in India are certified under Central Board of Film Certification (CBFC) ratings:\n\n'
            '• "A" (Adults Only): Strictly restricted to persons aged 18 and older. Cinema security will request government-issued photo ID (Aadhaar, Passport, Voter ID, Driving License) at the auditorium turnstiles.\n'
            '• "UA" (Parental Guidance) / "U" (Universal): Suitable for all age groups.\n'
            '• Minors denied entry to "A" rated screenings due to lack of valid legal proof of age are strictly ineligible for refunds.',
      ),
      _PolicyClause(
        number: '05',
        title: 'Ticket Cancellation, Rescheduling & Refund Protocol',
        icon: Icons.published_with_changes_rounded,
        content:
            '• Cancellation Eligibility: Participating cinema halls permit cancellation up to 2 hours before the scheduled showtime for Cineza Premiere members (4 hours for standard bookings).\n'
            '• Non-Cancellable Windows: Within 2 hours of showtime, tickets cannot be cancelled, modified, or transferred.\n'
            '• Refund Execution: Approved refunds are processed to your Cineza Wallet instantly or credited back to the source bank account within 3 to 5 business days per Reserve Bank of India clearance cycles.',
      ),
      _PolicyClause(
        number: '06',
        title: 'Food, Beverage & Concession Policies',
        icon: Icons.fastfood_outlined,
        content:
            'Outside food and beverage items are strictly forbidden inside auditorium halls in accordance with cinema licensing and municipal safety standards. Pre-ordered Cineza F&B combos can be collected at the fast-track concession kiosk by presenting your digital booking QR code.',
      ),
      _PolicyClause(
        number: '07',
        title: 'Cinema Etiquette & Anti-Piracy Enforcement',
        icon: Icons.videocam_off_outlined,
        content:
            'Under the Indian Cinematograph Act, unauthorized recording, streaming, or camcording of copyrighted cinematographic films inside an auditorium is a severe, cognizable criminal offense punishable by imprisonment and substantial fines. Violators will be removed from premises immediately and handed over to law enforcement authorities without refund.',
      ),
      _PolicyClause(
        number: '08',
        title: 'Limitation of Liability & Theater Operations',
        icon: Icons.security_rounded,
        content:
            'Cineza operates as an advanced technology intermediary and digital ticketing platform. Screen projection quality, sound calibration, air conditioning, auditorium cleanliness, and parking operations are the sole responsibility of the respective cinema theater management.',
      ),
    ];

    return _buildClauseList(clauses);
  }

  // --- TAB 2: PRIVACY POLICY ---

  Widget _buildPrivacyTab() {
    final clauses = [
      _PolicyClause(
        number: '01',
        title: 'Information We Collect',
        icon: Icons.account_circle_outlined,
        content:
            'We collect strictly necessary data to enable frictionless ticket reservations:\n\n'
            '• Mobile Phone Number: Required for fast, passwordless OTP authentication.\n'
            '• Transaction Records: Movie titles, showtimes, seat labels, booking references, and food vouchers.\n'
            '• Coarse Location (Optional): Used only upon explicit browser permission to arrange nearby cinema listings and current city showtimes.\n'
            '• Device Diagnostics: Browser version, operating system, and IP address for session security and anti-bot defense.',
      ),
      _PolicyClause(
        number: '02',
        title: 'How We Utilize Your Information',
        icon: Icons.bolt_rounded,
        content:
            'Your personal information is leveraged solely for operational purposes:\n\n'
            '• Delivering instant digital tickets, QR entrance passes, and booking updates via SMS and WhatsApp.\n'
            '• Maintaining your authenticated state across devices without insecure static passwords.\n'
            '• Thwarting unauthorized automated bots, seat hoarding scripts, and scalping syndicates.\n'
            '• Facilitating customer support inquiries and refund reconciliations.',
      ),
      _PolicyClause(
        number: '03',
        title: 'Zero-Knowledge Payment Card Security',
        icon: Icons.shield_rounded,
        highlight: true,
        content:
            'Cineza NEVER stores your credit card numbers, debit card numbers, CVVs, or net banking passwords on our infrastructure.\n\n'
            'All payment processing is handled through PCI-DSS Level 1 compliant financial payment aggregators utilizing 256-bit AES TLS encryption. Sensitive card data is tokenized according to Reserve Bank of India (RBI) payment guidelines.',
      ),
      _PolicyClause(
        number: '04',
        title: 'Third-Party Disclosure & Zero Ad Brokering',
        icon: Icons.group_outlined,
        content:
            'We maintain a strict anti-selling policy. We NEVER sell, lease, or monetize your personal details to third-party ad networks or brokers.\n\n'
            'Information is disclosed exclusively to:\n'
            '• Cinema Multiplex Turnstiles: To validate ticket authenticity and admit authorized guests.\n'
            '• SMS Gateway Providers (MSG91 / Firebase): Exclusively to transmit transactional OTP codes and booking vouchers.\n'
            '• Legal Authorities: Solely when mandated by court subpoena or statutory law enforcement order.',
      ),
      _PolicyClause(
        number: '05',
        title: 'Cookies & Browser Local Storage',
        icon: Icons.cookie_outlined,
        content:
            'Cineza uses lightweight browser local storage and encrypted session tokens strictly for preserving your selected city, theme preference (Dark/Light mode), and authenticated session token. We do not employ intrusive tracking pixels across third-party websites.',
      ),
      _PolicyClause(
        number: '06',
        title: 'User Rights & Account Data Deletion',
        icon: Icons.delete_forever_outlined,
        content:
            'You retain absolute sovereignty over your digital records. You may request a machine-readable export of your booking archive or initiate permanent account deletion by dispatching a verified request to privacy@cineza.com. Account deletion is executed within 30 days, retaining only legally mandatory fiscal tax receipts.',
      ),
      _PolicyClause(
        number: '07',
        title: 'Grievance Redressal & Legal Officer',
        icon: Icons.business_rounded,
        content:
            'In compliance with Information Technology (Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021:\n\n'
            'Grievance Officer: Mr. A. Rajagopal\n'
            'Cineza Entertainment Technologies Pvt. Ltd.\n'
            'Prestige Tech Park, Outer Ring Road, Bengaluru, Karnataka - 560103, India\n'
            'Contact Email: grievance@cineza.com | legal@cineza.com\n'
            'Response Time: Within 48 business hours.',
      ),
    ];

    return _buildClauseList(clauses);
  }

  // --- REUSABLE CLAUSE LIST WITH SEARCH FILTERING ---

  Widget _buildClauseList(List<_PolicyClause> clauses) {
    final filtered = _searchQuery.isEmpty
        ? clauses
        : clauses.where((c) {
            return c.title.toLowerCase().contains(_searchQuery) ||
                c.content.toLowerCase().contains(_searchQuery) ||
                c.number.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: kTextMuted.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'No clauses match "$_searchQuery"',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching for terms like "lock", "refund", "card", "otp", or "cancellation".',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: kTextMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final clause = filtered[index];
        return _buildClauseCard(clause);
      },
    );
  }

  Widget _buildClauseCard(_PolicyClause clause) {
    final isHighlighted = clause.highlight;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted ? Color(0xFF161B2B) : kSurfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? kSecondaryCyan.withValues(alpha: 0.45)
              : kSurfaceBorder,
          width: isHighlighted ? 1.4 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: kSecondaryCyan.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Clause Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? kSecondaryCyan.withValues(alpha: 0.2)
                        : kSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isHighlighted
                          ? kSecondaryCyan.withValues(alpha: 0.5)
                          : kSurfaceBorder,
                    ),
                  ),
                  child: Text(
                    '§ ${clause.number}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted ? kSecondaryCyan : kTextMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  clause.icon,
                  size: 18,
                  color: isHighlighted ? kSecondaryCyan : kPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clause.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: kTextWhite,
                    ),
                  ),
                ),
                if (isHighlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kSecondaryCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'KEY CLAUSE',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: kSecondaryCyan,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              clause.content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFCBD5E1),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STICKY BOTTOM ACTION BAR ---

  Widget _buildBottomActionBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: kSurfaceLow,
        border: Border(
          top: BorderSide(color: kSurfaceBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Official Cineza Legal Agreement • Encrypted & Enforceable',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kTextMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryVivid,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Accept & Return',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyClause {
  final String number;
  final String title;
  final IconData icon;
  final String content;
  final bool highlight;

  _PolicyClause({
    required this.number,
    required this.title,
    required this.icon,
    required this.content,
    this.highlight = false,
  });
}
