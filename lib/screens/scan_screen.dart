import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/colors.dart';
import '../services/camera_service.dart';
import '../services/permission_service.dart';
import '../services/frame_quality_service.dart';
import '../services/image_crop_service.dart';
import '../services/shutter_sound_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final _camera = CameraService();
  late FrameQualityService _frameQuality;
  final _shutterSound = ShutterSoundService();

  // ── Settings ───────────────────────────────────────────────────────────────
  bool _gridEnabled = false;
  bool _soundEnabled = true;
  bool _saveToGallery = false;
  // 0 = relaxed, 1 = normal (default), 2 = strict
  int _qualityLevel = 1;

  // ── State ──────────────────────────────────────────────────────────────────
  _ScreenState _screenState = _ScreenState.checkingPermission;
  bool _isCapturing = false;
  bool _flashOn = false;
  // True only when the app genuinely went to background (paused/inactive).
  // Navigation pops also trigger AppLifecycleState.resumed, so without this
  // flag a tab switch back to ScanScreen would fire a full camera reinit
  // while _capture() is already restarting the stream — causing a race that
  // locks the camera hardware after several scans.
  bool _didBackground = false;
  // Null until the first frame is analysed, so the pill stays hidden.
  //
  // This is a ValueNotifier rather than plain State + setState on purpose:
  // the camera's image stream pushes a new quality reading many times per
  // second, and only _QualityPill actually needs that value. Routing it
  // through setState() would rebuild the entire camera screen — live
  // preview, vignette, grid overlay, top bar, viewfinder animation,
  // bottom controls, all of it — on every single frame analysed, which is
  // a very real source of jank, especially on lower-end devices already
  // busy running the camera's image stream in the background. A
  // ValueListenableBuilder scoped to just the pill avoids all of that.
  final _quality = ValueNotifier<FrameQuality?>(null);
  bool _isCropping = false;

  // ── Tap-to-focus ───────────────────────────────────────────────────────────
  // Normalised focus point (0,0)→(1,1) sent to the camera, plus the raw
  // screen position used to draw the focus ring indicator.
  Offset? _focusPoint; // normalised, passed to CameraService
  Offset? _focusIndicator; // screen coordinates, for the ring widget
  bool _showFocusRing = false;

  // Geometry captured from the last build, needed to map the on-screen
  // viewfinder box onto the captured photo's pixel coordinates.
  Rect? _viewfinderRect;
  Offset? _previewOffset;
  Size? _previewDisplaySize;
  final _stackKey = GlobalKey();
  final _viewfinderKey = GlobalKey();
  bool _measurementScheduled = false;

  void _scheduleViewfinderRectMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      _measureViewfinderRect();
    });
  }

  void _measureViewfinderRect() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final vfBox =
        _viewfinderKey.currentContext?.findRenderObject() as RenderBox?;
    final previewOffset = _previewOffset;
    if (stackBox == null ||
        vfBox == null ||
        !vfBox.hasSize ||
        previewOffset == null) {
      return;
    }

    // Viewfinder's top-left in its own local space is (0,0). Convert that
    // to global screen coordinates, then into the Stack's local space.
    final globalTopLeft = vfBox.localToGlobal(Offset.zero);
    final topLeftInStack = stackBox.globalToLocal(globalTopLeft);

    // The preview (via OverflowBox) is centered and almost always larger
    // than the Stack, so its own top-left sits at a negative offset
    // within the Stack. Subtracting it converts the viewfinder's position
    // into preview-relative coordinates — exactly what ImageCropService
    // needs, since it maps fractions of the *preview*, not the screen.
    final topLeftInPreview = topLeftInStack - previewOffset;

    final rect = Rect.fromLTWH(
      topLeftInPreview.dx,
      topLeftInPreview.dy,
      vfBox.size.width,
      vfBox.size.height,
    );

    if (_viewfinderRect != rect) {
      setState(() => _viewfinderRect = rect);
    }
  }

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scanY;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frameQuality = _buildFrameQualityService();
    _shutterSound.init();
    _initAnimations();
    _initCamera();
  }

  /// Builds a [FrameQualityService] tuned to the current [_qualityLevel].
  ///
  /// level 0 – relaxed  (easier to get "good")
  /// level 1 – normal   (factory defaults)
  /// level 2 – strict   (harder to get "good")
  FrameQualityService _buildFrameQualityService() {
    switch (_qualityLevel) {
      case 0:
        return FrameQualityService(
          minAcceptableBrightness: 40,
          maxAcceptableBrightness: 235,
          minAcceptableSharpness: 7,
        );
      case 2:
        return FrameQualityService(
          minAcceptableBrightness: 70,
          maxAcceptableBrightness: 210,
          minAcceptableSharpness: 20,
        );
      default: // 1 – normal
        return FrameQualityService();
    }
  }

  void _initAnimations() {
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scanY = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut));
    _pulseScale = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  Future<void> _initCamera() async {
    // ── 1. Check connectivity first ──────────────────────────────────────────
    final results = await Connectivity().checkConnectivity();
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      if (mounted) setState(() => _screenState = _ScreenState.offline);
      _watchConnectivity();
      return;
    }

    // ── 2. Camera permission ─────────────────────────────────────────────────
    final status = await PermissionService.requestCamera();

    if (status == CameraPermissionStatus.granted) {
      await _startCamera();
    } else if (status == CameraPermissionStatus.permanentlyDenied) {
      if (mounted)
        setState(() => _screenState = _ScreenState.permissionPermanentlyDenied);
    } else {
      if (mounted) setState(() => _screenState = _ScreenState.permissionDenied);
    }
  }

  /// Listens for connectivity to return and auto-retries initialisation.
  void _watchConnectivity() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline && mounted) {
        _connectivitySub?.cancel();
        _connectivitySub = null;
        _initCamera();
      }
    });
  }

  /// Opens the device photo library and sends the picked image to /detect.
  Future<void> _pickFromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    context.push('/home/detect', extra: File(picked.path));
  }

  StreamSubscription<FrameQuality>? _qualitySub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void> _startCamera() async {
    try {
      setState(() => _screenState = _ScreenState.loading);
      // Always fully dispose before reinitialising — the screen may have been
      // unmounted (e.g. /detect pushed on root navigator tears down ScanScreen)
      // leaving the CameraController in a broken/disposed state. Reinitialising
      // without disposing first locks the camera hardware on most devices.
      await _qualitySub?.cancel();
      _qualitySub = null;
      await _camera.dispose();
      await _camera.init();
      if (!mounted) return;
      setState(() => _screenState = _ScreenState.ready);
      _scheduleViewfinderRectMeasurement();
      await _startLiveQualityCheck();
    } catch (e) {
      debugPrint('[ScanScreen] _startCamera error: $e');
      if (mounted) setState(() => _screenState = _ScreenState.error);
    }
  }

  Future<void> _startLiveQualityCheck() async {
    if (!mounted) return;
    // Always cancel the old sub and re-subscribe so we get a fresh listener
    // even when returning from /detect (where the stream was stopped).
    await _qualitySub?.cancel();
    _qualitySub = _frameQuality.qualityStream.listen((q) {
      // Updates the notifier directly — no setState, so this doesn't
      // rebuild the whole screen on every analysed frame. Only the
      // ValueListenableBuilder wrapping _QualityPill reacts to this.
      _quality.value = q;
    });
    await _camera.startImageStream(_frameQuality.onFrame);
  }

  // Pause/resume preview when app goes to background/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _didBackground = true;
      _camera.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Only do a full reinit when the app truly went to background.
      // Navigation pops (e.g. returning from another tab) also fire
      // resumed — without this guard that would race with _capture()'s
      // own restart path and lock the camera hardware.
      if (_didBackground) {
        _didBackground = false;
        _startCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _qualitySub?.cancel();
    _connectivitySub?.cancel();
    _frameQuality.dispose();
    _shutterSound.dispose();
    _camera.dispose();
    _quality.dispose();
    super.dispose();
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_isCapturing || _screenState != _ScreenState.ready) return;
    setState(() => _isCapturing = true);

    // Play shutter sound immediately so it feels responsive.
    if (_soundEnabled) {
      _shutterSound.play();
    }

    try {
      final file = await _camera.capture();
      if (!mounted) return;

      File toSend = file;

      // Crop down to exactly what the user saw inside the viewfinder box,
      // if we have valid geometry for it. Falls back to the full photo
      // (rather than blocking the flow) if layout data isn't available.
      final rect = _viewfinderRect;
      final previewSize = _previewDisplaySize;
      if (rect != null && previewSize != null) {
        setState(() => _isCropping = true);
        try {
          toSend = await ImageCropService.cropToViewfinder(
            source: file,
            viewfinderRect: rect,
            previewDisplaySize: previewSize,
            isFrontCamera: _camera.isFrontCamera,
          );
        } catch (e) {
          debugPrint('[Scan] Crop failed, using uncropped photo: $e');
        } finally {
          if (mounted) setState(() => _isCropping = false);
        }
      }

      // Save a copy to the device gallery if the user opted in.
      if (_saveToGallery) {
        try {
          await Gal.putImage(toSend.path);
        } catch (e) {
          debugPrint('[Scan] Save to gallery failed: $e');
        }
      }

      if (!mounted) return;
      await context.push('/home/detect', extra: toSend);
      // Stream was stopped before capture. Use _startCamera() for the full
      // reinit path — avoids racing with a lifecycle-triggered reinit if the
      // OS fired paused/resumed during the /detect screen's lifetime.
      if (mounted && _screenState == _ScreenState.ready) {
        await _startCamera();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture failed: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final mode = await _camera.toggleFlash();
    setState(() => _flashOn = mode == FlashMode.torch);
  }

  Future<void> _flipCamera() async {
    // Cancel the existing quality sub before flipping — flipCamera() internally
    // stops the stream, so the sub would receive no more events anyway.
    await _qualitySub?.cancel();
    _qualitySub = null;
    setState(() => _screenState = _ScreenState.loading);
    await _camera.flipCamera();
    if (!mounted) return;
    setState(() => _screenState = _ScreenState.ready);
    await _startLiveQualityCheck();
  }

  // ── Tap-to-focus ──────────────────────────────────────────────────────────

  Future<void> _onTapToFocus(TapUpDetails details) async {
    if (_screenState != _ScreenState.ready) return;

    final previewOffset = _previewOffset;
    final previewSize = _previewDisplaySize;
    if (previewOffset == null || previewSize == null) return;

    final tapInPreview = details.localPosition - previewOffset;

    // Clamp to preview bounds before normalising.
    final clamped = Offset(
      tapInPreview.dx.clamp(0, previewSize.width),
      tapInPreview.dy.clamp(0, previewSize.height),
    );
    var normalised = Offset(
      clamped.dx / previewSize.width,
      clamped.dy / previewSize.height,
    );

    // CameraPreview mirrors the front camera horizontally on screen,
    // but the underlying sensor coordinate space is unmirrored.
    if (_camera.isFrontCamera) {
      normalised = Offset(1.0 - normalised.dx, normalised.dy);
    }

    setState(() {
      _focusPoint = normalised;
      _focusIndicator = details.localPosition;
      _showFocusRing = true;
    });

    await _camera.setFocusPoint(normalised);

    // Hide the ring after 2 s (matches typical camera UX).
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _showFocusRing = false);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_screenState) {
        _ScreenState.checkingPermission => _buildLoading(
            'Checking permissions…',
          ),
        _ScreenState.loading => _buildLoading('Starting camera…'),
        _ScreenState.permissionDenied => _buildPermissionDenied(
            permanent: false,
          ),
        _ScreenState.permissionPermanentlyDenied => _buildPermissionDenied(
            permanent: true,
          ),
        _ScreenState.offline => _buildOffline(),
        _ScreenState.error => _buildError(),
        _ScreenState.ready => _buildCamera(),
      },
    );
  }

  // ── Camera UI ──────────────────────────────────────────────────────────────

  Widget _buildCamera() {
    final screenW = MediaQuery.of(context).size.width;
    final viewfinderW = screenW * 0.78;
    final viewfinderH = viewfinderW * 1.1;
    final controller = _camera.controller!;

    return GestureDetector(
      onTapUp: _onTapToFocus,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          // Live camera preview — fills the entire screen
          _CameraPreviewFill(
            controller: controller,
            onGeometryKnown: (offset, size) {
              // Preview geometry only changes on rotation/device swap, so
              // skip pointless rebuild churn when nothing actually moved.
              if (_previewOffset != offset || _previewDisplaySize != size) {
                _previewOffset = offset;
                _previewDisplaySize = size;
                _scheduleViewfinderRectMeasurement();
              }
            },
          ),

          // Vignette
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [Colors.transparent, Color(0xBB000000)],
                stops: [0.5, 1.0],
              ),
            ),
          ),

          // Rule-of-thirds grid overlay
          if (_gridEnabled) IgnorePointer(child: const _GridOverlay()),

          // Tap-to-focus ring — appears at the tapped screen position.
          if (_showFocusRing && _focusIndicator != null)
            Positioned(
              left: _focusIndicator!.dx - 28,
              top: _focusIndicator!.dy - 28,
              child: const _FocusRing(),
            ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TopBtn(
                        icon: _flashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        active: _flashOn,
                        onTap: _toggleFlash,
                      ),
                      Text(
                        'PLANTODEX',
                        style: GoogleFonts.spaceMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 3,
                        ),
                      ),
                      _TopBtn(icon: Icons.tune_rounded, onTap: _showSettings),
                    ],
                  ),
                ),

                const Spacer(),

                // Viewfinder overlay
                AnimatedBuilder(
                  animation: Listenable.merge([_scanCtrl, _pulseCtrl]),
                  builder: (context, _) => KeyedSubtree(
                    key: _viewfinderKey,
                    child: _Viewfinder(
                      width: viewfinderW,
                      height: viewfinderH,
                      scanY: _scanY.value,
                      pulseScale: _pulseScale.value,
                      pulseOpacity: _pulseOpacity.value,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Live quality pill — only shown when a plant frame is
                // detected (non-good states that are purely about lighting
                // or blur are still surfaced so the user can act on them).
                //
                // Scoped with ValueListenableBuilder so the dozens of
                // quality updates per second from the camera stream only
                // rebuild this small widget, not the whole camera screen.
                ValueListenableBuilder<FrameQuality?>(
                  valueListenable: _quality,
                  builder: (context, quality, _) =>
                      _QualityPill(quality: quality),
                ),

                const Spacer(),

                // Bottom controls
                Padding(
                  padding: EdgeInsets.only(
                    left: 40,
                    right: 40,
                    bottom: MediaQuery.of(context).padding.bottom + 72,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _SideBtn(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: _pickFromGallery,
                      ),
                      _ShutterButton(
                          isCapturing: _isCapturing, onTap: _capture),
                      _SideBtn(
                        icon: Icons.flip_camera_ios_outlined,
                        label: 'Flip',
                        onTap: _flipCamera,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ), // Stack
    ); // GestureDetector
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: green300, strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Permission denied ──────────────────────────────────────────────────────

  Widget _buildPermissionDenied({required bool permanent}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 52,
              color: Colors.white30,
            ),
            const SizedBox(height: 20),
            Text(
              'Camera access needed',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              permanent
                  ? 'Camera permission was permanently denied. Open Settings to enable it.'
                  : 'PlantoDex needs camera access to identify plants.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed:
                    permanent ? PermissionService.openSettings : _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: green600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  permanent ? 'Open Settings' : 'Grant Permission',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Offline ────────────────────────────────────────────────────────────────

  Widget _buildOffline() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: Colors.white30),
            const SizedBox(height: 20),
            Text(
              'No internet connection',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'PlantoDex needs a connection to identify plants. '
              "We'll retry automatically when you're back online.",
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                  backgroundColor: green600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings bottom sheet ──────────────────────────────────────────────────

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(
        gridEnabled: _gridEnabled,
        soundEnabled: _soundEnabled,
        saveToGallery: _saveToGallery,
        qualityLevel: _qualityLevel,
        onGridChanged: (v) => setState(() => _gridEnabled = v),
        onSoundChanged: (v) => setState(() => _soundEnabled = v),
        onSaveToGalleryChanged: (v) => setState(() => _saveToGallery = v),
        onQualityChanged: (v) {
          if (v == _qualityLevel) return;
          // Rebuild the quality service with new thresholds, re-subscribe.
          _qualitySub?.cancel();
          _qualitySub = null;
          _frameQuality.dispose();
          setState(() {
            _qualityLevel = v;
            _frameQuality = _buildFrameQualityService();
          });
          _startLiveQualityCheck();
        },
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Could not start camera',
            style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _startCamera,
            child: Text(
              'Try again',
              style: GoogleFonts.spaceGrotesk(color: green300),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Screen state enum ─────────────────────────────────────────────────────────

enum _ScreenState {
  checkingPermission,
  loading,
  permissionDenied,
  permissionPermanentlyDenied,
  offline,
  error,
  ready,
}

// ── Camera preview that fills the screen correctly ────────────────────────────

class _CameraPreviewFill extends StatelessWidget {
  const _CameraPreviewFill({
    required this.controller,
    this.onGeometryKnown,
  });
  final CameraController controller;

  /// Reports the preview's cover-scaled size AND its top-left offset
  /// within this widget's own bounds (which — since the Stack uses
  /// StackFit.expand — is the same as the Stack's coordinate space).
  /// OverflowBox centers an oversized child, so the offset is usually
  /// negative; callers need it to convert other Stack-relative
  /// coordinates (like the viewfinder box) into preview-relative ones.
  final void Function(Offset offset, Size size)? onGeometryKnown;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        // controller.value.aspectRatio is the sensor's native ratio, which
        // on Android is always landscape (e.g. 1.777 for 16:9). CameraPreview
        // rotates the feed to match device orientation internally, so when the
        // phone is portrait the effective displayed ratio is the reciprocal.
        // We detect this by checking whether the screen itself is portrait and
        // the raw ratio is > 1 (landscape), and flip accordingly.
        final rawRatio = controller.value.aspectRatio;
        final isScreenPortrait = screenH >= screenW;
        final previewRatio =
            (isScreenPortrait && rawRatio > 1) ? 1.0 / rawRatio : rawRatio;

        double previewW, previewH;
        if (screenH / screenW > 1 / previewRatio) {
          previewH = screenH;
          previewW = screenH * previewRatio;
        } else {
          previewW = screenW;
          previewH = screenW / previewRatio;
        }

        if (onGeometryKnown != null) {
          final offset = Offset(
            (screenW - previewW) / 2,
            (screenH - previewH) / 2,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onGeometryKnown!(offset, Size(previewW, previewH));
          });
        }

        return OverflowBox(
          maxWidth: previewW,
          maxHeight: previewH,
          child: CameraPreview(controller),
        );
      },
    );
  }
}

// ── Viewfinder overlay ────────────────────────────────────────────────────────

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.width,
    required this.height,
    required this.scanY,
    required this.pulseScale,
    required this.pulseOpacity,
  });

  final double width;
  final double height;
  final double scanY;
  final double pulseScale;
  final double pulseOpacity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pulse ring
          Positioned.fill(
            child: Transform.scale(
              scale: pulseScale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: green400.withOpacity(pulseOpacity),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Frosted fill
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.02),
              ),
            ),
          ),

          // Scan line + glow
          Positioned(
            left: 12,
            right: 12,
            top: scanY * (height - 24) + 12,
            child: Column(
              children: [
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        green300.withOpacity(0.9),
                        green300,
                        green300.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [green300.withOpacity(0.1), Colors.transparent],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Corners
          Positioned.fill(
            child: Align(
              alignment: Alignment.topLeft,
              child: _Corner(flipX: false, flipY: false),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.topRight,
              child: _Corner(flipX: true, flipY: false),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _Corner(flipX: false, flipY: true),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: _Corner(flipX: true, flipY: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.flipX, required this.flipY});
  final bool flipX;
  final bool flipY;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipX ? -1 : 1,
      scaleY: flipY ? -1 : 1,
      child: CustomPaint(size: const Size(26, 26), painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = green300
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const r = 6.0;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(r, 0)
      ..arcToPoint(
        Offset(0, r),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(0, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ── Live quality pill ─────────────────────────────────────────────────────────

class _QualityPillContent {
  const _QualityPillContent(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

class _QualityPill extends StatelessWidget {
  const _QualityPill({required this.quality});
  final FrameQuality? quality;

  /// Returns null when no pill should be shown (no frame analysed yet).
  _QualityPillContent? _contentFor(FrameQuality? q) {
    switch (q) {
      case null:
        return null;
      case FrameQuality.tooDark:
        return const _QualityPillContent(
          'Too dark — find more light',
          Color(0xFFFFB020),
          Icons.brightness_low_rounded,
        );
      case FrameQuality.tooBright:
        return const _QualityPillContent(
          'Too bright — reduce glare',
          Color(0xFFFFB020),
          Icons.brightness_high_rounded,
        );
      case FrameQuality.blurry:
        return const _QualityPillContent(
          'Hold steady…',
          Color(0xFFFFB020),
          Icons.blur_on_rounded,
        );
      case FrameQuality.good:
        return const _QualityPillContent(
          'Good shot — tap to capture',
          green300,
          Icons.check_circle_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(quality);

    // Animate the pill in/out when a plant enters or leaves the frame.
    return AnimatedOpacity(
      opacity: content != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: content == null
          ? const SizedBox(height: 36) // reserve space so layout doesn't jump
          : AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: content.color.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      content.icon,
                      key: ValueKey(quality),
                      size: 14,
                      color: content.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      content.label,
                      key: ValueKey('${quality}_text'),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Tap-to-focus ring ─────────────────────────────────────────────────────────

class _FocusRing extends StatefulWidget {
  const _FocusRing();

  @override
  State<_FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<_FocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scale = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Opacity(
        opacity: _opacity.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: green300, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top icon button ───────────────────────────────────────────────────────────

class _TopBtn extends StatelessWidget {
  const _TopBtn({required this.icon, required this.onTap, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Icon(
          icon,
          size: 17,
          color: active ? Colors.white : Colors.white.withOpacity(0.85),
        ),
      ),
    );
  }
}

// ── Side button ───────────────────────────────────────────────────────────────

class _SideBtn extends StatelessWidget {
  const _SideBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 22, color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shutter button with press feedback ───────────────────────────────────────

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.onTap, required this.isCapturing});
  final VoidCallback onTap;
  final bool isCapturing;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween(begin: 1.0, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: widget.isCapturing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: green600,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('🌿', style: TextStyle(fontSize: 28)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rule-of-thirds grid overlay ───────────────────────────────────────────────

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..strokeWidth = 0.8;

    for (final x in [size.width / 3, size.width * 2 / 3]) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in [size.height / 3, size.height * 2 / 3]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Settings bottom sheet widget ──────────────────────────────────────────────

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.gridEnabled,
    required this.soundEnabled,
    required this.saveToGallery,
    required this.qualityLevel,
    required this.onGridChanged,
    required this.onSoundChanged,
    required this.onSaveToGalleryChanged,
    required this.onQualityChanged,
  });

  final bool gridEnabled;
  final bool soundEnabled;
  final bool saveToGallery;
  final int qualityLevel;
  final ValueChanged<bool> onGridChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onSaveToGalleryChanged;
  final ValueChanged<int> onQualityChanged;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late bool _grid;
  late bool _sound;
  late bool _save;
  late int _quality;

  @override
  void initState() {
    super.initState();
    _grid = widget.gridEnabled;
    _sound = widget.soundEnabled;
    _save = widget.saveToGallery;
    _quality = widget.qualityLevel;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        24;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Scan Settings',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // ── Toggles ──────────────────────────────────────────────────────
          _SettingToggle(
            icon: Icons.grid_3x3_rounded,
            label: 'Grid overlay',
            subtitle: 'Rule-of-thirds lines on viewfinder',
            value: _grid,
            onChanged: (v) {
              setState(() => _grid = v);
              widget.onGridChanged(v);
            },
          ),
          _SettingToggle(
            icon: Icons.volume_up_rounded,
            label: 'Shutter sound',
            subtitle: 'Nature-themed capture sound',
            value: _sound,
            onChanged: (v) {
              setState(() => _sound = v);
              widget.onSoundChanged(v);
            },
          ),
          _SettingToggle(
            icon: Icons.save_alt_rounded,
            label: 'Save to gallery',
            subtitle: 'Auto-save captures to device photos',
            value: _save,
            onChanged: (v) {
              setState(() => _save = v);
              widget.onSaveToGalleryChanged(v);
            },
          ),

          const SizedBox(height: 24),

          // ── Quality threshold ────────────────────────────────────────────
          Text(
            'Shot quality threshold',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How strict the "Good shot" indicator is',
            style:
                GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _QualityChip(
                label: 'Relaxed',
                value: 0,
                selected: _quality,
                onTap: (v) {
                  setState(() => _quality = v);
                  widget.onQualityChanged(v);
                },
              ),
              const SizedBox(width: 8),
              _QualityChip(
                label: 'Normal',
                value: 1,
                selected: _quality,
                onTap: (v) {
                  setState(() => _quality = v);
                  widget.onQualityChanged(v);
                },
              ),
              const SizedBox(width: 8),
              _QualityChip(
                label: 'Strict',
                value: 2,
                selected: _quality,
                onTap: (v) {
                  setState(() => _quality = v);
                  widget.onQualityChanged(v);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Setting toggle row ────────────────────────────────────────────────────────

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? green600.withOpacity(0.25)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? green300 : Colors.white38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: green300,
            activeTrackColor: green600.withOpacity(0.5),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}

// ── Quality threshold chip ────────────────────────────────────────────────────

class _QualityChip extends StatelessWidget {
  const _QualityChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? green600.withOpacity(0.35)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? green300.withOpacity(0.6) : Colors.white12,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? green300 : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
