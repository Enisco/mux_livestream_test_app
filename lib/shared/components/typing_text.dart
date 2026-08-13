import 'package:flutter/material.dart';

import 'package:test_app/utils/app_constants/app_colors.dart';

class TypingSpan {
  const TypingSpan(this.text, this.style);

  final String text;
  final TextStyle style;
}

class TypingLine {
  const TypingLine(this.spans);

  final List<TypingSpan> spans;

  int get length => spans.fold(0, (sum, span) => sum + span.text.length);
}

/// Character-by-character reveal with a blinking caret. One character every
/// 70ms, two intervals at each line break, caret blinking on a 530ms period
/// that settles once the text is fully typed.
class TypingText extends StatefulWidget {
  const TypingText({
    super.key,
    required this.lines,
    this.lineGap = 6,
    this.onCompleted,
  });

  final List<TypingLine> lines;
  final double lineGap;
  final VoidCallback? onCompleted;

  static const charInterval = Duration(milliseconds: 70);
  static const lineBreakIntervals = 2;
  static const caretBlinkPeriod = Duration(milliseconds: 530);
  static const caretRestingOpacity = 0.593;
  static const caretWidth = 2.0;
  static const caretHeight = 24.0;

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _totalTicks;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    // Each line costs its own characters plus a pause before the next line.
    _totalTicks = widget.lines.fold(
      0,
      (sum, line) => sum + line.length + TypingText.lineBreakIntervals,
    );
    _controller = AnimationController(
      vsync: this,
      duration: TypingText.charInterval * _totalTicks,
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_notified) {
        _notified = true;
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _revealedOn(int lineIndex, int tick) {
    var consumed = 0;
    for (var i = 0; i < lineIndex; i++) {
      consumed += widget.lines[i].length + TypingText.lineBreakIntervals;
    }
    return (tick - consumed).clamp(0, widget.lines[lineIndex].length);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final tick = (_controller.value * _totalTicks).floor();
        final done = _controller.isCompleted;
        // The caret follows the line currently being typed.
        var caretLine = widget.lines.length - 1;
        for (var i = 0; i < widget.lines.length; i++) {
          if (_revealedOn(i, tick) < widget.lines[i].length) {
            caretLine = i;
            break;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.lines.length; i++) ...[
              if (i > 0) SizedBox(height: widget.lineGap),
              _line(
                i,
                _revealedOn(i, tick),
                showCaret: i == caretLine,
                done: done,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _line(
    int index,
    int revealed, {
    required bool showCaret,
    required bool done,
  }) {
    final spans = <InlineSpan>[];
    var remaining = revealed;
    for (final span in widget.lines[index].spans) {
      if (remaining <= 0) break;
      final take = remaining < span.text.length ? remaining : span.text.length;
      spans.add(
        TextSpan(text: span.text.substring(0, take), style: span.style),
      );
      remaining -= take;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(TextSpan(children: spans)),
        if (showCaret) _Caret(controller: _controller, settled: done),
      ],
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({required this.controller, required this.settled});

  final AnimationController controller;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final elapsed = controller.duration! * controller.value;
    final phase =
        elapsed.inMilliseconds % TypingText.caretBlinkPeriod.inMilliseconds;
    final visible = phase < TypingText.caretBlinkPeriod.inMilliseconds / 2;
    return Opacity(
      opacity: settled ? TypingText.caretRestingOpacity : (visible ? 1.0 : 0.0),
      child: Container(
        width: TypingText.caretWidth,
        height: TypingText.caretHeight,
        color: AppColors.textPrimary,
      ),
    );
  }
}
