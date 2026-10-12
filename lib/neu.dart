import 'dart:math' as math;

import 'package:aura_music/app_scope.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Fixed palette (the accent colour comes from the settings)
// ---------------------------------------------------------------------------
const Color kBackground = Color(0xFF121212);
const Color kBackgroundTop = Color(0xFF1B1B21);
const Color kSurface = Color(0xFF1C1C22);
const Color kSurfaceLight = Color(0xFF25252C);
const Color kSurfaceDark = Color(0xFF16161B);
const String kFont = 'Poppins';

ThemeData buildAuraTheme(Color accent, Color accentSoft) {
  final ThemeData base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    cardColor: kSurface,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accentSoft,
      surface: kSurface,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kFont,
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kSurfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: kFont,
        fontSize: 14,
        color: Colors.white,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      modalBackgroundColor: kSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kSurfaceLight,
      contentTextStyle: const TextStyle(fontFamily: kFont, color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionHandleColor: accent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
  );
}

// ---------------------------------------------------------------------------
// Background
// ---------------------------------------------------------------------------
class NeuBackground extends StatelessWidget {
  const NeuBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[kBackgroundTop, kBackground, Color(0xFF0B0B0E)],
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// App logo (assets/app_logo.png) in a small glowing rounded tile.
// If the image cannot be loaded, a music icon is shown instead.
// ---------------------------------------------------------------------------
class AuraLogo extends StatelessWidget {
  const AuraLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    final BorderRadius radius = BorderRadius.circular(size * 0.3);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 10),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) =>
              Container(
            color: kSurfaceDark,
            child: Icon(
              Icons.graphic_eq_rounded,
              color: accent,
              size: size * 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Core neumorphic container: raised (dark shadow + light glow) or inset.
// ---------------------------------------------------------------------------
class NeuBox extends StatelessWidget {
  const NeuBox({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.inset = false,
    this.glow = false,
    this.depth = 1.0,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final bool inset;
  final bool glow;
  final double depth;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    final bool isCircle = shape == BoxShape.circle;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: isCircle ? null : BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: inset
              ? const <Color>[Color(0xFF101014), Color(0xFF212127)]
              : const <Color>[kSurfaceLight, kSurfaceDark],
        ),
        border: Border.all(
          color: glow
              ? accent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.04),
          width: glow ? 1.2 : 1,
        ),
        boxShadow: inset
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  offset: Offset(5 * depth, 5 * depth),
                  blurRadius: 12 * depth,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.045),
                  offset: Offset(-4 * depth, -4 * depth),
                  blurRadius: 10 * depth,
                ),
                if (glow)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 18,
                  ),
              ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Round neumorphic button (raised -> inset when pressed). `filled` = accent.
// ---------------------------------------------------------------------------
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 44,
    this.iconSize = 22,
    this.filled = false,
    this.loading = false,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool filled;
  final bool loading;
  final bool active;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    final Color accentSoft = context.accentSoft;

    final Widget content = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: widget.filled ? Colors.white : accent,
            ),
          )
        : Icon(
            widget.icon,
            size: widget.iconSize,
            color: widget.filled
                ? Colors.white
                : (widget.active ? accentSoft : Colors.white70),
          );

    final Widget body = widget.filled
        ? Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[accentSoft, accent],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.55),
                  blurRadius: _pressed ? 8 : 18,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(3, 3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(child: content),
          )
        : SizedBox(
            width: widget.size,
            height: widget.size,
            child: NeuBox(
              shape: BoxShape.circle,
              inset: _pressed,
              glow: widget.active,
              depth: 0.6,
              child: Center(child: content),
            ),
          );

    final Widget gesture = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: body,
      ),
    );

    return widget.tooltip == null
        ? gesture
        : Tooltip(message: widget.tooltip!, child: gesture);
  }
}

// ---------------------------------------------------------------------------
// Pill button with icon + label
// ---------------------------------------------------------------------------
class NeuPillButton extends StatelessWidget {
  const NeuPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    final Color accentSoft = context.accentSoft;

    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 20, color: filled ? Colors.white : accentSoft),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: filled
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[accentSoft, accent],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: row,
            )
          : NeuBox(
              radius: 26,
              depth: 0.7,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: row,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small selectable chip
// ---------------------------------------------------------------------------
class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? <Color>[
                    accent.withValues(alpha: 0.32),
                    accent.withValues(alpha: 0.12),
                  ]
                : const <Color>[kSurfaceLight, kSurfaceDark],
          ),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.04),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings tile: icon + title + current value + chevron
