import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

class ExportPreviewScreen extends StatelessWidget {
  final String text;

  const ExportPreviewScreen({
    super.key,
    required this.text,
  });

  String get _exportText {
    final trimmedText = text.trim();

    if (trimmedText.isEmpty) {
      return 'Не удалось получить текст для экспорта.';
    }

    return trimmedText;
  }

  Future<void> _copyText(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: _exportText),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Текст скопирован.'),
      ),
    );
  }

  Future<void> _shareText(BuildContext context) async {
    final exportText = _exportText;

    if (exportText.trim().isEmpty ||
        exportText == 'Не удалось получить текст для экспорта.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет текста для отправки.'),
        ),
      );
      return;
    }

    await Share.share(
      exportText,
      subject: 'КПТ-запись',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exportText = _exportText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Экспорт записи'),
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
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.xl,
                          AppSpacing.lg,
                        ),
                        children: [
                          Text(
                            'Текст для экспорта',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Можно скопировать текст или поделиться им через доступные приложения.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          AppCard(
                            hasShadow: false,
                            child: SelectableText(
                              exportText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            text: 'Скопировать текст',
                            icon: Icons.copy_rounded,
                            onPressed: () => _copyText(context),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            text: 'Поделиться',
                            icon: Icons.ios_share_rounded,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _shareText(context),
                          ),
                        ],
                      ),
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