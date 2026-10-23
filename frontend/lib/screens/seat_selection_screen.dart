import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_response.dart';
import '../models/movie.dart';
import '../models/seat.dart';
import '../models/show.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_success_dialog.dart';
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

  late ShowItem _show;
  late Movie _movie;
  ShowSeatMap? _seatMap;
  bool _isLoading = true;

  final Set<SeatModel> _selectedSeats = {};
  String? _activeLockToken;
  bool _isLocking = false;
  bool _isBooking = false;

  final TextEditingController _emailController = TextEditingController(text: 'alex.doe@example.com');
  final TextEditingController _phoneController = TextEditingController(text: '+1-555-0199');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _show = args['show'] as ShowItem;
      _movie = args['movie'] as Movie;
      _loadSeatMap();
    }
  }

  Future<void> _loadSeatMap() async {
    setState(() => _isLoading = true);
    final seatMap = await _apiService.getShowSeatMap(_show.id, lockToken: _activeLockToken);
    if (mounted) {
      setState(() {
        _seatMap = seatMap;
        _isLoading = false;
      });
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
      } else {
        seat.status = SeatStatusType.selected;
        _selectedSeats.add(seat);
      }
    });
  }

  double get _totalPrice {
    return _selectedSeats.fold(0.0, (sum, seat) => sum + seat.price);
  }

  /// Lock selected seats in Redis with a 10-minute TTL
  Future<void> _lockSelectedSeatsAndProceed() async {
    if (_selectedSeats.isEmpty) return;

    setState(() => _isLocking = true);

    final seatIds = _selectedSeats.map((s) => s.id).toList();
    final lockResult = await _apiService.lockSeats(_show.id, seatIds, ApiService.sessionId);

    setState(() => _isLocking = false);

    if (lockResult.success) {
      setState(() {
        _activeLockToken = lockResult.lockToken;
      });

      if (mounted) {
        _showCheckoutModal(lockResult.ttlSeconds);
      }
    } else {
      // Conflict: seat already taken
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
                        : 'Selected seat is already locked or booked by someone else!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        // Refresh seat map to reflect conflicting seat
        _selectedSeats.clear();
        _loadSeatMap();
      }
    }
  }

  void _showCheckoutModal(int ttlSeconds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final isDark = ThemeController.isDark(context);
        final activePrimary = AppTheme.getPrimary(isDark);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final seatLabels = _selectedSeats.map((s) => s.label).join(', ');
            final bookingFee = 3.50;
            final grandTotal = _totalPrice + bookingFee;

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 20,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: AppTheme.getSurface(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AppTheme.getSurfaceBorder(isDark), width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Countdown Timer Badge (10-minute TTL)
                    Center(
                      child: CountdownTimerWidget(
                        initialSeconds: ttlSeconds,
                        onTimerExpired: () {
                          Navigator.pop(modalContext);
                          _handleLockExpiry();
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Checkout & Lock Confirmation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seats $seatLabels are held exclusively for you in Redis cache.',
                      style: TextStyle(color: AppTheme.getTextSecondary(isDark), fontSize: 13),
                    ),

                    const SizedBox(height: 20),

                    // Contact fields
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address for Ticket',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 20),
                    Divider(color: AppTheme.getSurfaceBorder(isDark)),
                    const SizedBox(height: 12),

                    // Price Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tickets (${_selectedSeats.length} seats)',
                            style: TextStyle(color: AppTheme.getTextSecondary(isDark))),
                        Text('\$${_totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(isDark),
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Booking Fee & Taxes',
                            style: TextStyle(color: AppTheme.getTextSecondary(isDark))),
                        Text('\$3.50',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.getTextPrimary(isDark),
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: AppTheme.getSurfaceBorder(isDark)),
                    const SizedBox(height: 12),
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
                          '\$${grandTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: activePrimary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Confirm Booking Action
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activePrimary,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                        ),
                        onPressed: _isBooking
                            ? null
                            : () async {
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
                            : const Text('Confirm & Pay Now'),
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
      // If modal was dismissed without booking confirmation, release Redis locks
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
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Go back to movie details
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);
    final activePrimary = AppTheme.getPrimary(isDark);
    final timeFormat = DateFormat('EEE, MMM d • h:mm a');

    return Scaffold(
      backgroundColor: AppTheme.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.getSurface(isDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_movie.title} (${_movie.rating})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(isDark),
              ),
            ),
            Text(
              '${_show.theatreName} • ${timeFormat.format(_show.startTime)}',
              style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(isDark)),
            ),
          ],
        ),
        actions: [
          // Theme Toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: activePrimary,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Bright Mode' : 'Switch to Dark Mode',
            onPressed: () {
              ThemeController.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Seat Map',
            onPressed: _loadSeatMap,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: activePrimary))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

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

                        const SizedBox(height: 24),

                        // Seat Legend
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _buildLegendItem(
                                isDark ? AppTheme.darkSeatAvailable : AppTheme.lightSeatAvailable,
                                'Available',
                                isDark: isDark,
                              ),
                              _buildLegendItem(
                                AppTheme.seatSelected,
                                'Selected',
                                isDark: isDark,
                              ),
                              _buildLegendItem(
                                AppTheme.seatLocked,
                                'Locked (Redis)',
                                icon: Icons.lock_clock,
                                isDark: isDark,
                              ),
                              _buildLegendItem(
                                isDark ? AppTheme.darkSeatBooked : AppTheme.lightSeatBooked,
                                'Booked',
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Divider(color: AppTheme.getSurfaceBorder(isDark)),
                        const SizedBox(height: 16),

                        // Interactive Seat Matrix
                        if (_seatMap != null) _buildSeatGrid(isDark),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Floating Checkout Bottom Tray
                _buildBottomTray(isDark, activePrimary),
              ],
            ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {IconData? icon, required bool isDark}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          ),
          child: icon != null
              ? Icon(icon, size: 10, color: Colors.white70)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.getTextSecondary(isDark)),
        ),
      ],
    );
  }

  Widget _buildSeatGrid(bool isDark) {
    final seatsByRow = _seatMap!.seatsByRow;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: seatsByRow.entries.map((entry) {
          final rowName = entry.key;
          final seats = entry.value;

          final bool isTierStart = rowName == 'A' || rowName == 'C' || rowName == 'E';
          final tier = (rowName == 'A' || rowName == 'B')
              ? 'VIP Recliners (\$24.00)'
              : (rowName == 'C' || rowName == 'D')
                  ? 'Premium (\$18.00)'
                  : 'Standard (\$14.00)';

          return Column(
            children: [
              if (isTierStart)
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.getSurfaceBorder(isDark))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          tier.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextMuted(isDark),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.getSurfaceBorder(isDark))),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Row Name Left
                    SizedBox(
                      width: 24,
                      child: Text(
                        rowName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.getTextMuted(isDark),
                        ),
                      ),
                    ),

                    // Left Seats (1-5)
                    ...seats.take(5).map((seat) {
                      return SeatWidget(
                        seat: seat,
                        onTap: () => _toggleSeat(seat),
                      );
                    }),

                    // Aisle Gap
                    const SizedBox(width: 16),

                    // Right Seats (6-10)
                    ...seats.skip(5).map((seat) {
                      return SeatWidget(
                        seat: seat,
                        onTap: () => _toggleSeat(seat),
                      );
                    }),

                    // Row Name Right
                    SizedBox(
                      width: 24,
                      child: Text(
                        rowName,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.getTextMuted(isDark),
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
    );
  }

  Widget _buildBottomTray(bool isDark, Color activePrimary) {
    final seatCount = _selectedSeats.length;
    final seatNames = _selectedSeats.map((s) => s.label).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.getSurface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppTheme.getSurfaceBorder(isDark))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Selection summary
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seatCount > 0
                        ? '$seatCount ${seatCount == 1 ? "Seat" : "Seats"} ($seatNames)'
                        : 'Select your seats',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.getTextSecondary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: activePrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Lock & Proceed Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: activePrimary,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              onPressed: seatCount > 0 && !_isLocking ? _lockSelectedSeatsAndProceed : null,
              child: _isLocking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : const Text('Lock Seats & Pay'),
            ),
          ],
        ),
      ),
    );
  }
}
