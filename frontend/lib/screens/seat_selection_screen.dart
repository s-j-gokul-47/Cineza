import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_response.dart';
import '../models/movie.dart';
import '../models/seat.dart';
import '../models/show.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_success_dialog.dart';
import '../widgets/cinema_hall_3d_view.dart';
import '../widgets/concessions_sheet.dart';
import '../widgets/countdown_timer_widget.dart';
import '../widgets/curved_screen_painter.dart';
import '../widgets/seat_widget.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final ApiService _apiService = ApiService();

  static final Movie _defaultMovie = Movie(
    id: 1,
    title: '24',
    synopsis:
        'A sci-fi thriller about a genius watchmaker who invents a time-travel watch. When his vengeful twin brother Athreya resurfaces to claim it, a thrilling war across timelines begins.',
    posterUrl: 'assets/images/movie_24.jpg',
    backdropUrl: 'assets/images/titlecard_24.png',
    genre: 'Sci-Fi',
    language: 'Tamil',
    durationMinutes: 164,
    rating: 'UA',
    imdbScore: 7.9,
    releaseDate: '2016-05-06',
  );

  static final ShowItem _defaultShow = ShowItem(
    id: 1,
    movieId: 1,
    movieTitle: '24',
    theatreId: 1,
    theatreName: 'PVR VR Mall',
    theatreAddress: 'Anna Nagar, Chennai',
    screenId: 1,
    screenName: 'Screen 1',
    screenType: 'IMAX 3D',
    startTime: DateTime.now().add(const Duration(hours: 1)),
    endTime: DateTime.now().add(const Duration(hours: 3, minutes: 45)),
    baseStartingPrice: 190.0,
  );

  ShowItem _show = _defaultShow;
  Movie _movie = _defaultMovie;
  bool _argsLoaded = false;
  ShowSeatMap? _seatMap;
  bool _isLoading = true;

  final Set<SeatModel> _selectedSeats = {};
  String? _activeLockToken;
  bool _isLocking = false;
  bool _isBooking = false;

  // 3D Hall vs 2D Plan View Toggle
  bool _is3DView = true;

  // 3D Hall atmospheric settings
  bool _houseLights = false;
  bool _isHd = true;
  SeatModel? _povSeat;

  // Quick Pick Seat Count Stepper
  int _quickPickCount = 2;

  // Selected Concessions / Snacks
  List<SnackItem> _selectedSnacks = [];

  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _hydrateUserDetails();
    AuthService.currentUserNotifier.addListener(_onAuthChanged);
    ThemeController.themeMode.addListener(_onThemeChanged);
  }

  void _onAuthChanged() {
    if (mounted) {
      _hydrateUserDetails();
      setState(() {});
    }
  }

  void _hydrateUserDetails() {
    final user = AuthService.currentUser;
    final fbUser = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber ?? fbUser?.phoneNumber ?? '';
    final email = user?.email ?? fbUser?.email ?? '';
    if (phone.isNotEmpty && (_phoneController.text.isEmpty || _phoneController.text != phone)) {
      _phoneController.text = phone;
    }
    if (email.isNotEmpty && (_emailController.text.isEmpty || _emailController.text != email)) {
      _emailController.text = email;
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthService.currentUserNotifier.removeListener(_onAuthChanged);
    ThemeController.themeMode.removeListener(_onThemeChanged);
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        if (args['show'] is ShowItem) _show = args['show'] as ShowItem;
        if (args['movie'] is Movie) _movie = args['movie'] as Movie;
      }
      _argsLoaded = true;
      _loadSeatMap();
    }
  }

  Future<void> _loadSeatMap() async {
    setState(() => _isLoading = true);
    final seatMap = await _apiService.getShowSeatMap(
      _show.id,
      lockToken: _activeLockToken,
      movieTitle: _movie.title,
      theatreName: _show.theatreName,
      screenName: _show.screenName,
      screenType: _show.screenType,
      basePrice: _show.baseStartingPrice,
    );
    if (mounted) {
      setState(() {
        _seatMap = seatMap;
        _isLoading = false;
      });
    }
  }

  String get _currencySymbol => _show.baseStartingPrice >= 100 ? '₹' : '\$';

  String _formatPrice(double amount) {
    if (_show.baseStartingPrice >= 100) {
      return '₹${amount.toInt()}';
    } else {
      return '\$${amount.toStringAsFixed(2)}';
    }
  }

  void _toggleSeat(SeatModel seat) {
    if (seat.status == SeatStatusType.locked || seat.status == SeatStatusType.booked) {
      return;
    }

    setState(() {
      if (seat.status == SeatStatusType.selected) {
        seat.status = SeatStatusType.available;
        _selectedSeats.remove(seat);
        if (_povSeat?.id == seat.id) {
          _povSeat = null;
        }
      } else {
        seat.status = SeatStatusType.selected;
        _selectedSeats.add(seat);
      }
    });
  }

  double get _totalPrice {
    return _selectedSeats.fold(0.0, (sum, seat) => sum + seat.price);
  }

  double get _snacksTotal {
    return _selectedSnacks.fold(0.0, (sum, snack) => sum + (snack.price * snack.quantity));
  }

  /// Cineverse Sweet-Spot Best Seats Finder Algorithm:
  /// Evaluates available contiguous seat windows of size [quantity]
  /// score = distFromCenter * 1.2 + distFromSweetSpotRow
  void _findAndSelectBestSeats(int quantity) {
    if (_seatMap == null) return;

    final preferredRows = ['E', 'D', 'C', 'F', 'B', 'A'];
    List<SeatModel>? bestWindow;
    double bestScore = double.infinity;

    for (final rowName in preferredRows) {
      final rowSeats = _seatMap!.seatsByRow[rowName] ?? [];
      if (rowSeats.length < quantity) continue;

      final sweetSpotRowDistance = preferredRows.indexOf(rowName).toDouble() * 2.2;

      for (int i = 0; i <= rowSeats.length - quantity; i++) {
        final window = rowSeats.sublist(i, i + quantity);

        final hasUnavailable = window.any((s) =>
            s.status == SeatStatusType.booked || s.status == SeatStatusType.locked);
        if (hasUnavailable) continue;

        // Check if seats cross aisles
        bool crossesAisle = false;
        for (int k = 0; k < window.length - 1; k++) {
          if (window[k + 1].seatNumber != window[k].seatNumber + 1) {
            crossesAisle = true;
            break;
          }
        }
        if (crossesAisle) continue;

        // Center calculation
        final avgSeatNum = window.map((s) => s.seatNumber).reduce((a, b) => a + b) / quantity;
        final centerNum = (rowSeats.length + 1) / 2.0;
        final distFromCenter = (avgSeatNum - centerNum).abs();

        final score = distFromCenter * 1.2 + sweetSpotRowDistance;
        if (score < bestScore) {
          bestScore = score;
          bestWindow = window;
        }
      }
    }

    if (bestWindow != null && bestWindow.isNotEmpty) {
      setState(() {
        // Deselect previous
        for (final s in _selectedSeats) {
          s.status = SeatStatusType.available;
        }
        _selectedSeats.clear();

        // Select best
        for (final s in bestWindow!) {
          s.status = SeatStatusType.selected;
          _selectedSeats.add(s);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Selected sweet-spot seats: ${bestWindow.map((s) => s.label).join(", ")}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.warning,
          content: Text('No contiguous seats available for this quantity. Try choosing manually.'),
        ),
      );
    }
  }

  /// Prompt guest user to sign in or create an account before reserving seats
  Future<bool> _promptSignInRequired() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seatLabels = _selectedSeats.map((s) => s.label).join(', ');

    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.getSurface(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top drag indicator
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Lock / Cinema Badge
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 30,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Sign In to Reserve Seats',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getTextPrimary(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Please sign in or create an account to lock seats $seatLabels and continue to snacks & checkout.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.getTextSecondary(isDark),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Reserved seat indicator chip
              if (_selectedSeats.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedSeats.length} seat${_selectedSeats.length > 1 ? 's' : ''} ($seatLabels) held for your login',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'Sign In with Mobile / Username',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final res = await Navigator.pushNamed(context, '/login');
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext, res == true || AuthService.isLoggedIn);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.getTextPrimary(isDark),
                    side: BorderSide(color: AppTheme.getSurfaceBorder(isDark)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text(
                    'New to Cineza? Create Account',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    final res = await Navigator.pushNamed(context, '/signup');
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext, res == true || AuthService.isLoggedIn);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    return result == true || AuthService.isLoggedIn || FirebaseAuth.instance.currentUser != null;
  }

  /// Lock selected seats in Redis with a 10-minute TTL, then open Snacks / Checkout
  Future<void> _lockSelectedSeatsAndProceed() async {
    if (_selectedSeats.isEmpty) return;

    // Verify user is signed in before locking seats and proceeding to checkout
    final bool isUserLoggedIn = AuthService.isLoggedIn || FirebaseAuth.instance.currentUser != null;
    if (!isUserLoggedIn) {
      final signedIn = await _promptSignInRequired();
      if (!signedIn || (!AuthService.isLoggedIn && FirebaseAuth.instance.currentUser == null)) {
        return;
      }
      _hydrateUserDetails();
    }

    setState(() => _isLocking = true);

    final seatIds = _selectedSeats.map((s) => s.id).toList();
    final lockResult = await _apiService.lockSeats(_show.id, seatIds, ApiService.sessionId);

    setState(() => _isLocking = false);

    if (lockResult.success) {
      setState(() {
        _activeLockToken = lockResult.lockToken;
      });

      if (mounted) {
        _openConcessionsAndCheckout(lockResult.ttlSeconds);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lockResult.message.isNotEmpty
                        ? lockResult.message
                        : 'Selected seat was just locked by another guest. Please choose other seats.',
                  ),
                ),
              ],
            ),
          ),
        );
        _loadSeatMap();
      }
    }
  }

  void _openConcessionsAndCheckout(int ttlSeconds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ConcessionsSheet(
          seatTotal: _totalPrice,
          ticketCount: _selectedSeats.length,
          currencySymbol: _currencySymbol,
          onProceed: (snacks) {
            Navigator.pop(modalContext);
            setState(() => _selectedSnacks = snacks);
            _showCheckoutModal(ttlSeconds);
          },
          onSkip: () {
            Navigator.pop(modalContext);
            setState(() => _selectedSnacks = []);
            _showCheckoutModal(ttlSeconds);
          },
        );
      },
    );
  }

  void _showCheckoutModal(int ttlSeconds) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePrimary = AppTheme.getPrimary(isDark);
    final seatLabels = _selectedSeats.map((s) => s.label).join(', ');
    final bookingFee = _show.baseStartingPrice >= 100 ? 30.0 : 2.50;
    final grandTotal = _totalPrice + _snacksTotal + bookingFee;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.getSurface(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle and Countdown Timer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Checkout & Confirm',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        CountdownTimerWidget(
                          initialSeconds: ttlSeconds,
                          onTimerExpired: () {
                            Navigator.pop(modalContext);
                            _handleLockExpiry();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seats $seatLabels are held exclusively for you in Redis cache.',
                      style: TextStyle(color: AppTheme.getTextSecondary(isDark), fontSize: 13),
                    ),

                    if (AuthService.isLoggedIn) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF06B6D4)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Booking as @${AuthService.currentUser?.displayName ?? 'user'} (${AuthService.currentUser?.phoneNumber ?? _phoneController.text})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF06B6D4),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Contact fields
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address for M-Ticket',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number for SMS QR',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),
                    Divider(color: AppTheme.getSurfaceBorder(isDark)),
                    const SizedBox(height: 10),

                    // Price Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tickets (${_selectedSeats.length} seats)',
                            style: TextStyle(color: AppTheme.getTextSecondary(isDark))),
                        Text(_formatPrice(_totalPrice),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(isDark),
                            )),
                      ],
                    ),

                    if (_selectedSnacks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Movie Snacks (${_selectedSnacks.fold(0, (sum, s) => sum + s.quantity)} items)',
                              style: TextStyle(color: AppTheme.getTextSecondary(isDark))),
                          Text(_formatPrice(_snacksTotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.goldAccent,
                              )),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Booking Fee & Taxes',
                            style: TextStyle(color: AppTheme.getTextSecondary(isDark))),
                        Text(_formatPrice(bookingFee),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(isDark),
                            )),
                      ],
                    ),

                    const SizedBox(height: 10),
                    Divider(color: AppTheme.getSurfaceBorder(isDark)),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Payable',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          _formatPrice(grandTotal),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: activePrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Confirm Booking Action
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activePrimary,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isBooking
                            ? null
                            : () async {
                                final bool isUserLoggedIn =
                                    AuthService.isLoggedIn || FirebaseAuth.instance.currentUser != null;
                                if (!isUserLoggedIn) {
                                  Navigator.pop(modalContext);
                                  final signedIn = await _promptSignInRequired();
                                  if (signedIn && mounted) {
                                    _hydrateUserDetails();
                                    _showCheckoutModal(ttlSeconds);
                                  }
                                  return;
                                }

                                setModalState(() => _isBooking = true);
                                try {
                                  final receipt = await _apiService.confirmBooking(
                                    showId: _show.id,
                                    seatIds: _selectedSeats.map((s) => s.id).toList(),
                                    lockToken: _activeLockToken!,
                                    email: _emailController.text.trim(),
                                    phone: _phoneController.text.trim(),
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(modalContext);
                                    _showSuccessTicketModal(receipt);
                                  }
                                } catch (e) {
                                  setModalState(() => _isBooking = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppTheme.danger,
                                        content: Text('Booking failed: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                        child: _isBooking
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm & Pay Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
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
    ).then((_) {
      if (_activeLockToken != null && !_isBooking) {
        _apiService.unlockSeats(
          _show.id,
          _selectedSeats.map((s) => s.id).toList(),
          ApiService.sessionId,
        );
        setState(() => _activeLockToken = null);
      }
    });
  }

  void _handleLockExpiry() {
    setState(() {
      _activeLockToken = null;
      _selectedSeats.clear();
    });
    _loadSeatMap();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.warning,
        content: Text('Seat lock expired after 10 minutes. Please select your seats again.'),
      ),
    );
  }

  void _showSuccessTicketModal(BookingReceipt receipt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BookingSuccessDialog(
        receipt: receipt,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDark = currentMode == ThemeMode.dark;
        final activePrimary = AppTheme.getPrimary(isDark);
        final timeFormat = DateFormat('EEE, d MMM • h:mm a');

        return Scaffold(
          backgroundColor: AppTheme.getBackground(isDark),
          appBar: _buildTopBar(isDark, activePrimary, timeFormat),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: activePrimary))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth >= 960;

                    if (isWideScreen) {
                      // Desktop Split Layout: 3D Cinema Hall on Left, Rich Booking Sidebar on Right
                      return Row(
                        children: [
                          // Left 3D / 2D Auditorium Canvas
                          Expanded(
                            flex: 7,
                            child: _is3DView
                                ? CinemaHall3DView(
                                    seatMap: _seatMap!,
                                    selectedSeats: _selectedSeats,
                                    onSeatTapped: _toggleSeat,
                                    movieTitle: _movie.title,
                                    movieBackdropUrl: _movie.resolvedPosterUrl,
                                    trailerYoutubeId: _movie.trailerYoutubeId,
                                    houseLights: _houseLights,
                                    isHd: _isHd,
                                    povSeat: _povSeat,
                                    onResetPov: () => setState(() => _povSeat = null),
                                  )
                                : _build2DPlanView(isDark),
                          ),

                          // Right Sidebar (Seat Classes, Quick Pick, Selected Seats, Checkout)
                          Container(
                            width: 380,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              border: Border(
                                left: BorderSide(
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                              ),
                            ),
                            child: _buildSidebarContent(isDark, activePrimary),
                          ),
                        ],
                      );
                    } else {
                      // Mobile / Tablet Responsive Stack
                      return Column(
                        children: [
                          Expanded(
                            child: _is3DView
                                ? CinemaHall3DView(
                                    seatMap: _seatMap!,
                                    selectedSeats: _selectedSeats,
                                    onSeatTapped: _toggleSeat,
                                    movieTitle: _movie.title,
                                    movieBackdropUrl: _movie.resolvedPosterUrl,
                                    trailerYoutubeId: _movie.trailerYoutubeId,
                                    houseLights: _houseLights,
                                    isHd: _isHd,
                                    povSeat: _povSeat,
                                    onResetPov: () => setState(() => _povSeat = null),
                                  )
                                : SingleChildScrollView(child: _build2DPlanView(isDark)),
                          ),
                          _buildMobileBottomTray(isDark, activePrimary),
                        ],
                      );
                    }
                  },
                ),
        );
      },
    );
  }

  PreferredSizeWidget _buildTopBar(
    bool isDark,
    Color activePrimary,
    DateFormat timeFormat,
  ) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _movie.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Text(
                        _movie.rating,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_show.theatreName} • ${timeFormat.format(_show.startTime)} • ${_show.screenType} • ${_movie.language.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 3D ⟷ 2D View Switcher Pill
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewToggleOption('3D Hall', true, Icons.view_in_ar_rounded, activePrimary),
              _buildViewToggleOption('2D Plan', false, Icons.grid_view_rounded, activePrimary),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // House Lights Toggle (for 3D mode)
        if (_is3DView)
          IconButton(
            icon: Icon(
              _houseLights ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
              color: _houseLights ? AppTheme.goldAccent : (isDark ? Colors.white70 : Colors.black54),
              size: 20,
            ),
            tooltip: _houseLights ? 'House Lights ON' : 'Movie Darkness Mode',
            onPressed: () => setState(() => _houseLights = !_houseLights),
          ),

        // Refresh
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Refresh Seats',
          onPressed: _loadSeatMap,
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildViewToggleOption(String label, bool is3D, IconData icon, Color primary) {
    final bool active = _is3DView == is3D;
    return InkWell(
      onTap: () => setState(() => _is3DView = is3D),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Right Sidebar content matching Cineverse showcase `seats-3d.png`
  Widget _buildSidebarContent(bool isDark, Color activePrimary) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SEAT CLASSES HEADER
                Text(
                  'SEAT CLASSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),

                // 4 Tiers matching Cineverse showcase
                _buildSeatClassCard(
                  title: 'Royal Recliner',
                  subtitle: 'Motorised recliners • F&B to seat',
                  price: _show.baseStartingPrice >= 100 ? '₹550' : '\$24',
                  remaining: '32 left',
                  accentColor: const Color(0xFFEAB308), // Gold
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSeatClassCard(
                  title: 'Balcony',
                  subtitle: 'Elevated view • centre aligned',
                  price: _show.baseStartingPrice >= 100 ? '₹320' : '\$18',
                  remaining: '148 left',
                  accentColor: const Color(0xFFA855F7), // Purple
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSeatClassCard(
                  title: 'Prime',
                  subtitle: 'Sweet spot for sound & picture',
                  price: _show.baseStartingPrice >= 100 ? '₹240' : '\$14',
                  remaining: '209 left',
                  accentColor: const Color(0xFF10B981), // Emerald
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildSeatClassCard(
                  title: 'Classic',
                  subtitle: 'Front rows • big screen energy',
                  price: _show.baseStartingPrice >= 100 ? '₹160' : '\$10',
                  remaining: '117 left',
                  accentColor: const Color(0xFF3B82F6), // Blue
                  isDark: isDark,
                ),

                const SizedBox(height: 12),

                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDotLegend('Booked', const Color(0xFF334155)),
                    _buildDotLegend('Your pick', const Color(0xFF06B6D4)),
                    _buildDotLegend('Available', const Color(0xFF10B981)),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white10 : Colors.black12),
                const SizedBox(height: 14),

                // 2. QUICK PICK SECTION
                Text(
                  'QUICK PICK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Quantity Stepper
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: _quickPickCount > 1
                                ? () => setState(() => _quickPickCount--)
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '$_quickPickCount',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: _quickPickCount < 6
                                ? () => setState(() => _quickPickCount++)
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // "Best N Seats" Action Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => _findAndSelectBestSeats(_quickPickCount),
                        icon: const Icon(Icons.auto_awesome, size: 15, color: Colors.black),
                        label: Text(
                          '✦ Best $_quickPickCount seats',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white10 : Colors.black12),
                const SizedBox(height: 14),

                // 3. YOUR SEATS LIST
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YOUR SEATS (${_selectedSeats.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    if (_selectedSeats.isNotEmpty)
                      InkWell(
                        onTap: () {
                          setState(() {
                            for (final s in _selectedSeats) {
                              s.status = SeatStatusType.available;
                            }
                            _selectedSeats.clear();
                            _povSeat = null;
                          });
                        },
                        child: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_selectedSeats.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Text(
                      'Click any seat in the hall, or let us pick the best ones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedSeats.map((seat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF06B6D4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              seat.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _toggleSeat(seat),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                // "View Screen from Seat" POV preview button
                if (_selectedSeats.isNotEmpty && _is3DView) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cyanAccent,
                      side: const BorderSide(color: AppTheme.cyanAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _povSeat = _selectedSeats.first;
                      });
                    },
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                    label: Text(
                      'Preview view from ${_selectedSeats.first.label}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Checkout Action Box
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedSeats.length} tickets' +
                            (_selectedSeats.isNotEmpty ? ' • fees ${_formatPrice(30)}' : ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      Text(
                        _formatPrice(_totalPrice + (_selectedSeats.isNotEmpty ? 30.0 : 0.0)),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedSeats.isNotEmpty
                          ? AppTheme.primary
                          : const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: _selectedSeats.isNotEmpty ? 4 : 0,
                    ),
                    onPressed: _selectedSeats.isNotEmpty && !_isLocking
                        ? _lockSelectedSeatsAndProceed
                        : null,
                    child: _isLocking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'CONTINUE • ADD SNACKS',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatClassCard({
    required String title,
    required String subtitle,
    required String price,
    required String remaining,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          // Left Colored Accent Line
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),

          // Price & Remaining
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                remaining,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDotLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white60),
        ),
      ],
    );
  }

  /// Mobile Bottom Tray
  Widget _buildMobileBottomTray(bool isDark, Color activePrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selectedSeats.length} seats selected',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  _formatPrice(_totalPrice),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: activePrimary,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  tooltip: 'Pick Best 2 Seats',
                  onPressed: () => _findAndSelectBestSeats(2),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _selectedSeats.isNotEmpty && !_isLocking
                      ? _lockSelectedSeatsAndProceed
                      : null,
                  child: _isLocking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'CONTINUE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2D Plan View (Fallback mode)
  Widget _build2DPlanView(bool isDark) {
    final activePrimary = AppTheme.getPrimary(isDark);

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 18),
          // Curved Screen Graphic
          SizedBox(
            width: double.infinity,
            height: 70,
            child: CustomPaint(
              painter: CurvedScreenPainter(isDark: isDark),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'SCREEN THIS WAY',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.cyanAccent : const Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 20),

          // 2D Matrix Grid
          if (_seatMap != null) _buildSeatGrid(isDark),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSeatGrid(bool isDark) {
    final seatsByRow = _seatMap!.seatsByRow;
    final isINR = _show.baseStartingPrice >= 100;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: seatsByRow.entries.map((entry) {
            final rowName = entry.key;
            final seats = entry.value;

            final bool isTierStart = rowName == 'A' || rowName == 'C' || rowName == 'E';
            String tierTitle = 'CLASSIC';
            String tierPrice = isINR ? '₹160' : '\$10.00';
            IconData tierIcon = Icons.event_seat_rounded;
            Color tierAccent = const Color(0xFF3B82F6);

            if (rowName == 'A' || rowName == 'B') {
              tierTitle = 'ROYAL RECLINER';
              tierPrice = isINR ? '₹550' : '\$24.00';
              tierIcon = Icons.chair_rounded;
              tierAccent = const Color(0xFFEAB308);
            } else if (rowName == 'C' || rowName == 'D') {
              tierTitle = 'BALCONY';
              tierPrice = isINR ? '₹320' : '\$18.00';
              tierIcon = Icons.workspace_premium_rounded;
              tierAccent = const Color(0xFFA855F7);
            } else if (rowName == 'E' || rowName == 'F') {
              tierTitle = 'PRIME';
              tierPrice = isINR ? '₹240' : '\$14.00';
              tierIcon = Icons.star_rounded;
              tierAccent = const Color(0xFF10B981);
            }

            return Column(
              children: [
                if (isTierStart)
                  _buildTierHeader(
                    tierTitle: tierTitle,
                    price: tierPrice,
                    icon: tierIcon,
                    accentColor: tierAccent,
                    isDark: isDark,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row Letter Badge Left
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            rowName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              color: AppTheme.getTextMuted(isDark),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Seat items in row with aisle gap
                      ...seats.asMap().entries.map((seatEntry) {
                        final seatIndex = seatEntry.key;
                        final seat = seatEntry.value;
                        final bool hasAisle = seatIndex == 2 || seatIndex == 7;

                        return Row(
                          children: [
                            SeatWidget(
                              seat: seat,
                              onTap: () => _toggleSeat(seat),
                            ),
                            if (hasAisle) const SizedBox(width: 18),
                          ],
                        );
                      }),

                      const SizedBox(width: 8),
                      // Row Letter Badge Right
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            rowName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                              color: AppTheme.getTextMuted(isDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTierHeader({
    required String tierTitle,
    required String price,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            tierTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              price,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