// ---------------------------------------------------------------------------
class NeuTile extends StatelessWidget {
  const NeuTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: NeuBox(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 42,
              height: 42,
              child: NeuBox(
                shape: BoxShape.circle,
                inset: true,
                child: Center(
                  child: Icon(icon, size: 20, color: context.accentSoft),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.accentSoft,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Choice dialog (used by the settings): returns the chosen value or null.
// ---------------------------------------------------------------------------
class NeuChoice<T> {
  const NeuChoice({required this.value, required this.label, this.leading});

  final T value;
  final String label;
  final Widget? leading;
}

Future<T?> showNeuChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required List<NeuChoice<T>> choices,
  required T selected,
}) {
  return showDialog<T>(
    context: context,
    builder: (BuildContext dialogContext) {
      final Color accent = dialogContext.accent;
      return Dialog(
        backgroundColor: kSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  children: <Widget>[
                    for (final NeuChoice<T> choice in choices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              Navigator.of(dialogContext).pop(choice.value),
                          child: NeuBox(
                            radius: 16,
                            depth: 0.6,
                            glow: choice.value == selected,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: <Widget>[
                                if (choice.leading != null) ...<Widget>[
                                  choice.leading!,
                                  const SizedBox(width: 14),
                                ],
                                Expanded(
                                  child: Text(
                                    choice.label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: choice.value == selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (choice.value == selected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Animated equalizer bars
// ---------------------------------------------------------------------------
class EqualizerIcon extends StatefulWidget {
  const EqualizerIcon({
    super.key,
    required this.animate,
    this.color,
    this.size = 18,
  });

  final bool animate;
  final Color? color;
  final double size;

  @override
  State<EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<EqualizerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? context.accentSoft;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List<Widget>.generate(4, (int i) {
              final double wave = widget.animate
                  ? 0.5 +
                      0.5 *
                          math.sin(
                            2 * math.pi * (_controller.value + i * 0.23),
                          )
                  : 0.3;
              return Container(
                width: widget.size / 6,
                height: widget.size * (0.25 + 0.75 * wave),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Centered status message (permission, empty, error, placeholders)
// ---------------------------------------------------------------------------
class StatusMessage extends StatelessWidget {
  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 96,
              height: 96,
              child: NeuBox(
                shape: BoxShape.circle,
                child: Icon(icon, size: 40, color: context.accentSoft),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white60),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Neumorphic tab bar
// ---------------------------------------------------------------------------
class NeuTabBar extends StatelessWidget {
  const NeuTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    return NeuBox(
      radius: 22,
      padding: const EdgeInsets.all(5),
      child: Row(
        children: List<Widget>.generate(labels.length, (int i) {
          final bool selected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: selected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            accent.withValues(alpha: 0.32),
                            accent.withValues(alpha: 0.12),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.5),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 14,
                          ),
                        ],
                      )
                    : const BoxDecoration(),
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Neumorphic bottom navigation (wraps a real BottomNavigationBar)
// ---------------------------------------------------------------------------
class NeuBottomNav extends StatelessWidget {
  const NeuBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.accent;
    final List<Shadow> glow = <Shadow>[
      Shadow(color: accent.withValues(alpha: 0.9), blurRadius: 14),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: onTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: accent,
            unselectedItemColor: Colors.white38,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(
              fontFamily: kFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: kFont,
              fontSize: 11,
            ),
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded, shadows: glow),
                label: context.tr('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music_rounded, shadows: glow),
                label: context.tr('library'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded, shadows: glow),
                label: context.tr('settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App bars
// ---------------------------------------------------------------------------

/// Main app bar: "Title" + the app logo right next to it.
PreferredSizeWidget buildAuraAppBar({
  required String title,
  Widget? customTitle,
  List<Widget> actions = const <Widget>[],
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: 64,
    titleSpacing: 20,
    title: customTitle ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const AuraLogo(size: 32),
          ],
        ),
    actions: actions,
  );
}

/// App bar for inner pages: round back button + title.
PreferredSizeWidget buildSubAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const <Widget>[],
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    toolbarHeight: 64,
    automaticallyImplyLeading: false,
    titleSpacing: 16,
    title: Row(
      children: <Widget>[
        NeuButton(
          icon: Icons.arrow_back_rounded,
          size: 40,
          iconSize: 20,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kFont,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
    actions: actions,
  );
}