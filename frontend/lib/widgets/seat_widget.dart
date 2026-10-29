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
        seatBg = AppTheme.getSeatSelected(isDark);
        borderColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0047BA);
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
          // Bright / Light mode colors (Blue & White palette)
          if (seat.seatType == 'VIP') {
            seatBg = const Color(0xFFE8F1FC); // soft sky-ice blue
            borderColor = const Color(0xFF0062FF);
          } else if (seat.seatType == 'PREMIUM') {
            seatBg = const Color(0xFFF0F6FF); // light ice blue
            borderColor = const Color(0xFF70B6FF);
          } else {
            seatBg = Colors.white; // crisp white
            borderColor = const Color(0xFFCFE0F8);
          }
        }
        break;
    }

    final tooltipMsg = '${seat.label} • ${seat.seatType} • \$${seat.price.toStringAsFixed(2)}'
        '${seat.status == SeatStatusType.locked ? ' (Locked in checkout)' : ''}'
        '${seat.status == SeatStatusType.booked ? ' (Sold)' : ''}';

    Color textColor;
    if (seat.status == SeatStatusType.selected) {
      textColor = Colors.white;
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
        splashColor: AppTheme.getSeatSelected(isDark).withValues(alpha: 0.3),
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
                      color: AppTheme.getSeatSelected(isDark).withValues(alpha: 0.45),
                      blurRadius: 10,
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
