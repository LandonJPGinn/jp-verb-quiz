import 'package:flutter/material.dart';

/// One piece of a word in kanji[kana] furigana notation.
class FuriganaSegment {
  final String? base; // the visible character(s), null for plain text
  final String? reading; // furigana reading, null for plain text
  final String? text; // plain text

  FuriganaSegment.plain(this.text)
      : base = null,
        reading = null;

  FuriganaSegment.ruby(this.base, this.reading) : text = null;
}

final RegExp _furiganaPattern = RegExp(r'(.)\[([^\]]*)\]');

/// Splits "食[た]べる" into [ruby(食,た), plain(べる)], mirroring
/// wordWithFurigana's parsing in drill.js.
List<FuriganaSegment> parseFurigana(String word) {
  final segments = <FuriganaSegment>[];
  var lastEnd = 0;
  for (final match in _furiganaPattern.allMatches(word)) {
    if (match.start > lastEnd) {
      segments.add(FuriganaSegment.plain(word.substring(lastEnd, match.start)));
    }
    segments.add(FuriganaSegment.ruby(match.group(1), match.group(2)));
    lastEnd = match.end;
  }
  if (lastEnd < word.length) {
    segments.add(FuriganaSegment.plain(word.substring(lastEnd)));
  }
  return segments;
}

/// Renders furigana notation as ruby-style text (small reading above the
/// character), replacing the web app's `<ruby>` markup.
class FuriganaText extends StatelessWidget {
  final String word;
  final TextStyle style;
  final Color? readingColor;

  const FuriganaText(
    this.word, {
    super.key,
    required this.style,
    this.readingColor,
  });

  @override
  Widget build(BuildContext context) {
    final segments = parseFurigana(word);
    if (segments.every((s) => s.base == null)) {
      return Text(word, style: style);
    }

    final readingStyle = TextStyle(
      fontSize: (style.fontSize ?? 16) * 0.45,
      height: 1.0,
      color: readingColor ?? style.color?.withValues(alpha: 0.85),
    );

    return Wrap(
      spacing: 2,
      runSpacing: 4,
      children: [
        for (final seg in segments)
          if (seg.base != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(seg.reading ?? '', style: readingStyle),
                Text(seg.base!, style: style),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(seg.text ?? '', style: style),
            ),
      ],
    );
  }
}
