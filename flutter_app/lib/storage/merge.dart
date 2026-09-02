library;

/// Pure merge logic for the layered storage system.
///
/// Every persisted section is an envelope `{data, updatedAt}` (ms epoch).
/// Conflict rules:
///  - stats (daily + per-form counters): additive — per key take the max of
///    each counter, OR the goal flag. Counters only ever grow, so this loses
///    nothing no matter which side is newer.
///  - presets: per-name last-write-wins (each preset carries updatedAt).
///  - settings / lastOptions / questionLog cursor: whole-section LWW.

typedef Envelope = Map<String, dynamic>; // {data: ..., updatedAt: int}

Envelope makeEnvelope(Map<String, dynamic> data, int updatedAt) =>
    {'data': data, 'updatedAt': updatedAt};

int envTime(Envelope? e) =>
    e == null ? 0 : (e['updatedAt'] as int? ?? 0);

Map<String, dynamic> envData(Envelope? e) =>
    e == null ? {} : Map<String, dynamic>.from(e['data'] as Map? ?? {});

Envelope newerEnvelope(Envelope? a, Envelope? b) {
  if (a == null) return b ?? makeEnvelope({}, 0);
  if (b == null) return a;
  return envTime(a) >= envTime(b) ? a : b;
}

/// Deep-max merge of the stats section: {days: {...}, forms: {...}}.
Map<String, dynamic> mergeStatsData(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map<String, Map<String, dynamic>> asMap(Map<String, dynamic>? raw) => {
        for (final e in (raw ?? <String, dynamic>{}).entries)
          e.key: Map<String, dynamic>.from(e.value as Map),
      };

  final aDays = asMap(a['days']);
  final bDays = asMap(b['days']);
  final days = <String, dynamic>{};
  int maxOf(dynamic x, dynamic y) {
    final xi = x as int? ?? 0;
    final yi = y as int? ?? 0;
    return xi > yi ? xi : yi;
  }

  for (final key in {...aDays.keys, ...bDays.keys}) {
    final x = aDays[key];
    final y = bDays[key];
    if (x == null) {
      days[key] = y!;
    } else if (y == null) {
      days[key] = x;
    } else {
      days[key] = {
        'date': x['date'] ?? y['date'],
        'answered': maxOf(x['answered'], y['answered']),
        'correct': maxOf(x['correct'], y['correct']),
        'goalMet': (x['goalMet'] as bool? ?? false) || (y['goalMet'] as bool? ?? false),
      };
    }
  }

  final aForms = asMap(a['forms']);
  final bForms = asMap(b['forms']);
  final forms = <String, dynamic>{};
  for (final key in {...aForms.keys, ...bForms.keys}) {
    final x = aForms[key];
    final y = bForms[key];
    if (x == null) {
      forms[key] = y!;
    } else if (y == null) {
      forms[key] = x;
    } else {
      forms[key] = {
        'answered': maxOf(x['answered'], y['answered']),
        'correct': maxOf(x['correct'], y['correct']),
      };
    }
  }

  return {'days': days, 'forms': forms};
}

/// Per-name LWW merge of the presets list.
List<dynamic> mergePresetsData(List<dynamic> a, List<dynamic> b) {
  final byName = <String, Map<String, dynamic>>{};
  void addAll(List<dynamic> list) {
    for (final raw in list) {
      final p = Map<String, dynamic>.from(raw as Map);
      final name = p['name'] as String? ?? '';
      final t = p['updatedAt'] as int? ?? 0;
      final existing = byName[name];
      if (existing == null || t >= (existing['updatedAt'] as int? ?? 0)) {
        byName[name] = p;
      }
    }
  }

  addAll(a);
  addAll(b);
  return byName.values.toList();
}

/// Merge two full section-envelope maps; returns only sections that changed
/// relative to [local] (so callers know whether to persist).
Map<String, Envelope> mergeSections({
  required Map<String, Envelope?> local,
  required Map<String, Envelope?> remote,
}) {
  final result = <String, Envelope>{};

  for (final name in {...local.keys, ...remote.keys}) {
    final l = local[name];
    final r = remote[name];
    switch (name) {
      case 'stats':
        if (l == null) {
          if (r != null) result[name] = r;
        } else if (r == null) {
          // local only — nothing to merge in
        } else {
          final lt = envTime(l);
          final rt = envTime(r);
          if (rt > lt) {
            // pull remote counters, but keep anything local has that remote lacks
            final merged = mergeStatsData(envData(l), envData(r));
            final changed = merged.toString() != envData(r).toString();
            result[name] = makeEnvelope(merged, changed ? lt : rt);
          }
          // if local >= remote: local is at least as new; additive fields the
          // remote is missing will flow up on the next push.
        }
      case 'presets':
        if (l == null) {
          if (r != null) result[name] = r;
        } else if (r == null) {
          // local only
        } else {
          final merged = mergePresetsData(
            (envData(l)['list'] as List? ?? []),
            (envData(r)['list'] as List? ?? []),
          );
          final localList = envData(l)['list'] as List? ?? [];
          final same = merged.length == localList.length &&
              merged.every((p) => localList.any(
                  (q) => (q as Map)['name'] == (p as Map)['name'] &&
                      (q)['updatedAt'] == (p)['updatedAt']));
          if (!same) {
            result[name] = makeEnvelope({'list': merged}, envTime(l) > envTime(r) ? envTime(l) : envTime(r));
          }
        }
      default: // settings, lastOptions — whole-section LWW
        final winner = newerEnvelope(l, r);
        if (winner.isNotEmpty && winner != l) {
          result[name] = winner;
        }
    }
  }
  return result;
}
