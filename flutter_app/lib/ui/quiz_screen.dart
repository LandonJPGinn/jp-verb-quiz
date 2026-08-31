import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/conjugation.dart';
import '../engine/models.dart';
import '../engine/options.dart';
import '../engine/romaji.dart';
import '../state/app_store.dart';
import 'complete_screen.dart';
import 'jisho_link.dart';
import 'theme.dart';
import 'widgets.dart';

final RegExp japaneseTextPattern = RegExp(
    r'^[\u{3040}-\u{309f}\u{30a0}-\u{30ff}\u{3190}-\u{319f}\u{31f0}-\u{31ff}\u{3400}-\u{4dbf}\u{4e00}-\u{9ffc}\u{f900}-\u{faff}\u{ff00}-\u{ffef}\u{1b000}-\u{1b0ff}\u{1b100}-\u{1b12f}\u{1b130}-\u{1b16f}\u{20000}-\u{2a6dd}\u{2a700}-\u{2b734}\u{2b740}-\u{2b81d}\u{2b820}-\u{2cea1}\u{2ceb0}-\u{2ebe0}\u{2f800}-\u{2fa1f}\u{30000}-\u{3134a}]*$',
    unicode: true);

/// The quiz: question card, romaji input, feedback and an inline explanation.
///
/// Wrong answers are re-queued: a session only ends once every question has
/// been answered correctly, so "mastered" is what the progress bar tracks.
class QuizScreen extends StatefulWidget {
  final ConjugationEngine engine;
  final AppStore store;
  final QuizOptions options;

