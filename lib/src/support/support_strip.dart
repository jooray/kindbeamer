// SYNCED COPY of support-widget/flutter/lib/support/support_strip.dart. Do not edit here:
// change the canonical file and run support-widget/flutter/sync.sh <this repo>.
// Support ask: the strip. Not a modal: a block in the place where a result is shown.
// Canonical source: support-widget/flutter/lib/support/support_strip.dart (copied to apps by flutter/sync.sh).
// Visual reference: support-widget/spec/ask-preview.html. Rules: support-widget/spec/ask.md.
//
// Built from basic widgets only (no Material ancestor needed), so it takes the host app's own look
// through [SupportStyle]. Never takes focus on its own, never animates anything but a 160 ms fade-in.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'support_controller.dart';
import 'support_copy.dart';

/// How the strip looks in a given app. Every value comes from the app's own palette and type.
class SupportStyle {
  const SupportStyle({
    required this.ground,
    required this.border,
    required this.ink,
    required this.mid,
    required this.faint,
    required this.focus,
    required this.body,
    required this.label,
    required this.small,
    this.cap,
    this.radius = 0,
    this.buttonBorder = 2,
    this.buttonBorderColor,
    this.uppercaseButtons = true,
  });

  /// Fill of the strip.
  final Color ground;

  /// 1 px outline of the strip.
  final Color border;
  final Color ink;

  /// "Not now".
  final Color mid;

  /// "Don't ask again".
  final Color faint;

  /// Keyboard focus ring.
  final Color focus;
  final TextStyle body;

  /// Button label face (size and weight; colour is applied here).
  final TextStyle label;
  final TextStyle small;

  /// A 4 px accent cap inside the top edge (the specimen voice); null for none.
  final Color? cap;
  final double radius;
  final double buttonBorder;

  /// Defaults to [ink].
  final Color? buttonBorderColor;
  final bool uppercaseButtons;
}

class SupportStrip extends StatelessWidget {
  const SupportStrip({
    super.key,
    required this.controller,
    required this.copy,
    required this.style,
    required this.brightness,
    this.lang,
  });

  final SupportController controller;
  final SupportCopy copy;
  final SupportStyle style;

  /// The theme the app is showing right now; the checkout follows it.
  final Brightness brightness;

  /// The app's UI language, or null if the app is not localized (the checkout follows the browser).
  final String? lang;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.visible) return const SizedBox.shrink();
        final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: reduced ? 1 : 0, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final s = style;
    final yes = s.uppercaseButtons ? copy.yes.toUpperCase() : copy.yes;
    final later = s.uppercaseButtons ? copy.later.toUpperCase() : copy.later;
    return Semantics(
      container: true,
      liveRegion: true,
      label: copy.region,
      child: CallbackShortcuts(
        // Escape means "Not now", but only while focus is inside the strip: the host app keeps its own Escape.
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): controller.hide,
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: s.ground,
            border: Border.all(color: s.border, width: 1),
            borderRadius: BorderRadius.circular(s.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.cap != null) Container(height: 4, color: s.cap),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.text, style: s.body.copyWith(color: s.ink)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StripButton(
                          label: yes,
                          semanticLabel: copy.yes,
                          style: s,
                          outlined: true,
                          onPressed: () => controller.support(
                            lang: lang,
                            dark: brightness == Brightness.dark,
                          ),
                        ),
                        _StripButton(
                          label: later,
                          semanticLabel: copy.later,
                          style: s,
                          outlined: false,
                          onPressed: controller.hide,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _StripLink(
                      label: copy.never,
                      style: s,
                      onPressed: controller.declineForever,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripButton extends StatefulWidget {
  const _StripButton({
    required this.label,
    required this.semanticLabel,
    required this.style,
    required this.outlined,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final SupportStyle style;
  final bool outlined;
  final VoidCallback onPressed;

  @override
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final text = Text(
      widget.label,
      style: s.label.copyWith(
        color: widget.outlined ? s.ink : s.mid,
        decoration: widget.outlined
            ? TextDecoration.none
            : TextDecoration.underline,
        decorationColor: s.mid,
      ),
    );
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          label: widget.semanticLabel,
          excludeSemantics: true,
          onTap: widget.onPressed,
          child: Container(
            // The focus ring sits 2 px outside the button, so it never changes the layout.
            margin: const EdgeInsets.all(0),
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border: Border.all(color: s.focus, width: 2),
                    borderRadius: BorderRadius.circular(s.radius),
                  )
                : null,
            constraints: const BoxConstraints(minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: widget.outlined ? 16 : 8),
            decoration: widget.outlined
                ? BoxDecoration(
                    border: Border.all(
                      color: s.buttonBorderColor ?? s.ink,
                      width: s.buttonBorder,
                    ),
                    borderRadius: BorderRadius.circular(s.radius),
                  )
                : null,
            // widthFactor: 1 keeps the button as wide as its label; a Container's own `alignment` would
            // take all the width it is offered and turn every button into a full row.
            child: Center(widthFactor: 1, child: text),
          ),
        ),
      ),
    );
  }
}

class _StripLink extends StatefulWidget {
  const _StripLink({
    required this.label,
    required this.style,
    required this.onPressed,
  });

  final String label;
  final SupportStyle style;
  final VoidCallback onPressed;

  @override
  State<_StripLink> createState() => _StripLinkState();
}

class _StripLinkState extends State<_StripLink> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Semantics(
          button: true,
          label: widget.label,
          excludeSemantics: true,
          onTap: widget.onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32),
            foregroundDecoration: _focused
                ? BoxDecoration(border: Border.all(color: s.focus, width: 2))
                : null,
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(
                widget.label,
                style: s.small.copyWith(
                  color: s.faint,
                  decoration: TextDecoration.underline,
                  decorationColor: s.faint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
