import 'package:flutter/material.dart';
import '../models/seat.dart';
import '../theme/app_theme.dart';

class SeatWidget extends StatelessWidget {
  final SeatModel seat;
  final VoidCallback onTap;

  const SeatWidget({
    super.key,
    required this.seat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);

    Color seatBg;
    Color borderColor;
    IconData? overlayIcon;
    bool isClickable = true;

    switch (seat.status) {
      case SeatStatusType.selected:
        seatBg = AppTheme.seatSelected;
        borderColor = isDark ? AppTheme.primaryGlow : AppTheme.lightPrimary;
        break;
      case SeatStatusType.locked:
        seatBg = AppTheme.seatLocked;
        borderColor = Colors.deepOrangeAccent;
        overlayIcon = Icons.lock_clock_rounded;
        isClickable = false;
        break;
      case SeatStatusType.booked:
        seatBg = isDark ? AppTheme.darkSeatBooked : AppTheme.lightSeatBooked;
        borderColor = isDark ? Colors.white10 : Colors.black12;
        isClickable = false;
        break;
      case SeatStatusType.available:
        if (isDark) {
          if (seat.seatType == 'VIP') {
            seatBg = const Color(0xFF2E2440);
            borderColor = AppTheme.accent.withValues(alpha: 0.5);
          } else if (seat.seatType == 'PREMIUM') {
            seatBg = const Color(0xFF222B38);
            borderColor = AppTheme.cyanAccent.withValues(alpha: 0.4);
          } else {
            seatBg = AppTheme.darkSeatAvailable;
            borderColor = AppTheme.darkSeatAvailableBorder;
          }
        } else {
          // Bright / Light mode colors
          if (seat.seatType == 'VIP') {
            seatBg = const Color(0xFFF3E8FF); // soft purple
            borderColor = const Color(0xFFC084FC);
          } else if (seat.seatType == 'PREMIUM') {
            seatBg = const Color(0xFFE0F2FE); // soft sky blue
            borderColor = const Color(0xFF7DD3FC);
          } else {
            seatBg = const Color(0xFFF1F5F9); // slate 100
            borderColor = const Color(0xFFCBD5E1);
          }
        }
        break;
    }

    final tooltipMsg = '${seat.label} • ${seat.seatType} • \$${seat.price.toStringAsFixed(2)}'
        '${seat.status == SeatStatusType.locked ? ' (Locked in checkout)' : ''}'
        '${seat.status == SeatStatusType.booked ? ' (Sold)' : ''}';

    Color textColor;
    if (seat.status == SeatStatusType.selected) {
      textColor = Colors.black87;
    } else if (seat.status == SeatStatusType.booked) {
      textColor = isDark ? Colors.white24 : Colors.black26;
    } else {
      textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    }

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        splashColor: AppTheme.primary.withValues(alpha: 0.3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 30,
          height: 30,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: seatBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: borderColor,
              width: seat.status == SeatStatusType.selected ? 2 : 1,
            ),
            boxShadow: seat.status == SeatStatusType.selected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: overlayIcon != null
                ? Icon(
                    overlayIcon,
                    size: 14,
                    color: Colors.white,
                  )
                : Text(
                    seat.seatNumber.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: seat.status == SeatStatusType.selected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