  const QuizScreen({
    super.key,
    required this.engine,
    required this.store,
    required this.options,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _random = Random();

  QuizQuestion? _question;
  final List<QuizQuestion> _requeue = [];
  int _mastered = 0;
  int _attempts = 0;
  bool _phaseFeedback = false;
  bool _lastCorrect = false;
  bool _explainVisible = false;
  String _lastResponse = '';

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void initState() {
    super.initState();
    _nextQuestion();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _useButtonSubmit =>
      widget.store.settings.submitMode == SubmitMode.button;

  void _nextQuestion() {
    // Re-queued mistakes come back interleaved with fresh questions.
    QuizQuestion? q;
    if (_requeue.isNotEmpty && _random.nextBool()) {
      q = _requeue.removeAt(0);
    } else {
      q = widget.engine.generateQuestion(
        widget.engine.questionPoolFor(widget.options),
        widget.options,
        _random,
      );
    }
    if (q == null) {
      _finish();
      return;
    }
    setState(() {
      _question = q;
      _phaseFeedback = false;
      _explainVisible = false;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _submitAnswer() {
    if (_phaseFeedback) return;
    final response = _controller.text.trim();
    final valid = response.isNotEmpty && japaneseTextPattern.hasMatch(response);
    if (!valid) {
      _shakeController.forward(from: 0);
      return;
    }

    final q = _question!;
    final correct =
        q.answer.contains(response) || q.answerKana.contains(response);

    // Every attempt counts toward today's activity — wrong or right.
    widget.store.recordAnswer(correct: correct, form: q.transformation.to);

    setState(() {
      _attempts++;
      _lastCorrect = correct;
      _lastResponse = response;
      _phaseFeedback = true;
      _controller.clear();
      if (correct) {
        _mastered++;
      } else {
        _requeue.add(q); // comes back later in the session
      }
    });

    if (correct && widget.store.settings.autoNextOnCorrect) {
      Future.delayed(const Duration(milliseconds: 350), _proceed);
    } else if (!correct && widget.store.settings.autoExplainOnWrong) {
      setState(() => _explainVisible = true);
    }
  }

  void _proceed() {
    if (!mounted) return;
    if (_mastered >= widget.options.questionCount) {
      _finish();
    } else {
      _nextQuestion();
    }
  }

  void _finish() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CompleteScreen(
          mastered: _mastered,
          attempts: _attempts,
          store: widget.store,
        ),
      ),
    );
  }

  /// Confirmation-aware cancel: closes the session when the user accepts.
  /// Attempts already made stay counted toward today's stats.
  Future<void> _attemptCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End session?'),
        content: Text(
          _attempts == 0
              ? 'No attempts yet — nothing will be lost.'
              : '$_attempts ${_attempts == 1 ? "attempt" : "attempts"} already '
                  'count toward today\'s activity.',
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Keep going'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('End session'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || shouldCancel != true) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.options.questionCount;
    final q = _question;

    if (q == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _attemptCancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _attemptCancel,
          ),
          title: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        total == 0 ? 0 : (_mastered / total).clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.indigoSoftDark
                            : AppColors.indigoSoft,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.indigo),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StreakBadge(
                  streak: widget.store.stats.currentStreak, flameSize: 20),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final dx = sin(t * pi * 8) * 6 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child!);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.viewPaddingOf(context).bottom + 24),
            children: [
              _questionCard(context, q),
              const SizedBox(height: 20),
              if (!_phaseFeedback) ..._inputArea(),
              if (_phaseFeedback) ..._feedbackArea(context, q),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ question

  Widget _questionCard(BuildContext context, QuizQuestion q) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final instruction = _instructionText(q);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? AppColors.indigoSoftDark : AppColors.indigoSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              // Always a single line: scales down however long it gets.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  instruction,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        dark ? const Color(0xFFB9D0F2) : AppColors.indigoDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_levelBadge(q) != null)
              Text(
                _levelBadge(q)!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: muted(context, 0.6),
                ),
              ),
            const SizedBox(height: 12),
            WordText(
              q.givenWord,
              kanaMode: widget.options.kana,
              furigana: widget.store.settings.furiganaAlways,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "N5 · Top 100" style badge so every question shows its source list.
  String? _levelBadge(QuizQuestion q) {
    final word = widget.engine.words[q.entry];
    if (word == null) return null;
    final badges = <String>[
      if (word.level.isNotEmpty) word.level,
      if (word.tags.contains('common')) 'Top 100',
    ];
    return badges.isEmpty ? null : badges.join(' · ');
  }

  /// "convert the following to the past tense" -> "Convert to the past tense"
  /// (single spaces — no double gap where the word was removed).
  String _instructionText(QuizQuestion q) {
    final phrase =
        ConjugationEngine.questionPhrases[q.transformation.phrase] ??
            q.transformation.phrase;
    var text = phrase.replaceFirst(' the following', '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return text;
    return text.characters.first.toUpperCase() + text.substring(1);
  }

  // -------------------------------------------------------------- input

  List<Widget> _inputArea() {
    return [
      TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        textInputAction:
            _useButtonSubmit ? TextInputAction.none : TextInputAction.done,
        onSubmitted: _useButtonSubmit ? null : (_) => _submitAnswer(),
        onChanged:
            widget.store.settings.romajiConversion ? _onInputChanged : null,
        decoration: const InputDecoration(
          hintText: '答え',
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
        inputFormatters: [LengthLimitingTextInputFormatter(40)],
      ),
      const SizedBox(height: 14),
      if (_useButtonSubmit)
        FilledButton.icon(
          onPressed: _submitAnswer,
          icon: const Icon(Icons.check),
          label: const Text('Check'),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Press Enter to check',
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.75),
            ),
          ),
        ),
    ];
  }

  /// Romaji -> hiragana conversion on every keystroke (case-insensitive).
  void _onInputChanged(String value) {
    final pos = _controller.selection.baseOffset;
    if (pos < 0 || pos > value.length) return;
    final (newValue, newPos) = convertRomajiAtCursor(value, pos);
    if (newValue != value) {
      _controller.value = TextEditingValue(
        text: newValue,
        selection: TextSelection.collapsed(offset: newPos),
      );
    }
  }

  // ----------------------------------------------------------- feedback

