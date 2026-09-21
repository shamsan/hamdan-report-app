/// Robust Arabic text reshaping and BiDi layout helper for PDF rendering.
/// Maps logical Arabic Unicode characters to presentation forms (isolated, initial, medial, final)
/// and handles Lam-Alef ligatures and BiDi visual ordering.
class ArabicReshaper {
  // static const int _charTatweel = 0x0640;

  // Characters that connect to both right and left
  static const Set<int> _dualJoining = {
    0x0626, // Yeh with Hamza
    0x0628, // Beh
    0x062A, // Teh
    0x062B, // Theh
    0x062C, // Jeem
    0x062D, // Hah
    0x062E, // K تطور
    0x0633, // Seen
    0x0634, // Sheen
    0x0635, // Sad
    0x0636, // Dad
    0x0637, // Tah
    0x0638, // Zah
    0x0639, // Ain
    0x063A, // Ghain
    0x0641, // Feh
    0x0642, // Qaf
    0x0643, // Kaf
    0x0644, // Lam
    0x0645, // Meem
    0x0646, // Noon
    0x0647, // Heh
    0x064A, // Yeh
    0x0649, // Alef Maksura (often dual in some forms)
    0x0640, // Tatweel
  };

  // Characters that only connect to the right (never to the left)
  static const Set<int> _rightJoining = {
    0x0622, // Alef with Madda
    0x0623, // Alef with Hamza Above
    0x0624, // Waw with Hamza Above
    0x0625, // Alef with Hamza Below
    0x0627, // Alef
    0x062F, // Dal
    0x0630, // Thal
    0x0631, // Reh
    0x0632, // Zain
    0x0648, // Waw
    0x0629, // Teh Marbuta
  };

  // Forms mapping: [Isolated, Final, Initial, Medial]
  static const Map<int, List<int>> _glyphForms = {
    0x0621: [0xFE80, 0xFE80, 0xFE80, 0xFE80], // Hamza
    0x0622: [0xFE81, 0xFE82, 0xFE81, 0xFE82], // Alef with Madda
    0x0623: [0xFE83, 0xFE84, 0xFE83, 0xFE84], // Alef with Hamza Above
    0x0624: [0xFE85, 0xFE86, 0xFE85, 0xFE86], // Waw with Hamza
    0x0625: [0xFE87, 0xFE88, 0xFE87, 0xFE88], // Alef with Hamza Below
    0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // Yeh with Hamza
    0x0627: [0xFE8D, 0xFE8E, 0xFE8D, 0xFE8E], // Alef
    0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // Beh
    0x0629: [0xFE93, 0xFE94, 0xFE93, 0xFE94], // Teh Marbuta
    0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // Teh
    0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // Theh
    0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // Jeem
    0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // Hah
    0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // Kheh
    0x062F: [0xFEA9, 0xFEAA, 0xFEA9, 0xFEAA], // Dal
    0x0630: [0xFEAB, 0xFEAC, 0xFEAB, 0xFEAC], // Thal
    0x0631: [0xFEAD, 0xFEAE, 0xFEAD, 0xFEAE], // Reh
    0x0632: [0xFEAF, 0xFEB0, 0xFEAF, 0xFEB0], // Zain
    0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // Seen
    0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // Sheen
    0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // Sad
    0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // Dad
    0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // Tah
    0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // Zah
    0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // Ain
    0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // Ghain
    0x0640: [0x0640, 0x0640, 0x0640, 0x0640], // Tatweel
    0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // Feh
    0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // Qaf
    0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // Kaf
    0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // Lam
    0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // Meem
    0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // Noon
    0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // Heh
    0x0648: [0xFEED, 0xFEEE, 0xFEED, 0xFEEE], // Waw
    0x0649: [0xFEEF, 0xFEF0, 0xFBE8, 0xFBE9], // Alef Maksura
    0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // Yeh
  };

  static bool _isArabic(int code) {
    return (code >= 0x0600 && code <= 0x06FF) ||
        (code >= 0xFB50 && code <= 0xFDFF) ||
        (code >= 0xFE70 && code <= 0xFEFF);
  }

  static bool _connectsRight(int code) =>
      _dualJoining.contains(code) || _rightJoining.contains(code);

  static bool _connectsLeft(int code) => _dualJoining.contains(code);

  /// Reshapes an Arabic string so characters connect properly.
  static String reshape(String input) {
    if (input.isEmpty) return input;
    // Strip tatweel (\u0640) so characters join naturally without distorted horizontal lines
    input = input.replaceAll('\u0640', '');

    final runes = input.runes.toList();
    final len = runes.length;
    final buffer = <int>[];

    for (int i = 0; i < len; i++) {
      final cur = runes[i];

      // Handle Lam-Alef ligatures
      if (cur == 0x0644 && i + 1 < len) {
        final next = runes[i + 1];
        int? ligature;
        final prevConnects = i > 0 && _connectsLeft(runes[i - 1]);

        if (next == 0x0622) {
          ligature = prevConnects ? 0xFEF6 : 0xFEF5; // Lam + Alef with Madda
        } else if (next == 0x0623) {
          ligature = prevConnects ? 0xFEF8 : 0xFEF7; // Lam + Alef with Hamza Above
        } else if (next == 0x0625) {
          ligature = prevConnects ? 0xFEFA : 0xFEF9; // Lam + Alef with Hamza Below
        } else if (next == 0x0627) {
          ligature = prevConnects ? 0xFEFC : 0xFEFB; // Lam + Plain Alef
        }

        if (ligature != null) {
          buffer.add(ligature);
          i++; // skip alef
          continue;
        }
      }

      final forms = _glyphForms[cur];
      if (forms == null) {
        buffer.add(cur);
        continue;
      }

      final prevConnects = i > 0 && _connectsLeft(runes[i - 1]);
      final nextConnects = i + 1 < len && _connectsRight(runes[i + 1]);

      int formIndex;
      if (prevConnects && nextConnects && _dualJoining.contains(cur)) {
        formIndex = 3; // Medial
      } else if (prevConnects) {
        formIndex = 1; // Final
      } else if (nextConnects && _dualJoining.contains(cur)) {
        formIndex = 2; // Initial
      } else {
        formIndex = 0; // Isolated
      }

      buffer.add(forms[formIndex]);
    }

    return String.fromCharCodes(buffer);
  }

