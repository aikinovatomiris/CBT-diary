import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/diary_entry_model.dart';
import '../../services/api_exception.dart';
import '../../services/diary_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_text_field.dart';

class DiaryEditScreen extends StatefulWidget {
  final String? entryId;
  final DiaryEntryModel? initialEntry;

  const DiaryEditScreen({
    super.key,
    required this.entryId,
    this.initialEntry,
  });

  @override
  State<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends State<DiaryEditScreen> {
  final TextEditingController _situationController = TextEditingController();
  final TextEditingController _automaticThoughtController =
      TextEditingController();
  final TextEditingController _emotionsBeforeController =
      TextEditingController();
  final TextEditingController _evidenceForController = TextEditingController();
  final TextEditingController _evidenceAgainstController =
      TextEditingController();
  final TextEditingController _alternativeThoughtController =
      TextEditingController();
  final TextEditingController _emotionsAfterController =
      TextEditingController();
  final TextEditingController _cognitiveDistortionsController =
      TextEditingController();
  final TextEditingController _conclusionController = TextEditingController();

  late Future<DiaryEntryModel> _entryFuture;

  int? _entryId;
  DiaryEntryModel? _entry;
  bool _controllersInitialized = false;
  bool _isSaving = false;

  late String _initialSituation;
  late String _initialAutomaticThought;
  late String _initialEmotionsBeforeText;
  late String _initialEvidenceFor;
  late String _initialEvidenceAgainst;
  late String _initialAlternativeThought;
  late String _initialEmotionsAfterText;
  late String _initialCognitiveDistortionsText;
  late String _initialConclusion;

  @override
  void initState() {
    super.initState();

    _entryId = int.tryParse(widget.entryId ?? '');

    final initialEntry = widget.initialEntry;

    if (initialEntry != null) {
      _entryFuture = Future.value(initialEntry);
    } else if (_entryId != null) {
      _entryFuture = DiaryService.getEntry(_entryId!);
    }
  }

  @override
  void dispose() {
    _situationController.dispose();
    _automaticThoughtController.dispose();
    _emotionsBeforeController.dispose();
    _evidenceForController.dispose();
    _evidenceAgainstController.dispose();
    _alternativeThoughtController.dispose();
    _emotionsAfterController.dispose();
    _cognitiveDistortionsController.dispose();
    _conclusionController.dispose();
    super.dispose();
  }

  void _initializeControllers(DiaryEntryModel entry) {
    if (_controllersInitialized) {
      return;
    }

    _initialSituation = entry.situation ?? '';
    _initialAutomaticThought = entry.automaticThought ?? '';
    _initialEmotionsBeforeText = _formatJsonFieldForEditing(
      entry.emotionsBefore,
    );
    _initialEvidenceFor = entry.evidenceFor ?? '';
    _initialEvidenceAgainst = entry.evidenceAgainst ?? '';
    _initialAlternativeThought = entry.alternativeThought ?? '';
    _initialEmotionsAfterText = _formatJsonFieldForEditing(
      entry.emotionsAfter,
    );
    _initialCognitiveDistortionsText = _formatJsonFieldForEditing(
      entry.cognitiveDistortions,
    );
    _initialConclusion = entry.conclusion ?? '';

    _situationController.text = _initialSituation;
    _automaticThoughtController.text = _initialAutomaticThought;
    _emotionsBeforeController.text = _initialEmotionsBeforeText;
    _evidenceForController.text = _initialEvidenceFor;
    _evidenceAgainstController.text = _initialEvidenceAgainst;
    _alternativeThoughtController.text = _initialAlternativeThought;
    _emotionsAfterController.text = _initialEmotionsAfterText;
    _cognitiveDistortionsController.text =
        _initialCognitiveDistortionsText;
    _conclusionController.text = _initialConclusion;

    _entry = entry;
    _controllersInitialized = true;
  }

  Future<void> _retry() async {
    final id = _entryId;

    if (id == null) {
      return;
    }

    setState(() {
      _controllersInitialized = false;
      _entryFuture = DiaryService.getEntry(id);
    });

    await _entryFuture;
  }

  Future<void> _save() async {
    final id = _entryId;
    final entry = _entry;

    if (id == null || entry == null) {
      _showSnackBar('Не удалось определить запись для редактирования.');
      return;
    }

    final fields = <String, dynamic>{};

    _addChangedTextField(
      fields: fields,
      key: 'situation',
      currentValue: _situationController.text,
      initialValue: _initialSituation,
    );
    _addChangedTextField(
      fields: fields,
      key: 'automatic_thought',
      currentValue: _automaticThoughtController.text,
      initialValue: _initialAutomaticThought,
    );
    _addChangedJsonField(
      fields: fields,
      key: 'emotions_before',
      currentText: _emotionsBeforeController.text,
      initialText: _initialEmotionsBeforeText,
    );
    _addChangedTextField(
      fields: fields,
      key: 'evidence_for',
      currentValue: _evidenceForController.text,
      initialValue: _initialEvidenceFor,
    );
    _addChangedTextField(
      fields: fields,
      key: 'evidence_against',
      currentValue: _evidenceAgainstController.text,
      initialValue: _initialEvidenceAgainst,
    );
    _addChangedTextField(
      fields: fields,
      key: 'alternative_thought',
      currentValue: _alternativeThoughtController.text,
      initialValue: _initialAlternativeThought,
    );
    _addChangedJsonField(
      fields: fields,
      key: 'emotions_after',
      currentText: _emotionsAfterController.text,
      initialText: _initialEmotionsAfterText,
    );
    _addChangedJsonField(
      fields: fields,
      key: 'cognitive_distortions',
      currentText: _cognitiveDistortionsController.text,
      initialText: _initialCognitiveDistortionsText,
    );
    _addChangedTextField(
      fields: fields,
      key: 'conclusion',
      currentValue: _conclusionController.text,
      initialValue: _initialConclusion,
    );

    if (fields.isEmpty) {
      _showSnackBar('Изменений нет.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedEntry = await DiaryService.updateEntry(
        id,
        fields,
      );

      if (!mounted) return;

      _showSnackBar('Запись обновлена.');
      context.pop(updatedEntry);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось сохранить изменения.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addChangedTextField({
    required Map<String, dynamic> fields,
    required String key,
    required String currentValue,
    required String initialValue,
  }) {
    if (currentValue != initialValue) {
      fields[key] = currentValue;
    }
  }

  void _addChangedJsonField({
    required Map<String, dynamic> fields,
    required String key,
    required String currentText,
    required String initialText,
  }) {
    if (currentText == initialText) {
      return;
    }

    if (currentText.trim().isEmpty) {
      fields[key] = null;
      return;
    }

    fields[key] = currentText;
  }

  String _formatJsonFieldForEditing(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is Map) {
      if (value.isEmpty) {
        return '';
      }

      final rawText = value['raw_text'];

      if (rawText != null) {
        return rawText.toString();
      }

      final items = value['items'];

      if (items is List) {
        return items.map(_formatJsonItem).join('\n');
      }

      return value.entries.map((entry) {
        final key = _humanizeKey(entry.key.toString());
        final formattedValue = _formatJsonItem(entry.value);

        return '$key: $formattedValue';
      }).join('\n');
    }

    if (value is List) {
      return value.map(_formatJsonItem).join('\n');
    }

    return value.toString();
  }

  String _formatJsonItem(dynamic item) {
    if (item == null) {
      return '';
    }

    if (item is Map) {
      final name = item['name'];
      final explanation = item['explanation'];
      final intensity = item['intensity'];
      final value = item['value'];

      final parts = <String>[];

      if (name != null && name.toString().trim().isNotEmpty) {
        parts.add(name.toString().trim());
      }

      if (value != null && value.toString().trim().isNotEmpty) {
        parts.add(value.toString().trim());
      }

      if (intensity != null && intensity.toString().trim().isNotEmpty) {
        parts.add('интенсивность: ${intensity.toString().trim()}');
      }

      if (explanation != null && explanation.toString().trim().isNotEmpty) {
        parts.add(explanation.toString().trim());
      }

      if (parts.isNotEmpty) {
        return parts.join(' — ');
      }

      return item.entries.map((entry) {
        final key = _humanizeKey(entry.key.toString());
        return '$key: ${entry.value}';
      }).join(', ');
    }

    return item.toString();
  }

  String _humanizeKey(String key) {
    switch (key) {
      case 'raw_text':
        return 'Текст';
      case 'items':
        return 'Список';
      case 'name':
        return 'Название';
      case 'explanation':
        return 'Объяснение';
      case 'intensity':
        return 'Интенсивность';
      case 'value':
        return 'Значение';
      default:
        return key;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не заполнено';

    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_entryId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Редактирование'),
        ),
        body: AppErrorView(
          message: 'Не найден ID дневниковой записи.',
          onRetry: () => context.pop(),
          retryText: 'Назад',
        ),
      );
    }

    return FutureBuilder<DiaryEntryModel>(
      future: _entryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppLoading(
              text: 'Загрузка записи...',
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Не удалось загрузить запись.';

          return Scaffold(
            appBar: AppBar(
              title: const Text('Редактирование'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _retry,
            ),
          );
        }

        final entry = snapshot.data;

        if (entry == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Редактирование'),
            ),
            body: AppErrorView(
              message: 'Нет данных записи.',
              onRetry: _retry,
            ),
          );
        }

        _initializeControllers(entry);

        return _DiaryEditContent(
          entry: entry,
          isSaving: _isSaving,
          situationController: _situationController,
          automaticThoughtController: _automaticThoughtController,
          emotionsBeforeController: _emotionsBeforeController,
          evidenceForController: _evidenceForController,
          evidenceAgainstController: _evidenceAgainstController,
          alternativeThoughtController: _alternativeThoughtController,
          emotionsAfterController: _emotionsAfterController,
          cognitiveDistortionsController: _cognitiveDistortionsController,
          conclusionController: _conclusionController,
          formatDate: _formatDate,
          onSave: _save,
        );
      },
    );
  }
}

