import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a Jisho.org search for [query] so answers and explanations can be
/// verified against a dictionary — the same link the web drill provides.
/// Also used generically to open external pages (source-repo credits).
abstract final class JishoLink {
  static String urlFor(String query) {
    final encoded = Uri.encodeComponent(query);
    return 'https://jisho.org/search/$encoded';
  }

  static Future<void> open(BuildContext context, String target) async {
    final Uri url;
    if (target.startsWith('http://') || target.startsWith('https://')) {
      url = Uri.parse(target);
    } else {
      url = Uri.parse(urlFor(target));
    }
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the browser.')),
        );
      }
    }
  }
}
