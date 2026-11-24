import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../config/app_config.dart';

final Set<String> _registeredTrailerViewTypes = {};

Widget buildTrailerView({
  required String youtubeId,
  required VoidCallback onClose,
}) {
  final String viewType = 'cinema-trailer-$youtubeId';

  if (!_registeredTrailerViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src =
              '${AppConfig.trailerEmbedBaseUrl}/$youtubeId?autoplay=1&mute=0&controls=1&rel=0&modestbranding=1&playsinline=1'
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000000'
          ..style.display = 'block'
          ..style.borderRadius = '8px'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
          ..allowFullscreen = true;
        return iframe;
      },
    );
    _registeredTrailerViewTypes.add(viewType);
  }

  return Stack(
    children: [
      Positioned.fill(
        child: HtmlElementView(viewType: viewType),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Close Trailer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