class _DiaryEditContent extends StatelessWidget {
  final DiaryEntryModel entry;
  final bool isSaving;
  final TextEditingController situationController;
  final TextEditingController automaticThoughtController;
  final TextEditingController emotionsBeforeController;
  final TextEditingController evidenceForController;
  final TextEditingController evidenceAgainstController;
  final TextEditingController alternativeThoughtController;
  final TextEditingController emotionsAfterController;
  final TextEditingController cognitiveDistortionsController;
  final TextEditingController conclusionController;
  final String Function(DateTime?) formatDate;
  final VoidCallback onSave;

  const _DiaryEditContent({
    required this.entry,
    required this.isSaving,
    required this.situationController,
    required this.automaticThoughtController,
    required this.emotionsBeforeController,
    required this.evidenceForController,
    required this.evidenceAgainstController,
    required this.alternativeThoughtController,
    required this.emotionsAfterController,
    required this.cognitiveDistortionsController,
    required this.conclusionController,
    required this.formatDate,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактирование'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide ? 720 : double.infinity,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    110,
                  ),
                  children: [
                    Text(
                      'КПТ-запись',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      formatDate(entry.createdAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _EditableSectionCard(
                      title: 'Ситуация',
                      controller: situationController,
                      hint: 'Опиши ситуацию',
                    ),
                    _EditableSectionCard(
                      title: 'Автоматическая мысль',
                      controller: automaticThoughtController,
                      hint: 'Какая мысль возникла?',
                    ),
                    _EditableSectionCard(
                      title: 'Эмоции до',
                      controller: emotionsBeforeController,
                      hint: 'Например: тревога — 80, страх — 60',
                    ),
                    _EditableSectionCard(
                      title: 'Доказательства за',
                      controller: evidenceForController,
                      hint: 'Какие факты поддерживают мысль?',
                    ),
                    _EditableSectionCard(
                      title: 'Доказательства против',
                      controller: evidenceAgainstController,
                      hint: 'Какие факты ей противоречат?',
                    ),
                    _EditableSectionCard(
                      title: 'Рациональная альтернативная мысль',
                      controller: alternativeThoughtController,
                      hint: 'Сформулируй более сбалансированную мысль',
                    ),
                    _EditableSectionCard(
                      title: 'Эмоции после',
                      controller: emotionsAfterController,
                      hint: 'Например: тревога — 40, страх — 25',
                    ),
                    _EditableSectionCard(
                      title: 'Когнитивные искажения',
                      controller: cognitiveDistortionsController,
                      hint: 'Укажи замеченные когнитивные искажения',
                    ),
                    _EditableSectionCard(
                      title: 'Вывод',
                      controller: conclusionController,
                      hint: 'Что удалось понять после разбора?',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      text: 'Сохранить изменения',
                      icon: Icons.check_rounded,
                      isLoading: isSaving,
                      onPressed: isSaving ? null : onSave,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EditableSectionCard extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hint;

  const _EditableSectionCard({
    required this.title,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        hasShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: controller,
              hint: hint,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }
}
