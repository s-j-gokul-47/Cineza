import 'package:flutter/material.dart';
import 'trailer_player_stub.dart'
    if (dart.library.html) 'trailer_player_web.dart';

class TrailerPlayerView extends StatelessWidget {
  final String youtubeId;
  final VoidCallback onClose;

  const TrailerPlayerView({
    super.key,
    required this.youtubeId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return buildTrailerView(
      youtubeId: youtubeId,
      onClose: onClose,
    );
  }
}
