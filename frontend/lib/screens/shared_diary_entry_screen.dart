import 'package:flutter/material.dart';

import '../models/diary_entry_model.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';

class SharedDiaryEntryScreen extends StatelessWidget {
  final DiaryEntryModel? entry;

  const SharedDiaryEntryScreen({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final diaryEntry = entry;

    if (diaryEntry == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('КПТ-запись'),
        ),
        body: const AppErrorView(
          message: 'Не удалось открыть КПТ-запись.',
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('КПТ-запись'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 760;

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
                    AppSpacing.xl,
                  ),
                  children: [
                    Text(
                      'Переданная КПТ-запись',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Эта запись была отправлена внутри переписки. Она не является публичной ссылкой.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _SectionCard(
                      title: 'Ситуация',
                      content: _textOrEmpty(diaryEntry.situation),
                    ),
                    _SectionCard(
                      title: 'Автоматическая мысль',
                      content: _textOrEmpty(diaryEntry.automaticThought),
                    ),
                    _SectionCard(
                      title: 'Эмоции до',
                      content: _formatJsonField(diaryEntry.emotionsBefore),
                    ),
                    _SectionCard(
                      title: 'Доказательства за',
                      content: _textOrEmpty(diaryEntry.evidenceFor),
                    ),
                    _SectionCard(
                      title: 'Доказательства против',
                      content: _textOrEmpty(diaryEntry.evidenceAgainst),
                    ),
                    _SectionCard(
                      title: 'Рациональная альтернативная мысль',
                      content: _textOrEmpty(diaryEntry.alternativeThought),
                    ),
                    _SectionCard(
                      title: 'Эмоции после',
                      content: _formatJsonField(diaryEntry.emotionsAfter),
                    ),
                    _SectionCard(
                      title: 'Когнитивные искажения',
                      content:
                          _formatJsonField(diaryEntry.cognitiveDistortions),
                    ),
                    _SectionCard(
                      title: 'Вывод',
                      content: _textOrEmpty(diaryEntry.conclusion),
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

  static String _textOrEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Не заполнено';
    }

    return value.trim();
  }

  static String _formatJsonField(dynamic value) {
    if (value == null) {
      return 'Не заполнено';
    }

    if (value is Map) {
      if (value.isEmpty) {
        return 'Не заполнено';
      }

      final rawText = value['raw_text'];

      if (rawText != null && rawText.toString().trim().isNotEmpty) {
        return rawText.toString().trim();
      }

      final items = value['items'];

      if (items is List && items.isNotEmpty) {
        return items.map((item) => _formatJsonItem(item)).join('\n');
      }

      return value.entries.map((entry) {
        final key = _humanizeKey(entry.key.toString());
        final formattedValue = _formatJsonItem(entry.value);

        return '$key: $formattedValue';
      }).join('\n');
    }

    if (value is List) {
      if (value.isEmpty) {
        return 'Не заполнено';
      }

      return value.map((item) => _formatJsonItem(item)).join('\n');
    }

    final text = value.toString().trim();

    if (text.isEmpty || text == '{}') {
      return 'Не заполнено';
    }

    return text;
  }

  static String _formatJsonItem(dynamic item) {
    if (item == null) {
      return 'Не заполнено';
    }

    if (item is Map) {
      final name = item['name'];
      final explanation = item['explanation'];
      final intensity = item['intensity'];
      final value = item['value'];
      final text = item['text'];
      final rawText = item['raw_text'];
      final title = item['title'];

      final parts = <String>[];

      if (name != null && name.toString().trim().isNotEmpty) {
        parts.add(name.toString().trim());
      }

      if (title != null && title.toString().trim().isNotEmpty) {
        parts.add(title.toString().trim());
      }

      if (text != null && text.toString().trim().isNotEmpty) {
        parts.add(text.toString().trim());
      }

      if (rawText != null && rawText.toString().trim().isNotEmpty) {
        parts.add(rawText.toString().trim());
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
        return '• ${parts.join(' — ')}';
      }

      return item.entries.map((entry) {
        final key = _humanizeKey(entry.key.toString());
        return '$key: ${entry.value}';
      }).join(', ');
    }

    return '• ${item.toString()}';
  }

  static String _humanizeKey(String key) {
    switch (key) {
      case 'raw_text':
        return 'Текст';
      case 'items':
        return 'Список';
      case 'name':
        return 'Название';
      case 'title':
        return 'Название';
      case 'text':
        return 'Текст';
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
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String content;

  const _SectionCard({
    required this.title,
    required this.content,
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
            Text(
              content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}