  List<Widget> _feedbackArea(BuildContext context, QuizQuestion q) {
    final settings = widget.store.settings;
    final total = widget.options.questionCount;
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _lastCorrect ? AppColors.successSoft : AppColors.errorSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _lastCorrect ? AppColors.success : AppColors.error,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _lastCorrect ? Icons.check_circle : Icons.cancel,
              color: _lastCorrect ? AppColors.success : AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _lastCorrect ? 'Correct!' : 'Not quite',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _lastCorrect ? AppColors.success : AppColors.error,
              ),
            ),
            if (!_lastCorrect) ...[
              const SizedBox(height: 12),
              Text(
                'Your answer',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _lastResponse,
                style: TextStyle(
                  fontSize: 20,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppColors.error,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Correct answer',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final a in q.answerFurigana)
                    WordText(
                      a,
                      kanaMode: widget.options.kana,
                      furigana: settings.furiganaAlways,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'This one will come back later in the session.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (!_lastCorrect)
        OutlinedButton.icon(
          onPressed: () => setState(() => _explainVisible = !_explainVisible),
          icon: Icon(_explainVisible
              ? Icons.unfold_less
              : Icons.menu_book_outlined),
          label: Text(_explainVisible ? 'Hide explanation' : 'Why?'),
        ),
      if (!_lastCorrect && _explainVisible) ...[
        const SizedBox(height: 14),
        ExplanationCard(
          engine: widget.engine,
          question: q,
          options: widget.options,
          settings: settings,
        ),
      ],
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _proceed,
        icon: const Icon(Icons.arrow_forward),
        label: Text(_mastered >= total ? 'Finish' : 'Next question'),
      ),
    ];
  }
}

/// Inline explanation shown directly on the quiz page under the feedback card
/// (replaces the old pop-up sheet).
class ExplanationCard extends StatelessWidget {
  final ConjugationEngine engine;
  final QuizQuestion question;
  final QuizOptions options;
  final AppSettings settings;

  const ExplanationCard({
    super.key,
    required this.engine,
    required this.question,
    required this.options,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final word = engine.words[question.entry]!;
    final t = question.transformation;
    final isTrick = t.tags.contains('trick');
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dark = Theme.of(context).brightness == Brightness.dark;

    var dictionary = engine.conjugationFor(question.entry, 'dictionary').forms;
    if (word.group == 'na-adjective') {
      dictionary =
          dictionary.map((d) => d.replaceAll(RegExp(r'だ$'), '')).toList();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WordText(
              dictionary.first,
              kanaMode: options.kana,
              furigana: settings.furiganaAlways,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              word.meaning,
              style:
                  TextStyle(fontSize: 13.5, color: onSurface.withValues(alpha: 0.75)),
            ),
            if (word.sentences.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      dark ? AppColors.indigoSoftDark : AppColors.indigoSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WordText(
                      word.sentences[0],
                      kanaMode: false,
                      furigana: false,
                      style: TextStyle(fontSize: 15, color: onSurface),
                    ),
                    if (word.sentences.length > 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.sentences[1],
                        style: TextStyle(
                          fontSize: 12.5,
                          color: onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => JishoLink.open(context, word.sentences[0]),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Check on Jisho.org',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _step('1', 'Recognise the given form', [
              WordText(
                question.givenWord,
                kanaMode: options.kana,
                furigana: settings.furiganaAlways,
                style: TextStyle(fontSize: 18, color: onSurface),
              ),
              const SizedBox(height: 6),
              Wrap(children: [for (final tag in t.fromTags) TagChip(tag)]),
              Text(
                'form of the ${ConjugationEngine.groupLabels[word.group] ?? word.group}.',
                style: const TextStyle(fontSize: 13.5),
              ),
            ], titleColor: onSurface),
            _step('2', 'Change the form', [
              Text(
                isTrick
                    ? 'The question asked for the "${t.phrase}" version, but that was already the case — a trick question.'
                    : 'The question asked for the "${t.phrase}" version:',
                style: const TextStyle(fontSize: 13.5),
              ),
              if (!isTrick)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child:
                      Wrap(children: [for (final tag in t.toTags) TagChip(tag)]),
                ),
            ], titleColor: onSurface),
            _step('3', 'The correct answer', [
              if (question.answerFurigana.length == 1)
                WordText(
                  question.answerFurigana.first,
                  kanaMode: options.kana,
                  furigana: settings.furiganaAlways,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in question.answerFurigana)
                      WordText(
                        a,
                        kanaMode: options.kana,
                        furigana: settings.furiganaAlways,
                        style: TextStyle(fontSize: 19, color: onSurface),
                      ),
                  ],
                ),
            ], titleColor: onSurface),
            if (word.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  word.notes[0],
                  style: TextStyle(
                    fontSize: 12,
                    color: onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _step(String number, String title, List<Widget> children,
      {required Color titleColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.indigo,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 5),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
