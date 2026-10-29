import 'package:flutter/material.dart';
import '../models/seat.dart';
import '../theme/app_theme.dart';

/// Innovative Cinema Armchair Widget
/// Replaces generic square boxes with an authentic, sculpted cinema chair:
/// - Curved ergonomic headrest / backrest pillow with stitching
/// - Flanking left & right armrests
/// - Contoured seat cushion with tactile elevation
/// - Distinct VIP Recliner, Premium Club, and Standard Chair styling
/// - Luminous Stitch Cobalt Blue aura when selected
class SeatWidget extends StatefulWidget {
  final SeatModel seat;
  final VoidCallback onTap;

  const SeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
  });

  @override
  State<SeatWidget> createState() => _SeatWidgetState();
}

class _SeatWidgetState extends State<SeatWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);
    final seat = widget.seat;
    final isSelected = seat.status == SeatStatusType.selected;
    final isLocked = seat.status == SeatStatusType.locked;
    final isBooked = seat.status == SeatStatusType.booked;
    final isAvailable = seat.status == SeatStatusType.available;

    final isVIP = seat.seatType.toUpperCase() == 'VIP';
    final isPremium = seat.seatType.toUpperCase() == 'PREMIUM';

    // Tier-specific dimensions for realistic stadium perspective
    final double chairWidth = isVIP ? 32.0 : (isPremium ? 29.0 : 27.0);
    final double headrestWidth = isVIP ? 24.0 : (isPremium ? 22.0 : 20.0);
    final double headrestHeight = isVIP ? 8.0 : 7.0;
    final double cushionWidth = isVIP ? 23.0 : (isPremium ? 21.0 : 19.0);
    final double cushionHeight = isVIP ? 20.0 : 18.0;
    final double armrestHeight = isVIP ? 16.0 : 14.5;
    final double armrestWidth = isVIP ? 3.5 : 3.0;

    // Palette & Gradients
    Color headrestBg;
    Color cushionBg;
    Gradient? cushionGradient;
    Color armrestBg;
    Color borderColor;
    Color armrestBorder;
    Color textColor;
    IconData? overlayIcon;
    bool isClickable = true;

    final activeBlue = AppTheme.getSeatSelected(isDark); // #18A0FB (dark) / #0062FF (light)
    final blueGlow = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    if (isSelected) {
      headrestBg = isDark ? const Color(0xFF18A0FB) : const Color(0xFF0062FF);
      cushionGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [const Color(0xFF38BDF8), const Color(0xFF0052CC)]
            : [const Color(0xFF2563EB), const Color(0xFF0047BA)],
      );
      cushionBg = activeBlue;
      armrestBg = isDark ? const Color(0xFF0284C7) : const Color(0xFF0047BA);
      borderColor = blueGlow;
      armrestBorder = blueGlow;
      textColor = Colors.white;
    } else if (isLocked) {
      headrestBg = const Color(0xFFEA580C);
      cushionBg = AppTheme.seatLocked;
      armrestBg = const Color(0xFFC2410C);
      borderColor = Colors.deepOrangeAccent;
      armrestBorder = Colors.deepOrangeAccent;
      overlayIcon = Icons.lock_clock_rounded;
      textColor = Colors.white;
      isClickable = false;
    } else if (isBooked) {
      headrestBg = isDark ? const Color(0xFF141722) : const Color(0xFFE2E8F0);
      cushionBg = isDark ? const Color(0xFF10131B) : const Color(0xFFEDF2F7);
      armrestBg = isDark ? const Color(0xFF0D0F16) : const Color(0xFFCBD5E1);
      borderColor = isDark ? const Color(0xFF232734) : const Color(0xFFCBD5E1);
      armrestBorder = isDark ? const Color(0xFF1D212C) : const Color(0xFFCBD5E1);
      textColor = isDark ? Colors.white24 : Colors.black26;
      isClickable = false;
    } else {
      // Available State
      if (isDark) {
        if (isVIP) {
          headrestBg = const Color(0xFF2D2319);
          cushionBg = const Color(0xFF231A12);
          armrestBg = const Color(0xFF33271C);
          borderColor = AppTheme.goldAccent.withValues(alpha: 0.85);
          armrestBorder = AppTheme.goldAccent.withValues(alpha: 0.6);
          textColor = const Color(0xFFFFE082);
        } else if (isPremium) {
          headrestBg = const Color(0xFF132338);
          cushionBg = const Color(0xFF0F1A2A);
          armrestBg = const Color(0xFF192F4A);
          borderColor = AppTheme.cyanAccent.withValues(alpha: 0.7);
          armrestBorder = AppTheme.cyanAccent.withValues(alpha: 0.5);
          textColor = const Color(0xFF7DD3FC);
        } else {
          headrestBg = const Color(0xFF1A1F2C);
          cushionBg = const Color(0xFF151924);
          armrestBg = const Color(0xFF1D2230);
          borderColor = AppTheme.darkSeatAvailableBorder;
          armrestBorder = const Color(0xFF374151);
          textColor = AppTheme.darkTextSecondary;
        }
      } else {
        // Light / Bright Mode
        if (isVIP) {
          headrestBg = const Color(0xFFFFFBEB);
          cushionGradient = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF5), Color(0xFFFEF3C7)],
          );
          cushionBg = const Color(0xFFFEF3C7);
          armrestBg = const Color(0xFFFDE68A);
          borderColor = const Color(0xFFD97706);
          armrestBorder = const Color(0xFFF59E0B);
          textColor = const Color(0xFF92400E);
        } else if (isPremium) {
          headrestBg = const Color(0xFFF0F7FF);
          cushionGradient = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0EFFF)],
          );
          cushionBg = const Color(0xFFE0EFFF);
          armrestBg = const Color(0xFFBAE6FD);
          borderColor = const Color(0xFF0284C7);
          armrestBorder = const Color(0xFF38BDF8);
          textColor = const Color(0xFF0369A1);
        } else {
          headrestBg = Colors.white;
          cushionGradient = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF1F5F9)],
          );
          cushionBg = const Color(0xFFF8FAFC);
          armrestBg = const Color(0xFFF1F5F9);
          borderColor = const Color(0xFF94A3B8);
          armrestBorder = const Color(0xFFCBD5E1);
          textColor = const Color(0xFF1E293B);
        }
      }
    }

    final currencySymbol = seat.price >= 100 ? '₹' : '\$';
    final priceStr = seat.price >= 100 ? seat.price.toInt().toString() : seat.price.toStringAsFixed(2);
    final tooltipMsg = '${seat.label} • ${seat.seatType} • $currencySymbol$priceStr'
        '${isLocked ? ' (Held in checkout)' : ''}'
        '${isBooked ? ' (Sold)' : ''}';

    final double scale = isSelected ? 1.08 : (_isHovered && isClickable ? 1.04 : 1.0);

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        onEnter: (_) {
          if (isClickable) setState(() => _isHovered = true);
        },
        onExit: (_) {
          if (isClickable) setState(() => _isHovered = false);
        },
        cursor: isClickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: isClickable ? widget.onTap : null,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Container(
              width: chairWidth,
              margin: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Curved Headrest / Backrest Cushion
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: headrestWidth,
                    height: headrestHeight,
                    decoration: BoxDecoration(
                      color: headrestBg,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                        bottom: Radius.circular(2),
                      ),
                      border: Border.all(
                        color: borderColor,
                        width: isSelected ? 1.6 : 1.1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: activeBlue.withValues(alpha: 0.5),
                                blurRadius: 6,
                                offset: const Offset(0, -1),
                              ),
                            ]
                          : null,
                    ),
                    child: isVIP && !isSelected && isAvailable
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 1.5,
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.goldAccent : const Color(0xFFD97706),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(height: 1.5),

                  // 2. Main Seat Cushion with Armrests
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left Armrest
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: armrestWidth,
                        height: armrestHeight,
                        decoration: BoxDecoration(
                          color: armrestBg,
                          borderRadius: BorderRadius.circular(2.5),
                          border: Border.all(
                            color: armrestBorder,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: activeBlue.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(-1, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),

                      const SizedBox(width: 1.5),

                      // Center Seat Cushion
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: cushionWidth,
                        height: cushionHeight,
                        decoration: BoxDecoration(
                          color: cushionBg,
                          gradient: cushionGradient,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2),
                            bottom: Radius.circular(6),
                          ),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected ? 1.8 : 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: activeBlue.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                    spreadRadius: 1.5,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : (_isHovered && isClickable
                                  ? [
                                      BoxShadow(
                                        color: borderColor.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null),
                        ),
                        child: Center(
                          child: overlayIcon != null
                              ? Icon(overlayIcon, size: 11, color: Colors.white)
                              : Text(
                                  seat.seatNumber.toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                    color: textColor,
                                    height: 1.0,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(width: 1.5),

                      // Right Armrest
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: armrestWidth,
                        height: armrestHeight,
                        decoration: BoxDecoration(
                          color: armrestBg,
                          borderRadius: BorderRadius.circular(2.5),
                          border: Border.all(
                            color: armrestBorder,
                            width: isSelected ? 1.2 : 0.8,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: activeBlue.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(1, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
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
}
