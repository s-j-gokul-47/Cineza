import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/seat.dart';
import '../theme/app_theme.dart';
import 'trailer_player_view.dart';

/// 3D Vector mathematical helper for camera perspective projection
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  Vec3 get norm {
    final l = length;
    return l > 0 ? Vec3(x / l, y / l, z / l) : const Vec3(0, 0, 0);
  }
}

/// Camera state for orbital navigation and preset transitions
class CameraState {
  final double yaw; // rotation around vertical axis (radians)
  final double pitch; // elevation angle (radians)
  final double distance; // zoom factor relative to base distance
  final Vec3 target; // target focus point in 3D world space

  const CameraState({
    required this.yaw,
    required this.pitch,
    required this.distance,
    required this.target,
  });

  CameraState copyWith({
    double? yaw,
    double? pitch,
    double? distance,
    Vec3? target,
  }) {
    return CameraState(
      yaw: yaw ?? this.yaw,
      pitch: pitch ?? this.pitch,
      distance: distance ?? this.distance,
      target: target ?? this.target,
    );
  }

  static CameraState lerp(CameraState a, CameraState b, double t) {
    return CameraState(
      yaw: ui.lerpDouble(a.yaw, b.yaw, t) ?? a.yaw,
      pitch: ui.lerpDouble(a.pitch, b.pitch, t) ?? a.pitch,
      distance: ui.lerpDouble(a.distance, b.distance, t) ?? a.distance,
      target: Vec3(
        ui.lerpDouble(a.target.x, b.target.x, t) ?? a.target.x,
        ui.lerpDouble(a.target.y, b.target.y, t) ?? a.target.y,
        ui.lerpDouble(a.target.z, b.target.z, t) ?? a.target.z,
      ),
    );
  }
}

/// Internal data class representing a seat in 3D world space
class Seat3D {
  final SeatModel model;
  final Vec3 position; // world coordinates
  final double width;
  final double height;
  final double depth;
  final String tier; // 'ROYAL', 'BALCONY', 'PRIME', 'CLASSIC'
  final Color baseColor;

  Seat3D({
    required this.model,
    required this.position,
    required this.width,
    required this.height,
    required this.depth,
    required this.tier,
    required this.baseColor,
  });
}

/// Projected polygon in 2D screen space with calculated camera depth for z-sorting
class ProjectedSeat {
  final Seat3D seat;
  final Rect screenBounds;
  final Path cushionPath;
  final Path backrestPath;
  final Path headrestPath;
  final double cameraDepth;
  final bool isSelected;
  final bool isHovered;

  ProjectedSeat({
    required this.seat,
    required this.screenBounds,
    required this.cushionPath,
    required this.backrestPath,
    required this.headrestPath,
    required this.cameraDepth,
    required this.isSelected,
    required this.isHovered,
  });
}

/// Calculated 2D projected screen geometry for click detection & video player overlay
class ProjectedScreenInfo {
  final Path? path;
  final Rect? bounds;
  final Matrix4? transformMatrix;
  final bool isFacingCamera;
  final Offset? topLeft;
  final Offset? topRight;
  final Offset? bottomRight;
  final Offset? bottomLeft;

  const ProjectedScreenInfo({
    this.path,
    this.bounds,
    this.transformMatrix,
    this.isFacingCamera = false,
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  });
}

/// Projective mapping (homography) from a rectangle [0, 0, width, height] to an arbitrary 2D quad (p0, p1, p2, p3)
Matrix4? rectToQuadMatrix({
  required double width,
  required double height,
  required Offset p0,
  required Offset p1,
  required Offset p2,
  required Offset p3,
}) {
  final dx1 = p1.dx - p2.dx;
  final dy1 = p1.dy - p2.dy;
  final dx2 = p3.dx - p2.dx;
  final dy2 = p3.dy - p2.dy;
  final sx = p0.dx - p1.dx + p2.dx - p3.dx;
  final sy = p0.dy - p1.dy + p2.dy - p3.dy;

  double a, b, c, d, e, f, g, h;

  if (sx.abs() < 1e-5 && sy.abs() < 1e-5) {
    a = (p1.dx - p0.dx) / width;
    b = (p3.dx - p0.dx) / height;
    c = p0.dx;
    d = (p1.dy - p0.dy) / width;
    e = (p3.dy - p0.dy) / height;
    f = p0.dy;
    g = 0.0;
    h = 0.0;
  } else {
    final denom = dx1 * dy2 - dx2 * dy1;
    if (denom.abs() < 1e-6) return null;
    final gRaw = (sx * dy2 - sy * dx2) / denom;
    final hRaw = (dx1 * sy - dy1 * sx) / denom;
    a = (p1.dx - p0.dx + gRaw * p1.dx) / width;
    b = (p3.dx - p0.dx + hRaw * p3.dx) / height;
    c = p0.dx;
    d = (p1.dy - p0.dy + gRaw * p1.dy) / width;
    e = (p3.dy - p0.dy + hRaw * p3.dy) / height;
    f = p0.dy;
    g = gRaw / width;
    h = hRaw / height;
  }

  final m = Matrix4.zero();
  m.setEntry(0, 0, a);
  m.setEntry(0, 1, b);
  m.setEntry(0, 3, c);

  m.setEntry(1, 0, d);
  m.setEntry(1, 1, e);
  m.setEntry(1, 3, f);

  m.setEntry(2, 2, 1.0);

  m.setEntry(3, 0, g);
  m.setEntry(3, 1, h);
  m.setEntry(3, 3, 1.0);

  return m;
}

/// Next-Generation 3D Cinema Hall Seating View
/// Features interactive orbit, presets (Overview, From stage, Balcony, Bird's eye, Tour, Seat POV),
/// house lights toggle, HD screen glow, realistic tiered amphitheatre layout, and sweet-spot auto picker.
class CinemaHall3DView extends StatefulWidget {
  final ShowSeatMap seatMap;
  final Set<SeatModel> selectedSeats;
  final ValueChanged<SeatModel> onSeatTapped;
  final String movieTitle;
  final String? movieBackdropUrl;
  final String? trailerYoutubeId;
  final bool houseLights;
  final bool isHd;
  final SeatModel? povSeat;
  final VoidCallback onResetPov;

