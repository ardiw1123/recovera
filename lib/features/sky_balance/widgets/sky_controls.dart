import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game_models.dart';
import '../sky_balance_theme.dart';
import '../sky_character.dart';

/// Solid primary pill. The only filled action on a screen.
class SkyPrimaryButton extends StatefulWidget {
  const SkyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  State<SkyPrimaryButton> createState() => _SkyPrimaryButtonState();
}

class _SkyPrimaryButtonState extends State<SkyPrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final TextStyle labelStyle = GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
    );

    return AnimatedScale(
      scale: _pressed && enabled ? .97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SkyRadii.pill),
            boxShadow: enabled ? SkyShadows.floating(opacity: .42) : null,
          ),
          child: SizedBox(
            width: double.infinity,
            height: widget.height,
            child: FilledButton(
              onPressed: widget.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: SkyPalette.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: SkyPalette.primary.withValues(
                  alpha: .45,
                ),
                disabledForegroundColor: Colors.white.withValues(alpha: .85),
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 20),
                shape: const StadiumBorder(),
                textStyle: labelStyle,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(widget.icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: labelStyle.copyWith(
                        color: enabled
                            ? Colors.white
                            : Colors.white.withValues(alpha: .85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet outlined action that never competes with the primary button.
class SkySecondaryButton extends StatelessWidget {
  const SkySecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SkyPalette.primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFCDE7F6)),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 17),
              const SizedBox(width: 7),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// Small text action for tertiary routes.
class SkyTextAction extends StatelessWidget {
  const SkyTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = SkyPalette.muted,
    this.iconAfter = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: color,
    );
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null && !iconAfter) ...<Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, style: style),
          if (icon != null && iconAfter) ...<Widget>[
            const SizedBox(width: 6),
            Icon(icon, size: 16, color: color),
          ],
        ],
      ),
    );
  }
}

/// Circular character portrait. Photos are only ever cropped to a circle.
class SkyCharacterAvatar extends StatelessWidget {
  const SkyCharacterAvatar({
    super.key,
    required this.character,
    required this.size,
    this.selected = false,
    this.showSelectionBadge = false,
  });

  final SkyCharacter character;
  final double size;
  final bool selected;
  final bool showSelectionBadge;

  @override
  Widget build(BuildContext context) {
    final double ringGap = selected ? 4 : 0;
    final bool isLarge = size >= 80;

    final Widget portrait = character.isMascot
        ? Padding(
            padding: EdgeInsets.all(size * .12),
            child: SvgPicture.asset(character.asset, fit: BoxFit.contain),
          )
        : Image.asset(character.asset, fit: BoxFit.cover);

    return SizedBox(
      width: size + ringGap * 2,
      height: size + ringGap * 2,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (selected)
            Container(
              width: size + ringGap * 2,
              height: size + ringGap * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SkyPalette.cyan, width: 2.5),
              ),
            ),
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(isLarge ? 4 : 2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: SkyShadows.floating(opacity: .16),
            ),
            child: ClipOval(
              child: ColoredBox(
                color: SkyPalette.paleBlue,
                child: portrait,
              ),
            ),
          ),
          if (selected && showSelectionBadge)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SkyPalette.cyan,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// White pill used for HUD readouts and floating feedback.
class SkyPill extends StatelessWidget {
  const SkyPill({
    super.key,
    required this.child,
    this.background = Colors.white,
    this.opacity = .95,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    this.shadow = true,
  });

  final Widget child;
  final Color background;
  final double opacity;
  final EdgeInsets padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(SkyRadii.pill),
        boxShadow: shadow ? SkyShadows.pill : null,
      ),
      child: child,
    );
  }
}

/// Rounded white surface used for instruction rows and result cards.
class SkySurfaceCard extends StatelessWidget {
  const SkySurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.opacity = .9,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double opacity;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(SkyRadii.card),
        border: Border.all(color: SkyPalette.border),
        boxShadow: elevated ? SkyShadows.surface : null,
      ),
      child: child,
    );
  }
}

/// One label / value row separated by a hairline in the parent.
class SkyDataRow extends StatelessWidget {
  const SkyDataRow({
    super.key,
    required this.label,
    required this.value,
    this.leading,
    this.valueSubLabel,
    this.muted = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final Widget? leading;
  final String? valueSubLabel;
  final bool muted;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[
            leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: SkyType.body(
                size: 13,
                color: muted ? SkyPalette.muted : SkyPalette.body,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                value,
                style: SkyType.number(
                  size: 13.5,
                  color:
                      valueColor ??
                      (muted ? SkyPalette.faint : SkyPalette.ink),
                ),
              ),
              if (valueSubLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    valueSubLabel!,
                    style: SkyType.body(
                      size: 10.5,
                      color: SkyPalette.faint,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkyHairline extends StatelessWidget {
  const SkyHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: SkyPalette.hairline),
    );
  }
}

/// Progress towards the summit with the level's checkpoint markers.
class ClimbTrack extends StatelessWidget {
  const ClimbTrack({
    super.key,
    required this.progress,
    required this.checkpoints,
    this.reached = 0,
    this.dotSize = 10,
    this.trackHeight = 6,
  });

  final double progress;
  final List<SkyCheckpoint> checkpoints;
  final int reached;
  final double dotSize;
  final double trackHeight;

  @override
  Widget build(BuildContext context) {
    final double clamped = progress.clamp(0.0, 1.0).toDouble();
    final double lane = dotSize < trackHeight ? trackHeight : dotSize;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        return SizedBox(
          height: lane,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: (lane - trackHeight) / 2,
                child: Container(
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: SkyPalette.track,
                    borderRadius: BorderRadius.circular(SkyRadii.pill),
                  ),
                ),
              ),
              if (clamped > 0)
                Positioned(
                  left: 0,
                  top: (lane - trackHeight) / 2,
                  child: Container(
                    width: width * clamped,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: SkyPalette.cyan,
                      borderRadius: BorderRadius.circular(SkyRadii.pill),
                    ),
                  ),
                ),
              for (int index = 0; index < checkpoints.length; index++)
                Positioned(
                  left: (width * checkpoints[index].progress) - dotSize / 2,
                  top: (lane - dotSize) / 2,
                  child: Semantics(
                    label: checkpoints[index].label,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: index < reached
                              ? SkyPalette.mint
                              : const Color(0xFFB6DCEE),
                          width: dotSize >= 10 ? 2.5 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -2,
                top: -2,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.flag_rounded,
                    size: lane + 3,
                    color: SkyPalette.cyan,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
