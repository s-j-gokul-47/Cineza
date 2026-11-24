import 'package:flutter/material.dart';

Widget buildTrailerView({
  required String youtubeId,
  required VoidCallback onClose,
}) {
  return Container(
    color: Colors.black,
    child: Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_rounded, color: Colors.white, size: 42),
              const SizedBox(height: 10),
              Text(
                'Trailer streaming ($youtubeId)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close Trailer',
          ),
        ),
      ],
    ),
  );
}