  const CinemaHall3DView({
    super.key,
    required this.seatMap,
    required this.selectedSeats,
    required this.onSeatTapped,
    required this.movieTitle,
    this.movieBackdropUrl,
    this.trailerYoutubeId,
    this.houseLights = false,
    this.isHd = true,
    this.povSeat,
    required this.onResetPov,
  });

  @override
  State<CinemaHall3DView> createState() => _CinemaHall3DViewState();
}

class _CinemaHall3DViewState extends State<CinemaHall3DView>
    with TickerProviderStateMixin {
  // Camera presets
  static const CameraState presetOverview = CameraState(
    yaw: 0.0,
    pitch: 0.40,
    distance: 1.0,
    target: Vec3(0, 90, 260),
  );

  static const CameraState presetFromStage = CameraState(
    yaw: math.pi,
    pitch: 0.18,
    distance: 0.90,
    target: Vec3(0, 140, 420),
  );

  static const CameraState presetBalcony = CameraState(
    yaw: 0.0,
    pitch: 0.58,
    distance: 1.25,
    target: Vec3(0, 80, 180),
  );

  static const CameraState presetBirdsEye = CameraState(
    yaw: 0.0,
    pitch: 1.45,
    distance: 1.2,
    target: Vec3(0, 0, 360),
  );

  String _currentPreset = 'Overview';
  late CameraState _camera;
  late CameraState _animStartCamera;
  late CameraState _animEndCamera;
  late AnimationController _cameraAnimController;
  late Animation<double> _cameraAnim;

  // Tour mode animation
  AnimationController? _tourController;
  bool _isTourActive = false;

  // Hovered seat
  SeatModel? _hoveredSeat;
  Offset? _hoverPos;

  // Interactive drag state
  Offset? _lastDragPos;

  // Generated 3D seat mesh cache
  final List<Seat3D> _seats3D = [];
  bool _meshBuilt = false;

  // Trailer Playback & Screen Hover State
  bool _isPlayingTrailer = false;
  bool _isHoveringScreen = false;

  static ProjectedScreenInfo calculateScreenProjection({
    required Size size,
    required CameraState camera,
  }) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return const ProjectedScreenInfo();
    final double cx = w / 2;
    final double cy = h / 2;

    const double baseDistance = 780.0;
    final double dist = baseDistance * camera.distance;
    final double eyeX =
        camera.target.x + dist * math.sin(camera.yaw) * math.cos(camera.pitch);
    final double eyeY = camera.target.y + dist * math.sin(camera.pitch);
    final double eyeZ =
        camera.target.z + dist * math.cos(camera.yaw) * math.cos(camera.pitch);

    final Vec3 eye = Vec3(eyeX, eyeY, eyeZ);
    final Vec3 target = camera.target;
    final Vec3 fwd = (target - eye).norm;
    const Vec3 worldUp = Vec3(0, 1, 0);
    final Vec3 right = fwd.cross(worldUp).norm;
    final Vec3 camUp = right.cross(fwd).norm;
    final double fl = math.min(w, h) * 1.15;

    Offset? project(Vec3 p) {
      final v = p - eye;
      final vz = v.dot(fwd);
      if (vz <= 20.0) return null;
      final vx = v.dot(right);
      final vy = v.dot(camUp);
      return Offset(cx + (vx / vz) * fl, cy - (vy / vz) * fl);
    }

    // True 16:9 Cinema Screen Dimensions matching movie trailers
    const double screenW = 460.0;
    const double screenH = 258.75; // 460 / (16/9)
    const double screenY = 270.0;
    const double screenZ = 10.0;
    const double screenCurve = 32.0;
    const int segments = 16;
    final List<Offset> topPoints = [];
    final List<Offset> bottomPoints = [];

    for (int i = 0; i <= segments; i++) {
      final double frac = i / segments;
      final double x = -screenW / 2 + frac * screenW;
      final double z = screenZ - (1.0 - math.pow(x / (screenW / 2), 2)) * screenCurve;
      final top = project(Vec3(x, screenY, z));
      final bot = project(Vec3(x, screenY - screenH, z));
      if (top != null && bot != null) {
        topPoints.add(top);
        bottomPoints.add(bot);
      }
    }

    if (topPoints.length == segments + 1 && bottomPoints.length == segments + 1) {
      final screenPath = Path()..moveTo(topPoints.first.dx, topPoints.first.dy);
      for (final p in topPoints) {
        screenPath.lineTo(p.dx, p.dy);
      }
      for (int i = bottomPoints.length - 1; i >= 0; i--) {
        screenPath.lineTo(bottomPoints[i].dx, bottomPoints[i].dy);
      }
      screenPath.close();

      final pTL = topPoints.first;
      final pTR = topPoints.last;
      final pBR = bottomPoints.last;
      final pBL = bottomPoints.first;

      // Check if screen is facing the camera (positive 2D signed cross product)
      final double cross =
          (pTR.dx - pTL.dx) * (pBR.dy - pTL.dy) - (pTR.dy - pTL.dy) * (pBR.dx - pTL.dx);
      final bool isFacingCamera = cross > 50.0;

      Matrix4? transformMatrix;
      if (isFacingCamera) {
        transformMatrix = rectToQuadMatrix(
          width: 640.0,
          height: 360.0,
          p0: pTL,
          p1: pTR,
          p2: pBR,
          p3: pBL,
        );
      }

      return ProjectedScreenInfo(
        path: screenPath,
        bounds: screenPath.getBounds(),
        transformMatrix: transformMatrix,
        isFacingCamera: isFacingCamera,
        topLeft: pTL,
        topRight: pTR,
        bottomRight: pBR,
        bottomLeft: pBL,
      );
    }
    return const ProjectedScreenInfo();
  }

  @override
  void initState() {
    super.initState();
    _camera = presetOverview;

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cameraAnim = CurvedAnimation(
      parent: _cameraAnimController,
      curve: Curves.easeInOutCubic,
    )..addListener(() {
        setState(() {
          _camera = CameraState.lerp(
            _animStartCamera,
            _animEndCamera,
            _cameraAnim.value,
          );
        });
      });

    _tourController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..addListener(() {
        if (_isTourActive) {
          final t = _tourController!.value * math.pi * 2;
          final yaw = math.sin(t) * 0.45;
          final pitch = 0.32 + math.sin(t * 2) * 0.12;
          final dist = 0.95 + math.cos(t) * 0.18;
          setState(() {
            _camera = CameraState(
              yaw: yaw,
              pitch: pitch,
              distance: dist,
              target: const Vec3(0, 100, 280),
            );
          });
        }
      });

    _build3DSeats();
  }

  @override
  void didUpdateWidget(covariant CinemaHall3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seatMap != widget.seatMap) {
      _meshBuilt = false;
      _build3DSeats();
    }
    if (widget.povSeat != oldWidget.povSeat && widget.povSeat != null) {
      _flyToSeatPov(widget.povSeat!);
    }
  }

  @override
  void dispose() {
    _cameraAnimController.dispose();
    _tourController?.dispose();
    super.dispose();
  }

  void _build3DSeats() {
    if (_meshBuilt) return;
    _seats3D.clear();

    final seatsByRow = widget.seatMap.seatsByRow;
    final rowKeys = seatsByRow.keys.toList();

    // Auditorium tier spacing
    const double rowZStart = 200.0;
    const double rowZSpacing = 68.0;
    const double rowYStep = 18.0; // Stadium seating height increment per row

    for (int r = 0; r < rowKeys.length; r++) {
      final rowName = rowKeys[r];
      final seats = seatsByRow[rowName] ?? [];
      final double rowZ = rowZStart + r * rowZSpacing;
      final double rowY = 8.0 + r * rowYStep;

      // Tier categorization
      String tier = 'CLASSIC';
      Color tierColor = const Color(0xFF3B82F6); // Blue
      if (rowName == 'A' || rowName == 'B') {
        tier = 'ROYAL';
        tierColor = const Color(0xFFEAB308); // Gold
      } else if (rowName == 'C' || rowName == 'D') {
        tier = 'BALCONY';
        tierColor = const Color(0xFFA855F7); // Purple
      } else if (rowName == 'E' || rowName == 'F') {
        tier = 'PRIME';
        tierColor = const Color(0xFF10B981); // Emerald Green
      }

      final int totalSeatsInRow = seats.length;
      if (totalSeatsInRow == 0) continue;

      // Split into 3 blocks: Left, Center, Right
      // e.g. 10 seats -> 2 left, 6 center, 2 right
      final int leftCount = (totalSeatsInRow > 6) ? 2 : 1;
      final int rightCount = (totalSeatsInRow > 6) ? 2 : 1;
      final int centerCount = totalSeatsInRow - leftCount - rightCount;

      const double seatWidth = 26.0;
      const double seatSpacing = 6.0;
      const double aisleWidth = 32.0;

      final double centerBlockWidth =
          centerCount * seatWidth + (centerCount - 1) * seatSpacing;
      final double leftBlockWidth =
          leftCount * seatWidth + (leftCount - 1) * seatSpacing;
      final double rightBlockWidth =
          rightCount * seatWidth + (rightCount - 1) * seatSpacing;

      final double totalSpan =
          leftBlockWidth + aisleWidth + centerBlockWidth + aisleWidth + rightBlockWidth;
      final double startX = -totalSpan / 2;

      for (int i = 0; i < totalSeatsInRow; i++) {
        final seat = seats[i];
        double posX;

        if (i < leftCount) {
          // Left block
          posX = startX + i * (seatWidth + seatSpacing) + seatWidth / 2;
        } else if (i < leftCount + centerCount) {
          // Center block
          final cIdx = i - leftCount;
          final centerStartX = startX + leftBlockWidth + aisleWidth;
          posX = centerStartX + cIdx * (seatWidth + seatSpacing) + seatWidth / 2;
        } else {
          // Right block
          final rIdx = i - (leftCount + centerCount);
          final rightStartX =
              startX + leftBlockWidth + aisleWidth + centerBlockWidth + aisleWidth;
          posX = rightStartX + rIdx * (seatWidth + seatSpacing) + seatWidth / 2;
        }

        // Curved row arc effect (outer seats curve subtly toward the screen)
        final double curveOffset = math.pow((posX / (totalSpan / 2)), 2) * -18.0;

        _seats3D.add(Seat3D(
          model: seat,
          position: Vec3(posX, rowY, rowZ + curveOffset),
          width: seatWidth,
          height: 28.0,
          depth: 22.0,
          tier: tier,
          baseColor: tierColor,
        ));
      }
    }

    _meshBuilt = true;
  }

  void _switchPreset(String name, CameraState target) {
    if (_isTourActive) {
      _isTourActive = false;
      _tourController?.stop();
    }
    setState(() {
      _currentPreset = name;
      _animStartCamera = _camera;
      _animEndCamera = target;
    });
    _cameraAnimController.forward(from: 0.0);
  }

  void _toggleTour() {
    if (_isTourActive) {
      _isTourActive = false;
      _tourController?.stop();
      _switchPreset('Overview', presetOverview);
    } else {
      setState(() {
        _isTourActive = true;
        _currentPreset = 'Tour';
      });
      _tourController?.repeat();
    }
  }

  void _flyToSeatPov(SeatModel seat) {
    final match = _seats3D.firstWhere(
      (s) => s.model.id == seat.id,
      orElse: () => _seats3D.first,
    );

    if (_isTourActive) {
      _isTourActive = false;
      _tourController?.stop();
    }

    setState(() {
      _currentPreset = 'Seat ${seat.label}';
      _animStartCamera = _camera;
      // Position camera directly in the seat's position looking at screen center (0, 130, 0)
      _animEndCamera = CameraState(
        yaw: 0.0,
        pitch: -0.15,
        distance: 0.35,
        target: const Vec3(0, 130, 0),
      ).copyWith(
        target: const Vec3(0, 130, 0),
      );
    });
    _cameraAnimController.forward(from: 0.0);
  }

  void _toggleTrailerPlayback() {
    setState(() {
      _isPlayingTrailer = !_isPlayingTrailer;
      if (_isPlayingTrailer) {
        if (_isTourActive) {
          _isTourActive = false;
          _tourController?.stop();
        }
        // Smoothly center camera on Overview so both the screen and all seats are front-and-center
        _switchPreset('Overview', presetOverview);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Ensure 3D seats mesh is built and populated
    if (_seats3D.isEmpty || !_meshBuilt) {
      _meshBuilt = false;
      _build3DSeats();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenInfo = calculateScreenProjection(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          camera: _camera,
        );
        final screenPath = screenInfo.path;
        final screenBounds = screenInfo.bounds;

        return Stack(
          children: [
            // 3D Canvas with Gesture Arena
            Positioned.fill(
              child: MouseRegion(
                cursor: _isHoveringScreen
                    ? SystemMouseCursors.click
                    : (_hoveredSeat != null
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.grab),
                onHover: (event) {
                  final isScreen = screenPath != null &&
                      screenPath.contains(event.localPosition);
                  setState(() {
                    _hoverPos = event.localPosition;
                    _isHoveringScreen = isScreen;
                  });
                },
                onExit: (_) {
                  setState(() {
                    _hoverPos = null;
                    _hoveredSeat = null;
                    _isHoveringScreen = false;
                  });
                },
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      // Zoom on mouse wheel scroll
                      final zoomDelta = pointerSignal.scrollDelta.dy * 0.001;
                      setState(() {
                        _camera = _camera.copyWith(
                          distance: (_camera.distance + zoomDelta).clamp(0.45, 2.2),
                        );
                        _currentPreset = 'Custom';
                      });
                    }
                  },
                  child: GestureDetector(
                    onPanStart: (details) {
                      _lastDragPos = details.localPosition;
                      if (_isTourActive) {
                        _isTourActive = false;
                        _tourController?.stop();
                      }
                    },
                    onPanUpdate: (details) {
                      if (_lastDragPos != null) {
                        final delta = details.localPosition - _lastDragPos!;
                        _lastDragPos = details.localPosition;

                        setState(() {
                          _currentPreset = 'Custom';
                          final double yawLimit = _isPlayingTrailer ? 0.32 : (math.pi * 0.65);
                          final double minPitch = _isPlayingTrailer ? 0.24 : 0.05;
                          final double maxPitch = _isPlayingTrailer ? 0.58 : 1.50;
                          final newYaw = (_camera.yaw - delta.dx * 0.0055)
                              .clamp(-yawLimit, yawLimit);
                          final newPitch = (_camera.pitch + delta.dy * 0.004)
                              .clamp(minPitch, maxPitch);
                          _camera = _camera.copyWith(yaw: newYaw, pitch: newPitch);
                        });
                      }
                    },
                    onPanEnd: (_) => _lastDragPos = null,
                    onTapUp: (details) {
                      if (_hoveredSeat != null) {
                        if (_hoveredSeat!.status != SeatStatusType.booked) {
                          widget.onSeatTapped(_hoveredSeat!);
                        }
                      } else if (screenPath != null &&
                          screenPath.contains(details.localPosition)) {
                        // User clicked directly on the curved cinema screen!
                        _toggleTrailerPlayback();
                      }
                    },
                    child: CustomPaint(
                      painter: _CinemaHall3DPainter(
                        camera: _camera,
                        seats3D: _seats3D,
                        selectedSeats: widget.selectedSeats,
                        hoverPos: _hoverPos,
                        movieTitle: widget.movieTitle,
                        movieBackdropUrl: widget.movieBackdropUrl,
                        trailerYoutubeId: widget.trailerYoutubeId,
                        isPlayingTrailer: _isPlayingTrailer,
                        isHoveringScreen: _isHoveringScreen,
                        houseLights: widget.houseLights,
                        isHd: widget.isHd,
                        isDark: isDark,
                        onHoveredSeatDetected: (seat) {
                          if (_hoveredSeat != seat) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _hoveredSeat = seat);
                            });
                          }
                        },
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),

            // Live Movie Trailer Stream Overlay locked to 3D Cinema Screen
            if (_isPlayingTrailer &&
                screenInfo.transformMatrix != null &&
                screenInfo.isFacingCamera)
              Positioned(
                left: 0,
                top: 0,
                child: Transform(
                  transform: screenInfo.transformMatrix!,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 640.0,
                    height: 360.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF38BDF8),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.8),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: TrailerPlayerView(
                          youtubeId: widget.trailerYoutubeId ?? 'wqXE_es_I3M',
                          onClose: () => setState(() => _isPlayingTrailer = false),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Floating Camera Presets Pill Bar (Top Center)
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPresetPill('Overview', presetOverview),
                        const SizedBox(width: 4),
                        _buildPresetPill('From stage', presetFromStage),
                        const SizedBox(width: 4),
                        _buildPresetPill('Balcony', presetBalcony),
                        const SizedBox(width: 4),
                        _buildPresetPill('Bird\'s eye', presetBirdsEye),
                        const SizedBox(width: 6),
                        // Tour Pill with Play/Stop Icon
                        InkWell(
                          onTap: _toggleTour,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isTourActive
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isTourActive
                                    ? AppTheme.primary
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isTourActive
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 14,
                                  color: _isTourActive ? Colors.black : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tour',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _isTourActive ? Colors.black : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 24 Trailer Action Pill
                        InkWell(
                          onTap: _toggleTrailerPlayback,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: _isPlayingTrailer
                                  ? const LinearGradient(
                                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF0062FF), Color(0xFF00D2FF)],
                                    ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isPlayingTrailer
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF0062FF))
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPlayingTrailer ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isPlayingTrailer ? 'Stop Trailer' : 'Play 24 Trailer',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Left Guidance Overlay & Reset Button
            Positioned(
              left: 16,
              bottom: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'Drag to orbit • scroll to zoom • tap screen to watch trailer',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentPreset == 'Custom' || widget.povSeat != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        widget.onResetPov();
                        _switchPreset('Overview', presetOverview);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.primary),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded,
                                size: 13, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text(
                              'Reset View',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Hover Seat Tooltip Pill
            if (_hoveredSeat != null && _hoverPos != null)
              Positioned(
                left: (_hoverPos!.dx - 60).clamp(16.0, 400.0),
                top: (_hoverPos!.dy - 46).clamp(50.0, 600.0),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hoveredSeat!.status == SeatStatusType.booked
                            ? Colors.redAccent
                            : AppTheme.cyanAccent,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _hoveredSeat!.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 10,
                          color: Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _hoveredSeat!.status == SeatStatusType.booked
                              ? 'BOOKED'
                              : '₹${_hoveredSeat!.price.toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _hoveredSeat!.status == SeatStatusType.booked
                                ? Colors.redAccent
                                : AppTheme.goldAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPresetPill(String title, CameraState state) {
    final bool isActive = _currentPreset == title && !_isTourActive;

    return InkWell(
      onTap: () => _switchPreset(title, state),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            color: isActive ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders the complete 3D auditorium in real-time
class _CinemaHall3DPainter extends CustomPainter {
  final CameraState camera;
  final List<Seat3D> seats3D;
  final Set<SeatModel> selectedSeats;
  final Offset? hoverPos;
  final String movieTitle;
  final String? movieBackdropUrl;
  final String? trailerYoutubeId;
  final bool isPlayingTrailer;
  final bool isHoveringScreen;
  final bool houseLights;
  final bool isHd;
  final bool isDark;
  final ValueChanged<SeatModel?> onHoveredSeatDetected;

  _CinemaHall3DPainter({
    required this.camera,
    required this.seats3D,
    required this.selectedSeats,
    required this.hoverPos,
    required this.movieTitle,
    required this.movieBackdropUrl,
    this.trailerYoutubeId,
    this.isPlayingTrailer = false,
    this.isHoveringScreen = false,
    required this.houseLights,
    required this.isHd,
    required this.isDark,
    required this.onHoveredSeatDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    // 1. Establish Camera Coordinate System
    // Camera Eye calculation from spherical yaw, pitch, distance
    const double baseDistance = 780.0;
    final double dist = baseDistance * camera.distance;
    final double eyeX =
        camera.target.x + dist * math.sin(camera.yaw) * math.cos(camera.pitch);
    final double eyeY = camera.target.y + dist * math.sin(camera.pitch);
    final double eyeZ =
        camera.target.z + dist * math.cos(camera.yaw) * math.cos(camera.pitch);

    final Vec3 eye = Vec3(eyeX, eyeY, eyeZ);
    final Vec3 target = camera.target;
    final Vec3 fwd = (target - eye).norm;
    const Vec3 worldUp = Vec3(0, 1, 0);
    final Vec3 right = fwd.cross(worldUp).norm;
    final Vec3 camUp = right.cross(fwd).norm;

    // Focal length scaled dynamically with viewport size
    final double fl = math.min(w, h) * 1.15;

    // Project 3D Point to 2D Screen
    Offset? project(Vec3 p) {
      final v = p - eye;
      final vz = v.dot(fwd);
      if (vz <= 20.0) return null; // near clipping plane
      final vx = v.dot(right);
      final vy = v.dot(camUp);
      return Offset(cx + (vx / vz) * fl, cy - (vy / vz) * fl);
    }

    double getDepth(Vec3 p) => (p - eye).dot(fwd);

    // 2. Draw Auditorium Environment (Walls, Floor, Atmosphere)
    try {
      _drawAtmosphere(canvas, size, project);
    } catch (e) {
      debugPrint('[3D Hall] Error in _drawAtmosphere: $e');
    }

    // 3. Draw Massive Cinema Screen with Light Projection
    try {
      _drawCinemaScreen(canvas, size, project);
    } catch (e) {
      debugPrint('[3D Hall] Error in _drawCinemaScreen: $e');
    }

    // 4. Draw Stage Apron and Neon Lip Light
    try {
      _drawStageApron(canvas, project);
    } catch (e) {
      debugPrint('[3D Hall] Error in _drawStageApron: $e');
    }

    // 5. Draw Tiered Carpet Aisles and Floor Lights
    try {
      _drawAislesAndTiers(canvas, project);
    } catch (e) {
      debugPrint('[3D Hall] Error in _drawAislesAndTiers: $e');
    }

    // 6. Draw 3D Cinema Seats (Depth-Sorted)
    try {
      _drawSeats(canvas, size, project, getDepth);
    } catch (e) {
      debugPrint('[3D Hall] Error in _drawSeats: $e');
    }
  }

  void _drawAtmosphere(Canvas canvas, Size size, Offset? Function(Vec3) project) {
    // Deep cinema void background
    final bgPaint = Paint();
    if (size.width > 0 && size.height > 0) {
      bgPaint.shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.35),
        size.width * 0.8,
        [
          houseLights
              ? const Color(0xFF1E293B)
              : (isDark ? const Color(0xFF070B14) : const Color(0xFF0F172A)),
          const Color(0xFF020408),
        ],
      );
    } else {
      bgPaint.color =
          isDark ? const Color(0xFF070B14) : const Color(0xFF0F172A);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Left & Right Acoustic Wall Panels
    final wallColor = houseLights
        ? const Color(0xFF334155).withValues(alpha: 0.35)
        : const Color(0xFF111827).withValues(alpha: 0.7);

    final leftWallTop = project(const Vec3(-380, 260, 0));
    final leftWallBottom = project(const Vec3(-380, 0, 0));
    final leftWallBackTop = project(const Vec3(-480, 320, 750));
    final leftWallBackBottom = project(const Vec3(-480, 240, 750));

    if (leftWallTop != null &&
        leftWallBottom != null &&
        leftWallBackTop != null &&
        leftWallBackBottom != null) {
      final leftWallPath = Path()
        ..moveTo(leftWallTop.dx, leftWallTop.dy)
        ..lineTo(leftWallBackTop.dx, leftWallBackTop.dy)
        ..lineTo(leftWallBackBottom.dx, leftWallBackBottom.dy)
        ..lineTo(leftWallBottom.dx, leftWallBottom.dy)
        ..close();
      canvas.drawPath(leftWallPath, Paint()..color = wallColor);

      // Acoustic Slat Lines on Left Wall
      for (double z = 100; z <= 650; z += 90) {
        final t = project(Vec3(-400 - (z * 0.1), 270 + (z * 0.05), z));
        final b = project(Vec3(-400 - (z * 0.1), 20 + (z * 0.28), z));
        if (t != null && b != null) {
          canvas.drawLine(
            t,
            b,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.04)
              ..strokeWidth = 2,
          );
        }
      }
    }

    // Glowing Green EXIT Sign on Left Door
    final exitP = project(const Vec3(-375, 120, 150));
    if (exitP != null) {
      final exitRect = Rect.fromCenter(center: exitP, width: 34, height: 16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(exitRect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.85),
      );
      // Soft green neon glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(exitRect.inflate(6), const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawCinemaScreen(Canvas canvas, Size size, Offset? Function(Vec3) project) {
    const double screenW = 460.0;
    const double screenH = 258.75; // Exact 16:9 matching video trailers
    const double screenY = 270.0;
    const double screenZ = 10.0;
    const double screenCurve = 32.0;

    // Curved Screen Grid Points
    const int segments = 16;
    final List<Offset> topPoints = [];
    final List<Offset> bottomPoints = [];

    for (int i = 0; i <= segments; i++) {
      final double frac = i / segments;
      final double x = -screenW / 2 + frac * screenW;
      // Parabolic curve inward
      final double z = screenZ - (1.0 - math.pow(x / (screenW / 2), 2)) * screenCurve;
      final top = project(Vec3(x, screenY, z));
      final bot = project(Vec3(x, screenY - screenH, z));
      if (top != null && bot != null) {
        topPoints.add(top);
        bottomPoints.add(bot);
      }
    }

    if (topPoints.length == segments + 1 && bottomPoints.length == segments + 1) {
      final screenPath = Path()..moveTo(topPoints.first.dx, topPoints.first.dy);
      for (final p in topPoints) {
        screenPath.lineTo(p.dx, p.dy);
      }
      for (int i = bottomPoints.length - 1; i >= 0; i--) {
        screenPath.lineTo(bottomPoints[i].dx, bottomPoints[i].dy);
      }
      screenPath.close();

      // Screen Surface Gradient (Cinematic lighting)
      final bounds = screenPath.getBounds();
      final screenPaint = Paint();
      if (bounds.height > 2.0 && (bounds.topCenter - bounds.bottomCenter).distanceSquared > 4.0) {
        screenPaint.shader = ui.Gradient.linear(
          bounds.topCenter,
          bounds.bottomCenter,
          isPlayingTrailer
              ? [const Color(0xFF030712), const Color(0xFF0F172A)]
              : (houseLights
                  ? [const Color(0xFFE2E8F0), const Color(0xFF94A3B8)]
                  : (isHoveringScreen
                      ? [const Color(0xFF38BDF8), const Color(0xFF0284C7)]
                      : [const Color(0xFF67E8F9), const Color(0xFF0284C7)])),
        );
      } else {
        screenPaint.color =
            isPlayingTrailer ? const Color(0xFF030712) : const Color(0xFF0284C7);
      }

      // Ambient screen glow on auditorium floor and ceiling
      if (!houseLights && isHd) {
        canvas.drawPath(
          screenPath,
          Paint()
            ..color = (isPlayingTrailer ? const Color(0xFF0284C7) : const Color(0xFF38BDF8))
                .withValues(alpha: isPlayingTrailer ? 0.55 : (isHoveringScreen ? 0.45 : 0.35))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, isPlayingTrailer ? 36 : 28),
        );
      }

      // Draw screen body
      canvas.drawPath(screenPath, screenPaint);

      // Screen Frame Border (glows cyan on hover)
      canvas.drawPath(
        screenPath,
        Paint()
          ..color = isHoveringScreen
              ? const Color(0xFF38BDF8)
              : const Color(0xFF0F172A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHoveringScreen ? 3.5 : 3,
      );

      // When trailer is NOT playing, show Title and interactive Play Prompt
      if (!isPlayingTrailer) {
        // Cinema Movie Title Card on Screen
        final centerTop = topPoints[segments ~/ 2];
        final centerBot = bottomPoints[segments ~/ 2];
        final screenCenter = Offset(
          (centerTop.dx + centerBot.dx) / 2,
          (centerTop.dy + centerBot.dy) / 2,
        );

        // Movie Title Typography on the screen
        final textSpan = TextSpan(
          text: movieTitle.toUpperCase(),
          style: TextStyle(
            fontSize: (bounds.height * 0.16).clamp(16.0, 36.0),
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width * 0.8);

        textPainter.paint(
          canvas,
          screenCenter - Offset(textPainter.width / 2, textPainter.height * 0.9),
        );

        // Interactive Play Button Badge on screen
        final playCenter = screenCenter + Offset(0, textPainter.height * 0.45);
        final bool isHover = isHoveringScreen;

        // Glowing outer halo
        canvas.drawCircle(
          playCenter,
          isHover ? 28 : 22,
          Paint()
            ..color = const Color(0xFF0284C7).withValues(alpha: isHover ? 0.5 : 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );

        // Play button background
        final playBgPaint = Paint()
          ..color = isHover
              ? const Color(0xFF0284C7)
              : Colors.black.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(playCenter, 20, playBgPaint);
        canvas.drawCircle(
          playCenter,
          20,
          Paint()
            ..color = isHover ? Colors.white : const Color(0xFF38BDF8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );

        // Play triangle icon
        final playPath = Path()
          ..moveTo(playCenter.dx - 5, playCenter.dy - 8)
          ..lineTo(playCenter.dx + 8, playCenter.dy)
          ..lineTo(playCenter.dx - 5, playCenter.dy + 8)
          ..close();
        canvas.drawPath(playPath, Paint()..color = Colors.white);

        // Invitation label
        final promptSpan = TextSpan(
          text: isHover
              ? '▶ CLICK SCREEN TO STREAM 24 TRAILER'
              : 'CLICK SCREEN TO PLAY TRAILER',
          style: TextStyle(
            fontSize: (bounds.height * 0.075).clamp(9.5, 13.0),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: isHover ? Colors.white : Colors.white70,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
        final promptPainter = TextPainter(
          text: promptSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bounds.width * 0.9);
        promptPainter.paint(
          canvas,
          playCenter + Offset(-promptPainter.width / 2, 26),
        );
      }

      // Red Stage Curtains on left & right edges
      final leftCurtainTop = topPoints.first;
      final leftCurtainBot = bottomPoints.first;
      final rightCurtainTop = topPoints.last;
      final rightCurtainBot = bottomPoints.last;

      const double curtainW = 28.0;
      final curtainPaint = Paint()..color = const Color(0xFF881337);
      final leftCurtainRect = Rect.fromPoints(
        leftCurtainTop - const Offset(curtainW, 0),
        leftCurtainBot,
      );
      final rightCurtainRect = Rect.fromPoints(
        rightCurtainTop,
        rightCurtainBot + const Offset(curtainW, 0),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(leftCurtainRect, const Radius.circular(3)),
        curtainPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rightCurtainRect, const Radius.circular(3)),
        curtainPaint,
      );

      // Subtle curtain pleat lines
      final pleatPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 1.2;
      for (double dx = 6; dx < curtainW; dx += 8) {
        canvas.drawLine(
          leftCurtainRect.topLeft + Offset(dx, 0),
          leftCurtainRect.bottomLeft + Offset(dx, 0),
          pleatPaint,
        );
        canvas.drawLine(
          rightCurtainRect.topLeft + Offset(dx, 0),
          rightCurtainRect.bottomLeft + Offset(dx, 0),
          pleatPaint,
        );
      }
    }
  }

  void _drawStageApron(Canvas canvas, Offset? Function(Vec3) project) {
    const double stageW = 540.0;
    final p1 = project(const Vec3(-stageW / 2, 10, 0));
    final p2 = project(const Vec3(stageW / 2, 10, 0));
    final p3 = project(const Vec3(stageW / 2 + 30, 8, 120));
    final p4 = project(const Vec3(-stageW / 2 - 30, 8, 120));

    if (p1 != null && p2 != null && p3 != null && p4 != null) {
      final stagePath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      // Reflective Stage Apron
      final pMid1 = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final pMid2 = Offset((p3.dx + p4.dx) / 2, (p3.dy + p4.dy) / 2);
      final stagePaint = Paint();
      if ((pMid1 - pMid2).distanceSquared > 4.0) {
        stagePaint.shader = ui.Gradient.linear(
          pMid1,
          pMid2,
          [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        );
      } else {
        stagePaint.color = const Color(0xFF1E293B);
      }
      canvas.drawPath(stagePath, stagePaint);

      // Glowing Neon Floor Strip at front of stage
      final stripPaint = Paint()
        ..color = const Color(0xFF06B6D4)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p4, p3, stripPaint);

      // Neon soft glow
      if (isHd) {
        final neonGlow = Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.45)
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..style = PaintingStyle.stroke;
        canvas.drawLine(p4, p3, neonGlow);
      }
    }
  }

  void _drawAislesAndTiers(Canvas canvas, Offset? Function(Vec3) project) {
    // Stepped auditorium floor plane
    final f1 = project(const Vec3(-360, 6, 140));
    final f2 = project(const Vec3(360, 6, 140));
    final f3 = project(const Vec3(460, 240, 750));
    final f4 = project(const Vec3(-460, 240, 750));

    if (f1 != null && f2 != null && f3 != null && f4 != null) {
      final floorPath = Path()
        ..moveTo(f1.dx, f1.dy)
        ..lineTo(f2.dx, f2.dy)
        ..lineTo(f3.dx, f3.dy)
        ..lineTo(f4.dx, f4.dy)
        ..close();

      final fMid1 = Offset((f1.dx + f2.dx) / 2, (f1.dy + f2.dy) / 2);
      final fMid2 = Offset((f3.dx + f4.dx) / 2, (f3.dy + f4.dy) / 2);
      final floorPaint = Paint();
      if ((fMid1 - fMid2).distanceSquared > 4.0) {
        floorPaint.shader = ui.Gradient.linear(
          fMid1,
          fMid2,
          [
            houseLights ? const Color(0xFF1E293B) : const Color(0xFF0B0F19),
            const Color(0xFF020617),
          ],
        );
      } else {
        floorPaint.color = houseLights ? const Color(0xFF1E293B) : const Color(0xFF0B0F19);
      }
      canvas.drawPath(floorPath, floorPaint);

      // Aisle Floor LED Path Lights (Left and Right aisles)
      for (double z = 200; z <= 680; z += 55) {
        final double y = 8.0 + (z - 200) * 0.35;
        // Left aisle marker
        final la = project(Vec3(-150, y + 2, z));
        // Right aisle marker
        final ra = project(Vec3(150, y + 2, z));

        final ledPaint = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
          ..style = PaintingStyle.fill;

        if (la != null) {
          canvas.drawCircle(la, 2.5, ledPaint);
        }
        if (ra != null) {
          canvas.drawCircle(ra, 2.5, ledPaint);
        }
      }
    }
  }

  void _drawSeats(
    Canvas canvas,
    Size size,
    Offset? Function(Vec3) project,
    double Function(Vec3) getDepth,
  ) {
    final List<ProjectedSeat> projected = [];
    SeatModel? newlyHoveredSeat;

    for (final s3d in seats3D) {
      final depth = getDepth(s3d.position);
      if (depth <= 20.0) continue;

      final isSelected = selectedSeats.any((s) => s.id == s3d.model.id);
      final isBooked = s3d.model.status == SeatStatusType.booked;

      // Seat corner vectors in 3D
      final hw = s3d.width / 2;
      final pos = s3d.position;

      // Base Cushion polygon
      final cFL = project(Vec3(pos.x - hw, pos.y, pos.z - s3d.depth / 2));
      final cFR = project(Vec3(pos.x + hw, pos.y, pos.z - s3d.depth / 2));
      final cBR = project(Vec3(pos.x + hw, pos.y + 4, pos.z + s3d.depth / 2));
      final cBL = project(Vec3(pos.x - hw, pos.y + 4, pos.z + s3d.depth / 2));

      // Backrest polygon (raised and angled)
      final bTL = project(Vec3(pos.x - hw * 0.9, pos.y + s3d.height, pos.z + s3d.depth / 2));
      final bTR = project(Vec3(pos.x + hw * 0.9, pos.y + s3d.height, pos.z + s3d.depth / 2));

      if (cFL != null &&
          cFR != null &&
          cBR != null &&
          cBL != null &&
          bTL != null &&
          bTR != null) {
        final cushionPath = Path()
          ..moveTo(cFL.dx, cFL.dy)
          ..lineTo(cFR.dx, cFR.dy)
          ..lineTo(cBR.dx, cBR.dy)
          ..lineTo(cBL.dx, cBL.dy)
          ..close();

        final backrestPath = Path()
          ..moveTo(cBL.dx, cBL.dy)
          ..lineTo(cBR.dx, cBR.dy)
          ..lineTo(bTR.dx, bTR.dy)
          ..lineTo(bTL.dx, bTL.dy)
          ..close();

        final headrestPath = Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromPoints(bTL - const Offset(0, 6), bTR + const Offset(0, 2)),
            const Radius.circular(3),
          ));

        final totalBounds = cushionPath.getBounds().expandToInclude(backrestPath.getBounds());

        // Hit testing for hover
        bool isHovered = false;
        if (hoverPos != null && !isBooked) {
          if (totalBounds.inflate(3).contains(hoverPos!)) {
            isHovered = true;
            newlyHoveredSeat = s3d.model;
          }
        }

        projected.add(ProjectedSeat(
          seat: s3d,
          screenBounds: totalBounds,
          cushionPath: cushionPath,
          backrestPath: backrestPath,
          headrestPath: headrestPath,
          cameraDepth: depth,
          isSelected: isSelected,
          isHovered: isHovered,
        ));
      }
    }

    onHoveredSeatDetected(newlyHoveredSeat);

    // Sort seats by camera depth (Painter's algorithm: draw farthest seats first)
    projected.sort((a, b) => b.cameraDepth.compareTo(a.cameraDepth));

    for (final p in projected) {
      final s = p.seat;
      final isBooked = s.model.status == SeatStatusType.booked;

      Color seatColor;
      if (p.isSelected) {
        seatColor = const Color(0xFF06B6D4); // Neon Cyan (Your Pick)
      } else if (isBooked) {
        seatColor = const Color(0xFF334155); // Muted dark slate
      } else if (p.isHovered) {
        seatColor = Color.lerp(s.baseColor, Colors.white, 0.35)!;
      } else {
        seatColor = s.baseColor;
      }

      // Shaded cushions
      final backrestPaint = Paint()
        ..color = seatColor
        ..style = PaintingStyle.fill;

      final cushionPaint = Paint()
        ..color = Color.lerp(seatColor, Colors.black, 0.20)!
        ..style = PaintingStyle.fill;

      // Selected Glowing Aura
      if (p.isSelected) {
        final glowPaint = Paint()
          ..color = const Color(0xFF06B6D4).withValues(alpha: 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawPath(p.backrestPath, glowPaint);
        canvas.drawPath(p.cushionPath, glowPaint);
      }

      // Draw Headrest, Backrest & Cushion
      canvas.drawPath(p.headrestPath, backrestPaint);
      canvas.drawPath(p.backrestPath, backrestPaint);
      canvas.drawPath(p.cushionPath, cushionPaint);

      // Seat outline borders for definition
      final borderPaint = Paint()
        ..color = p.isSelected
            ? Colors.white
            : (isBooked
                ? Colors.black54
                : Colors.black.withValues(alpha: 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.isSelected ? 1.5 : 0.8;

      canvas.drawPath(p.backrestPath, borderPaint);
      canvas.drawPath(p.cushionPath, borderPaint);

      // Row & Seat Number on Headrest when zoomed in close enough
      if (p.cameraDepth < 450.0 && !isBooked) {
        final labelSpan = TextSpan(
          text: s.model.label,
          style: TextStyle(
            fontSize: (180.0 / p.cameraDepth).clamp(7.0, 11.0),
            fontWeight: FontWeight.bold,
            color: p.isSelected ? Colors.black : Colors.white70,
          ),
        );
        final lp = TextPainter(
          text: labelSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        final c = p.headrestPath.getBounds().center;
        lp.paint(canvas, c - Offset(lp.width / 2, lp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CinemaHall3DPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.selectedSeats != selectedSeats ||
        oldDelegate.hoverPos != hoverPos ||
        oldDelegate.houseLights != houseLights ||
        oldDelegate.isHd != isHd ||
        oldDelegate.movieTitle != movieTitle ||
        oldDelegate.isPlayingTrailer != isPlayingTrailer ||
        oldDelegate.isHoveringScreen != isHoveringScreen;
  }
}
