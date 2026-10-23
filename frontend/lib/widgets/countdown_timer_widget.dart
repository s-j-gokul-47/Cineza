import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CountdownTimerWidget extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onTimerExpired;

  const CountdownTimerWidget({
    super.key,
    required this.initialSeconds,
    required this.onTimerExpired,
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
        widget.onTimerExpired();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isLowTime = _remainingSeconds < 120; // Under 2 mins

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isLowTime
            ? AppTheme.danger.withOpacity(0.15)
            : AppTheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLowTime ? AppTheme.danger : AppTheme.primary,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 20,
            color: isLowTime ? AppTheme.danger : AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Seats locked for checkout: ',
            style: TextStyle(
              fontSize: 13,
              color: isLowTime ? AppTheme.danger : AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formattedTime,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: isLowTime ? AppTheme.danger : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
