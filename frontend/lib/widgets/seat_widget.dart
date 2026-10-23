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
    Color seatBg;
    Color borderColor;
    IconData? overlayIcon;
    bool isClickable = true;

    switch (seat.status) {
      case SeatStatusType.selected:
        seatBg = AppTheme.seatSelected;
        borderColor = AppTheme.primaryGlow;
        break;
      case SeatStatusType.locked:
        seatBg = AppTheme.seatLocked;
        borderColor = Colors.deepOrangeAccent;
        overlayIcon = Icons.lock_clock_rounded;
        isClickable = false;
        break;
      case SeatStatusType.booked:
        seatBg = AppTheme.seatBooked;
        borderColor = Colors.white10;
        isClickable = false;
        break;
      case SeatStatusType.available:
        if (seat.seatType == 'VIP') {
          seatBg = const Color(0xFF2E2440);
          borderColor = AppTheme.accent.withOpacity(0.5);
        } else if (seat.seatType == 'PREMIUM') {
          seatBg = const Color(0xFF222B38);
          borderColor = AppTheme.cyanAccent.withOpacity(0.4);
        } else {
          seatBg = AppTheme.seatAvailable;
          borderColor = AppTheme.seatAvailableBorder;
        }
        break;
    }

    final tooltipMsg = '${seat.label} • ${seat.seatType} • \$${seat.price.toStringAsFixed(2)}'
        '${seat.status == SeatStatusType.locked ? ' (Locked in checkout)' : ''}'
        '${seat.status == SeatStatusType.booked ? ' (Sold)' : ''}';

    return Tooltip(
      message: tooltipMsg,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        splashColor: AppTheme.primary.withOpacity(0.3),
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
                      color: AppTheme.primary.withOpacity(0.4),
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
                    color: Colors.white70,
                  )
                : Text(
                    seat.seatNumber.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: seat.status == SeatStatusType.selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: seat.status == SeatStatusType.selected
                          ? Colors.black87
                          : (seat.status == SeatStatusType.booked
                              ? Colors.white24
                              : AppTheme.textPrimary),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
