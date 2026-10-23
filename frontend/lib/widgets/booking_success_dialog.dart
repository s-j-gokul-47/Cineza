import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking_response.dart';
import '../theme/app_theme.dart';

class BookingSuccessDialog extends StatelessWidget {
  final BookingReceipt receipt;
  final VoidCallback onDone;

  const BookingSuccessDialog({
    super.key,
    required this.receipt,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);
    final activePrimary = AppTheme.getPrimary(isDark);
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AppTheme.getSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: activePrimary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: activePrimary.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header Ribbon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    activePrimary.withValues(alpha: 0.25),
                    AppTheme.accent.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activePrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activePrimary.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.black, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Confirmed!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.getTextPrimary(isDark),
                          ),
                        ),
                        Text(
                          'Ref: ${receipt.bookingReference}',
                          style: TextStyle(
                            fontSize: 13,
                            color: activePrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ticket Body
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.movieTitle,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: AppTheme.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${receipt.theatreName} • ${receipt.screenName}',
                    style: TextStyle(
                      color: AppTheme.getTextSecondary(isDark),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: activePrimary),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(receipt.showTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.getTextPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.getSurfaceBorder(isDark)),
                  const SizedBox(height: 12),

                  // Seats and Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SEATS',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: receipt.seatLabels
                                .map(
                                  (label) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: activePrimary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: activePrimary, width: 1),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: activePrimary,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TOTAL PAID',
                            style: TextStyle(
                              color: AppTheme.getTextMuted(isDark),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${receipt.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: activePrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Barcode Mockup
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.getSurfaceBorder(isDark)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            36,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: (index % 4 == 0) ? 3.5 : (index % 3 == 0 ? 1.5 : 2.5),
                              height: 38,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          receipt.bookingReference,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.0,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onDone,
                      child: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
