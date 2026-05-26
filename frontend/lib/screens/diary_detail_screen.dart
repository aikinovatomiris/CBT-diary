import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/diary_entry_model.dart';
import '../navigation/app_routes.dart';
import '../services/api_exception.dart';
import '../services/diary_service.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_error_view.dart';
import '../widgets/app_loading.dart';

class DiaryDetailScreen extends StatefulWidget {
  final String? entryId;

  const DiaryDetailScreen({
    super.key,
    required this.entryId,
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  late Future<DiaryEntryModel> _entryFuture;

  int? _entryId;
  bool _isExporting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _entryId = int.tryParse(widget.entryId ?? '');

    if (_entryId != null) {
      _entryFuture = _loadEntry();
    }
  }

  Future<DiaryEntryModel> _loadEntry() async {
    final id = _entryId;

    if (id == null) {
      throw const ApiException(
        message: 'Не найден ID дневниковой записи.',
      );
    }

    return DiaryService.getEntry(id);
  }

  Future<void> _refresh() async {
    setState(() {
      _entryFuture = _loadEntry();
    });

    await _entryFuture;
  }

  Future<void> _exportEntry() async {
    final id = _entryId;

    if (id == null) {
      _showSnackBar('Не найден ID записи.');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final text = await DiaryService.exportEntryText(id);

      if (!mounted) return;

      context.push(
        AppRoutes.exportPreview,
        extra: text,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось экспортировать запись.');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _deleteEntry() async {
    final id = _entryId;

    if (id == null) {
      _showSnackBar('Не найден ID записи.');
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);

        return AlertDialog(
          title: const Text('Удалить запись?'),
          content: const Text(
            'Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Удалить',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await DiaryService.deleteEntry(id);

      if (!mounted) return;

      _showSnackBar('Запись удалена.');

      context.go(AppRoutes.diary);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Не удалось удалить запись.');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не заполнено';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year, $hour:$minute';
  }

  String _safeText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Не заполнено';
    }

    return value.trim();
  }

  String _formatJsonField(dynamic value) {
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

  String _formatJsonItem(dynamic item) {
    if (item == null) {
      return 'Не заполнено';
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
        return '• ${parts.join(' — ')}';
      }

      return item.entries.map((entry) {
        final key = _humanizeKey(entry.key.toString());
        return '$key: ${entry.value}';
      }).join(', ');
    }

    return '• ${item.toString()}';
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
          title: const Text('Запись'),
        ),
        body: AppErrorView(
          message: 'Не найден ID дневниковой записи.',
          onRetry: () => context.go(AppRoutes.diary),
          retryText: 'К дневнику',
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
              title: const Text('Запись'),
            ),
            body: AppErrorView(
              message: message,
              onRetry: _refresh,
            ),
          );
        }

        final entry = snapshot.data;

        if (entry == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Запись'),
            ),
            body: AppErrorView(
              message: 'Нет данных записи.',
              onRetry: _refresh,
            ),
          );
        }

        return _DiaryDetailContent(
          entry: entry,
          isExporting: _isExporting,
          isDeleting: _isDeleting,
          onExport: _exportEntry,
          onDelete: _deleteEntry,
          formatDate: _formatDate,
          safeText: _safeText,
          formatJsonField: _formatJsonField,
        );
      },
    );
  }
}

class _DiaryDetailContent extends StatelessWidget {
  final DiaryEntryModel entry;
  final bool isExporting;
  final bool isDeleting;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final String Function(DateTime?) formatDate;
  final String Function(String?) safeText;
  final String Function(dynamic) formatJsonField;

  const _DiaryDetailContent({
    required this.entry,
    required this.isExporting,
    required this.isDeleting,
    required this.onExport,
    required this.onDelete,
    required this.formatDate,
    required this.safeText,
    required this.formatJsonField,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Запись'),
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

                    _SectionCard(
                      title: 'Ситуация',
                      content: safeText(entry.situation),
                    ),
                    _SectionCard(
                      title: 'Автоматическая мысль',
                      content: safeText(entry.automaticThought),
                    ),
                    _SectionCard(
                      title: 'Эмоции до',
                      content: formatJsonField(entry.emotionsBefore),
                    ),
                    _SectionCard(
                      title: 'Доказательства за',
                      content: safeText(entry.evidenceFor),
                    ),
                    _SectionCard(
                      title: 'Доказательства против',
                      content: safeText(entry.evidenceAgainst),
                    ),
                    _SectionCard(
                      title: 'Рациональная альтернативная мысль',
                      content: safeText(entry.alternativeThought),
                    ),
                    _SectionCard(
                      title: 'Эмоции после',
                      content: formatJsonField(entry.emotionsAfter),
                    ),
                    _SectionCard(
                      title: 'Когнитивные искажения',
                      content: formatJsonField(entry.cognitiveDistortions),
                    ),
                    _SectionCard(
                      title: 'Вывод',
                      content: safeText(entry.conclusion),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    AppButton(
                      text: 'Экспортировать',
                      icon: Icons.ios_share_rounded,
                      isLoading: isExporting,
                      onPressed: isDeleting ? null : onExport,
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppButton(
                      text: 'Удалить',
                      icon: Icons.delete_outline_rounded,
                      variant: AppButtonVariant.ghost,
                      isLoading: isDeleting,
                      onPressed: isExporting ? null : onDelete,
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