  static const Map<String, String> _mirrorMap = {
    '(': ')',
    ')': '(',
    '[': ']',
    ']': '[',
    '{': '}',
    '}': '{',
    '<': '>',
    '>': '<',
    '«': '»',
    '»': '«',
  };

  /// Returns true if the string contains any Arabic unicode characters
  static bool hasArabic(String text) {
    for (final code in text.runes) {
      if (_isArabic(code)) return true;
    }
    return false;
  }

  /// Helper to determine if text should flow RTL (Arabic) or LTR (English/Latin/Numbers)
  static bool isRtlText(String text) => hasArabic(text);

  static bool _hasArabic(String text) => hasArabic(text);

  /// Converts text into visual order for LTR renderers (such as standard PDF text elements).
  /// Reverses Arabic words while keeping Latin words and numbers in their natural reading order.
  /// When [maxCharsPerLine] is provided, or when the text contains explicit newlines,
  /// lines are ordered from top to bottom (downwards) so that long notes wrap naturally downwards.
  static String shapeAndBidi(String input, {int? maxCharsPerLine}) {
    if (input.isEmpty) return input;

    // 1. Handle explicit newlines: process each line independently to preserve vertical line order (downwards)
    if (input.contains('\n')) {
      final lines = input.split('\n');
      return lines.map((l) => shapeAndBidi(l, maxCharsPerLine: maxCharsPerLine)).join('\n');
    }

    // 2. Handle long single-line text: wrap by words into logical lines first so wrapped lines flow downwards
    if (maxCharsPerLine != null && maxCharsPerLine > 0 && input.length > maxCharsPerLine) {
      final wrappedLines = _wrapWords(input, maxCharsPerLine);
      return wrappedLines.map((l) => shapeAndBidi(l)).join('\n');
    }

    if (!_hasArabic(input)) return input;

    // Reshape Arabic characters first
    final reshaped = reshape(input);

    // Tokenize text into LTR tokens (English words, units, measurement parentheticals like "(32°C)")
    // and Arabic / punctuation tokens.
    final tokenPattern = RegExp(
      r'[A-Za-z0-9][A-Za-z0-9\s\.\,\:\;\-\_\/\(\)\%\$\°\*\+\=]*[A-Za-z0-9\%\°\)]|\([0-9A-Za-z\s\.\-\/\°\%]+\)|[A-Za-z0-9]',
    );

    final matches = tokenPattern.allMatches(reshaped).toList();
    if (matches.isEmpty) {
      // Pure Arabic/punctuation text: reverse characters and mirror brackets
      final runes = reshaped.runes.toList();
      final reversedBuffer = <String>[];
      for (int i = runes.length - 1; i >= 0; i--) {
        final ch = String.fromCharCode(runes[i]);
        reversedBuffer.add(_mirrorMap[ch] ?? ch);
      }
      return reversedBuffer.join('');
    }

    final tokens = <_TextSegment>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        final arabicChunk = reshaped.substring(lastIndex, match.start);
        tokens.add(_TextSegment(text: arabicChunk, isRtl: true));
      }
      final ltrChunk = match.group(0)!;
      tokens.add(_TextSegment(text: ltrChunk, isRtl: false));
      lastIndex = match.end;
    }

    if (lastIndex < reshaped.length) {
      tokens.add(_TextSegment(text: reshaped.substring(lastIndex), isRtl: true));
    }

    // Visual LTR ordering: reverse token order; reverse characters inside RTL tokens with bracket mirroring
    final resultParts = <String>[];
    for (int i = tokens.length - 1; i >= 0; i--) {
      final token = tokens[i];
      if (token.isRtl) {
        final runes = token.text.runes.toList();
        final revBuffer = <String>[];
        for (int j = runes.length - 1; j >= 0; j--) {
          final ch = String.fromCharCode(runes[j]);
          revBuffer.add(_mirrorMap[ch] ?? ch);
        }
        resultParts.add(revBuffer.join(''));
      } else {
        resultParts.add(token.text);
      }
    }

    return resultParts.join('');
  }

  /// Splits a single line of text into multiple lines by words,
  /// ensuring no line exceeds maxChars unless a single word is longer than maxChars.
  /// Preserves the original logical order (first words at the top, subsequent words going downwards).
  /// Preserves parenthesized and bracketed fill-in blanks (e.g. "(      )") without collapsing spaces.
  static List<String> _wrapWords(String text, int maxChars) {
    if (text.length <= maxChars) return [text];
    final tokenPattern = RegExp(r'\([^\)]*\)[\.\,\:\;\!\؟\?\،]*|\[[^\]]*\][\.\,\:\;\!\؟\?\،]*|\S+');
    final words = tokenPattern.allMatches(text.trim()).map((m) => m.group(0)!).toList();
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      if (word.isEmpty) continue;
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= maxChars) {
        currentLine = '$currentLine $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    return lines.isNotEmpty ? lines : [text];
  }
}

class _TextSegment {
  final String text;
  final bool isRtl;
  _TextSegment({required this.text, required this.isRtl});
}

