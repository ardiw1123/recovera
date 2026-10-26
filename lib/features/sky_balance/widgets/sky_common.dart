import 'package:flutter/material.dart';

import '../sky_balance_theme.dart';

/// Full-bleed sky: gradient, a few slowly drifting clouds and an optional
/// scrim used behind modals. Clouds stop moving when the platform asks for
/// reduced motion.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.child, this.dimmed = false});

  final Widget child;
  final bool dimmed;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void initState() {
    super.initState();
    _drift.repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion && _drift.isAnimating) {
      _drift.stop();
    } else if (!reduceMotion && !_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                SkyPalette.skyTop,
                SkyPalette.skyMiddle,
                SkyPalette.skyBottom,
              ],
              stops: <double>[0, .46, 1],
            ),
          ),
        ),
        ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (BuildContext context, Widget? _) {
              final double t = Curves.easeInOut.transform(_drift.value);
              return Stack(
                children: <Widget>[
                  Positioned(
                    top: 118 + 4 * t,
                    left: -62 + 16 * t,
                    child: const SkyCloud(width: 214, height: 64, opacity: .8),
                  ),
                  Positioned(
                    top: 288 - 6 * t,
                    right: -70 + 14 * t,
                    child: const SkyCloud(width: 196, height: 56, opacity: .62),
                  ),
                  Positioned(
                    bottom: 142 + 8 * t,
                    left: -74 + 12 * t,
                    child: const SkyCloud(width: 208, height: 60, opacity: .58),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.dimmed) const ColoredBox(color: Color(0x7004263C)),
        widget.child,
      ],
    );
  }
}

/// Three overlapping rounded blobs read as a soft cartoon cloud.
class SkyCloud extends StatelessWidget {
  const SkyCloud({
    super.key,
    required this.width,
    this.height = 58,
    this.opacity = .8,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final Color color = Colors.white.withValues(alpha: opacity);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * .66,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          Positioned(
            left: width * .17,
            bottom: height * .26,
            width: width * .42,
            height: height * .82,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
          Positioned(
            left: width * .56,
            bottom: height * .2,
            width: width * .32,
            height: height * .62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A floating platform the character stands on.
class SkyPlatform extends StatelessWidget {
  const SkyPlatform({
    super.key,
    required this.width,
    this.height = 24,
    this.opacity = 1,
  });

  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.white.withValues(alpha: opacity),
            const Color(0xFFCFE9F8).withValues(alpha: opacity),
          ],
        ),
        borderRadius: BorderRadius.circular(SkyRadii.pill),
        boxShadow: SkyShadows.floating(opacity: .2),
      ),
    );
  }
}

/// Blue wave header carried over from the Recovera home screen.
class SkyWaveHeader extends StatelessWidget {
  const SkyWaveHeader({
    super.key,
    required this.title,
    this.leading,
    this.onBack,
    this.actions = const <Widget>[],
    this.titleSize = 21,
    this.height = 124,
  });

  final String title;
  final Widget? leading;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double titleSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: CustomPaint(painter: _WaveHeaderPainter()),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: <Widget>[
                  if (onBack != null)
                    SkyCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back to lobby',
                      onPressed: onBack!,
                    ),
                  ?leading,
                  if (leading != null || onBack != null)
                    const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SkyType.strong(
                        size: titleSize,
                        color: Colors.white,
                        height: 1,
                      ).copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent round icon button used on the wave header.
class SkyCircleIconButton extends StatelessWidget {
  const SkyCircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .16),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: .32)),
        minimumSize: const Size(36, 36),
        fixedSize: const Size(36, 36),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
    );
  }
}

class _WaveHeaderPainter extends CustomPainter {
  const _WaveHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 390;
    final double sy = size.height / 122;

    // Backdrop wave, slightly lower so it peeks under the main wave.
    final Path backdrop = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 98 * sy)
      ..cubicTo(338 * sx, 116 * sy, 300 * sx, 92 * sy, 244 * sx, 101 * sy)
      ..cubicTo(188 * sx, 110 * sy, 150 * sx, 122 * sy, 96 * sx, 110 * sy)
      ..cubicTo(52 * sx, 101 * sy, 26 * sx, 92 * sy, 0, 101 * sy)
      ..close();
    canvas.drawPath(
      backdrop,
      Paint()..color = SkyPalette.accent.withValues(alpha: .45),
    );

    // Main wave with the brand gradient.
    final Path main = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 88 * sy)
      ..cubicTo(340 * sx, 104 * sy, 302 * sx, 82 * sy, 248 * sx, 90 * sy)
      ..cubicTo(192 * sx, 99 * sy, 154 * sx, 110 * sy, 100 * sx, 98 * sy)
      ..cubicTo(58 * sx, 89 * sy, 28 * sx, 82 * sy, 0, 90 * sy)
      ..close();

    canvas.drawPath(
      main,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            SkyPalette.primaryDark,
            SkyPalette.primary,
            Color(0xFF12A3DA),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _WaveHeaderPainter oldDelegate) => false;
}
