// ignore_for_file: deprecated_member_use, unused_element

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/cbt_message_model.dart';
import '../../models/cbt_session_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/api_exception.dart';
import '../../services/cbt_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_error_view.dart';
import '../../widgets/app_loading.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;

  const ChatScreen({
    super.key,
    this.sessionId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _maxMessageLength = 1000;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final SpeechToText _speechToText = SpeechToText();

  int? _sessionId;

  CBTSessionModel? _session;
  List<CBTMessageModel> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  bool _isFinishing = false;

  bool _speechInitialized = false;
  bool _speechAvailable = false;
  bool _isListening = false;

  String _speechBaseText = '';

  String? _errorMessage;
  int? _createdDiaryEntryId;
  bool _sessionFinishedInThisScreen = false;

  @override
  void initState() {
    super.initState();

    _sessionId = int.tryParse(
      widget.sessionId ?? '',
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }

    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    final id = _sessionId;

    if (id == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Не найден ID КПТ-сессии.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final session = await CbtService.getSession(id);
      final messages = await CbtService.getMessages(id);

      if (!mounted) return;

      setState(() {
        _session = session;
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Не удалось загрузить КПТ-сессию.';
      });
    }
  }

  Future<void> _reloadFromBackend() async {
    final id = _sessionId;

    if (id == null) return;

    final session = await CbtService.getSession(id);
    final messages = await CbtService.getMessages(id);

    if (!mounted) return;

    setState(() {
      _session = session;
      _messages = messages;
    });

    _scrollToBottom();
  }

  // ============================================================
  // SPEECH TO TEXT
  // ============================================================

  Future<bool> _ensureSpeechInitialized() async {
    if (_speechInitialized) {
      return _speechAvailable;
    }

    try {
      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _speechInitialized = true;
        _speechAvailable = available;
      });

      return available;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _speechInitialized = true;
        _speechAvailable = false;
        _isListening = false;
      });

      _showSnackBar(
        'Не удалось запустить распознавание речи.',
      );

      return false;
    }
  }

  Future<void> _toggleSpeechInput() async {
    if (_isSending || _isFinished) {
      return;
    }

    if (_speechToText.isListening || _isListening) {
      await _stopListening();
      return;
    }

    await _startListening();
  }

  Future<void> _startListening() async {
    final available = await _ensureSpeechInitialized();

    if (!available) {
      if (mounted) {
        _showSnackBar(
          'Распознавание речи недоступно. Проверьте разрешение на использование микрофона.',
        );
      }

      return;
    }

    _speechBaseText =
        _messageController.text.trimRight();

    try {
      setState(() {
        _isListening = true;
      });

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
          onDevice: false,
        ).copyWith(
          listenFor: const Duration(
            seconds: 60,
          ),
          pauseFor: const Duration(
            seconds: 3,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _isListening =
            _speechToText.isListening;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isListening = false;
      });

      _showSnackBar(
        'Не удалось начать голосовой ввод.',
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {
      // Ошибка остановки не должна ломать поле ввода.
    }

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) return;

    final recognizedText =
        result.recognizedWords.trim();

    final combinedText = _speechBaseText.isEmpty
        ? recognizedText
        : recognizedText.isEmpty
            ? _speechBaseText
            : '$_speechBaseText $recognizedText';

    final limitedText =
        combinedText.length > _maxMessageLength
            ? combinedText.substring(
                0,
                _maxMessageLength,
              )
            : combinedText;

    _messageController.value = TextEditingValue(
      text: limitedText,
      selection: TextSelection.collapsed(
        offset: limitedText.length,
      ),
    );

    if (result.finalResult) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    final normalizedStatus =
        status.trim().toLowerCase();

    final isActive =
        normalizedStatus == 'listening';

    final isFinished =
        normalizedStatus == 'done' ||
        normalizedStatus == 'notlistening';

    if (isActive) {
      setState(() {
        _isListening = true;
      });

      return;
    }

    if (isFinished) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechError(
    SpeechRecognitionError error,
  ) {
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });

    final errorMessage =
        error.errorMsg.toLowerCase();

    if (errorMessage.contains('permission') ||
        errorMessage.contains('denied')) {
      _showSnackBar(
        'Нет доступа к микрофону. Разрешите использование микрофона в настройках приложения.',
      );

      return;
    }

    if (errorMessage.contains('no_match') ||
        errorMessage.contains('speech_timeout')) {
      _showSnackBar(
        'Речь не распознана. Попробуйте сказать фразу ещё раз.',
      );

      return;
    }

    if (errorMessage.contains('network')) {
      _showSnackBar(
        'Не удалось распознать речь. Проверьте подключение к интернету.',
      );

      return;
    }

    _showSnackBar(
      'Не удалось распознать речь.',
    );
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    if (_isListening ||
        _speechToText.isListening) {
      await _stopListening();
    }

    final id = _sessionId;
    final content =
        _messageController.text.trim();

    if (id == null) {
      _showSnackBar(
        'Не найден ID сессии.',
      );

      return;
    }

    if (content.isEmpty) {
      _showSnackBar(
        'Введите сообщение.',
      );

      return;
    }

    if (content.length > _maxMessageLength) {
      _showSnackBar(
        'Сообщение слишком длинное. Максимум $_maxMessageLength символов.',
      );

      return;
    }

    if (_isFinished) {
      _showSnackBar(
        'Сессия уже завершена.',
      );

      return;
    }

    final optimisticUserMessage =
        CBTMessageModel(
      id: null,
      sessionId: id,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
      usedTechnique: null,
    );

    setState(() {
      _isSending = true;

      _messages = [
        ..._messages,
        optimisticUserMessage,
      ];
    });

    _messageController.clear();
    _speechBaseText = '';

    _scrollToBottom();

    try {
      final response =
          await CbtService.sendMessage(
        id,
        content,
      );

      final backendUserMessage =
          CbtService.parseMessageFromMap(
        response['user_message'],
      );

      final backendAssistantMessage =
          CbtService.parseMessageFromMap(
        response['assistant_message'],
      );

      final updatedSession =
          await CbtService.getSession(id);

      if (!mounted) return;

      setState(() {
        _session = updatedSession;

        final newMessages = [
          ..._messages,
        ];

        final optimisticIndex =
            newMessages.indexOf(
          optimisticUserMessage,
        );

        if (backendUserMessage != null &&
            optimisticIndex != -1) {
          newMessages[optimisticIndex] =
              backendUserMessage;
        }

        if (backendAssistantMessage != null) {
          final alreadyExists =
              newMessages.any(
            (message) =>
                message.id ==
                backendAssistantMessage.id,
          );

          if (!alreadyExists) {
            newMessages.add(
              backendAssistantMessage,
            );
          }
        }

        _messages = newMessages;
      });

      await _syncMessagesSafely();

      _scrollToBottom();
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where(
          (message) {
            return message !=
                optimisticUserMessage;
          },
        ).toList();
      });

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _messages = _messages.where(
          (message) {
            return message !=
                optimisticUserMessage;
          },
        ).toList();
      });

      _showSnackBar(
        'Не удалось отправить сообщение.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _syncMessagesSafely() async {
    final id = _sessionId;

    if (id == null) return;

    try {
      final messages =
          await CbtService.getMessages(id);

      if (!mounted) return;

      if (messages.isNotEmpty) {
        setState(() {
          _messages = messages;
        });
      }
    } catch (_) {
      // Не ломаем экран при ошибке фоновой синхронизации.
    }
  }

  // ============================================================
  // FINISH SESSION
  // ============================================================

  Future<void> _finishSession() async {
    if (_isListening ||
        _speechToText.isListening) {
      await _stopListening();
    }

    final id = _sessionId;

    if (id == null) {
      _showSnackBar(
        'Не найден ID сессии.',
      );

      return;
    }

    if (_isFinished) {
      _showSnackBar(
        'Сессия уже завершена.',
      );

      return;
    }

    setState(() {
      _isFinishing = true;
    });

    try {
      final response =
          await CbtService.finishSession(id);

      final diaryEntryId =
          CbtService.extractDiaryEntryId(
        response,
      );

      final updatedSession =
          await CbtService.getSession(id);

      final updatedMessages =
          await CbtService.getMessages(id);

      if (!mounted) return;

      setState(() {
        _session = updatedSession;
        _messages = updatedMessages;
        _createdDiaryEntryId =
            diaryEntryId;
        _sessionFinishedInThisScreen =
            true;
      });

      _showSnackBar(
        'Сессия завершена. Дневниковая запись создана.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) return;

      _showSnackBar(
        'Не удалось завершить сессию.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  bool get _isFinished {
    final session = _session;

    if (session == null) return false;

    return session.status == 'finished' ||
        session.currentStep == 'FINISHED' ||
        session.currentPhase == 'FINISHED';
  }

  void _openCreatedDiaryEntry() {
    final id = _createdDiaryEntryId;

    if (id == null) {
      _showSnackBar(
        'Не удалось определить ID дневниковой записи.',
      );

      return;
    }

    context.push('/diary/$id');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController
              .position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _phaseTitle(String? phase) {
    switch (phase) {
      case 'OPENING':
        return 'Начало сессии';
      case 'SITUATION_ANALYSIS':
        return 'Разбор ситуации';
      case 'THOUGHT_IDENTIFICATION':
        return 'Поиск автоматической мысли';
      case 'EMOTION_ASSESSMENT':
        return 'Оценка эмоций';
      case 'COGNITIVE_RESTRUCTURING':
        return 'Когнитивная реструктуризация';
      case 'ALTERNATIVE_FORMULATION':
        return 'Альтернативная мысль';
      case 'SUMMARY':
        return 'Итоги сессии';
      case 'FINISHED':
        return 'Сессия завершена';
      case 'STABILIZATION':
        return 'Стабилизация';
      case 'SMER_COLLECTION':
        return 'Ситуация, мысли, эмоции, реакции';
      case 'THOUGHT_EXPLORATION':
        return 'Исследование мысли';
      default:
        return 'КПТ-сессия';
    }
  }

  String _techniqueTitle(String technique) {
    switch (technique) {
      case 'SOCRATIC_DIALOGUE':
        return 'Сократический диалог';
      case 'DOWNWARD_ARROW':
        return 'Стрела вниз';
      case 'REFRAMING':
        return 'Рефрейминг';
      case 'SUMMARY':
        return 'Итоги';
      case 'NONE':
        return 'Без техники';
      default:
        return technique;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppLoading(
          text: 'Загрузка сессии...',
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'КПТ-сессия',
          ),
        ),
        body: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadInitialData,
        ),
      );
    }

    final session = _session;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'КПТ-сессия',
          ),
        ),
        body: AppErrorView(
          message: 'Нет данных сессии.',
          onRetry: _loadInitialData,
        ),
      );
    }

    return _ChatContent(
      session: session,
      messages: _messages,
      messageController:
          _messageController,
      scrollController:
          _scrollController,
      isSending: _isSending,
      isFinishing: _isFinishing,
      isFinished: _isFinished,
      isListening: _isListening,
      speechAvailable:
          _speechAvailable,
      createdDiaryEntryId:
          _createdDiaryEntryId,
      sessionFinishedInThisScreen:
          _sessionFinishedInThisScreen,
      maxMessageLength:
          _maxMessageLength,
      onSend: _sendMessage,
      onFinish: _finishSession,
      onToggleSpeech:
          _toggleSpeechInput,
      onOpenCreatedDiaryEntry:
          _openCreatedDiaryEntry,
      phaseTitle: _phaseTitle,
      techniqueTitle:
          _techniqueTitle,
    );
  }
}

class _ChatContent extends StatelessWidget {
  final CBTSessionModel session;
  final List<CBTMessageModel> messages;
  final TextEditingController messageController;
  final ScrollController scrollController;

  final bool isSending;
  final bool isFinishing;
  final bool isFinished;
  final bool isListening;
  final bool speechAvailable;

  final int? createdDiaryEntryId;
  final bool sessionFinishedInThisScreen;
  final int maxMessageLength;

  final VoidCallback onSend;
  final VoidCallback onFinish;
  final VoidCallback onToggleSpeech;
  final VoidCallback onOpenCreatedDiaryEntry;

  final String Function(String?) phaseTitle;
  final String Function(String) techniqueTitle;

  const _ChatContent({
    required this.session,
    required this.messages,
    required this.messageController,
    required this.scrollController,
    required this.isSending,
    required this.isFinishing,
    required this.isFinished,
    required this.isListening,
    required this.speechAvailable,
    required this.createdDiaryEntryId,
    required this.sessionFinishedInThisScreen,
    required this.maxMessageLength,
    required this.onSend,
    required this.onFinish,
    required this.onToggleSpeech,
    required this.onOpenCreatedDiaryEntry,
    required this.phaseTitle,
    required this.techniqueTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'КПТ-сессия',
        ),
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                isFinishing || isFinished
                    ? null
                    : onFinish,
            child: isFinishing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme
                          .colorScheme.primary,
                    ),
                  )
                : Text(
                    isFinished
                        ? 'Завершена'
                        : 'Завершить',
                    style: TextStyle(
                      color: isFinished
                          ? theme.colorScheme
                              .onSurfaceVariant
                          : theme.colorScheme
                              .primary,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth > 700;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isWide
                      ? 720
                      : double.infinity,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.sm,
                      ),
                      child: AppCard(
                        hasShadow: false,
                        padding:
                            const EdgeInsets.all(
                          AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                phaseTitle(
                                  session
                                      .currentPhase,
                                ),
                                style: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                            Text(
                              session.currentStep ??
                                  '',
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: theme
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isFinished &&
                        sessionFinishedInThisScreen)
                      Padding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.sm,
                          AppSpacing.xl,
                          AppSpacing.sm,
                        ),
                        child: AppCard(
                          hasShadow: false,
                          padding:
                              const EdgeInsets
                                  .all(
                            AppSpacing.lg,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Сессия завершена',
                                style: theme
                                    .textTheme
                                    .titleLarge,
                              ),
                              const SizedBox(
                                height:
                                    AppSpacing.sm,
                              ),
                              Text(
                                'Дневниковая запись создана. Новые сообщения в этой сессии больше нельзя отправлять.',
                                style: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              if (createdDiaryEntryId !=
                                  null) ...[
                                const SizedBox(
                                  height:
                                      AppSpacing
                                          .lg,
                                ),
                                AppButton(
                                  text:
                                      'Открыть запись',
                                  variant:
                                      AppButtonVariant
                                          .secondary,
                                  onPressed:
                                      onOpenCreatedDiaryEntry,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyChatState(
                              isSending:
                                  isSending,
                            )
                          : ListView.builder(
                              controller:
                                  scrollController,
                              padding:
                                  const EdgeInsets
                                      .fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.md,
                                AppSpacing.xl,
                                AppSpacing.lg,
                              ),
                              itemCount:
                                  messages.length +
                                      (isSending
                                          ? 1
                                          : 0),
                              itemBuilder:
                                  (context, index) {
                                if (isSending &&
                                    index ==
                                        messages
                                            .length) {
                                  return const _AssistantLoadingBubble();
                                }

                                final message =
                                    messages[index];

                                return _MessageBubble(
                                  message: message,
                                  techniqueTitle:
                                      techniqueTitle,
                                );
                              },
                            ),
                    ),
                    if (!isFinished)
                      _MessageInput(
                        controller:
                            messageController,
                        isSending: isSending,
                        isListening:
                            isListening,
                        speechAvailable:
                            speechAvailable,
                        maxLength:
                            maxMessageLength,
                        onSend: onSend,
                        onToggleSpeech:
                            onToggleSpeech,
                      )
                    else
                      Padding(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.sm,
                          AppSpacing.xl,
                          AppSpacing.lg,
                        ),
                        child: AppCard(
                          hasShadow: false,
                          padding:
                              const EdgeInsets
                                  .all(
                            AppSpacing.lg,
                          ),
                          child: Text(
                            'Сессия завершена. Сообщения больше нельзя отправлять.',
                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
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

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;

  final bool isSending;
  final bool isListening;
  final bool speechAvailable;

  final int maxLength;

  final VoidCallback onSend;
  final VoidCallback onToggleSpeech;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.isListening,
    required this.speechAvailable,
    required this.maxLength,
    required this.onSend,
    required this.onToggleSpeech,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final inputBackground = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final inputBorder = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorder
                : AppColors.lightDivider,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints:
                  const BoxConstraints(
                minHeight: 48,
                maxHeight: 132,
              ),
              decoration: BoxDecoration(
                color: inputBackground,
                borderRadius:
                    AppRadius.large,
                border: Border.all(
                  color: isListening
                      ? theme
                          .colorScheme.primary
                      : inputBorder,
                  width:
                      isListening ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !isSending,
                minLines: 1,
                maxLines: 5,
                maxLength: maxLength,
                keyboardType:
                    TextInputType.multiline,
                textInputAction:
                    TextInputAction.newline,
                style:
                    theme.textTheme.bodyMedium,
                cursorColor:
                    theme.colorScheme.primary,
                decoration: InputDecoration(
                  hintText: isListening
                      ? 'Говорите...'
                      : 'Напишите ответ...',
                  hintStyle: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    color: isListening
                        ? theme
                            .colorScheme.primary
                        : theme.colorScheme
                            .onSurfaceVariant,
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder:
                      InputBorder.none,
                  focusedBorder:
                      InputBorder.none,
                  disabledBorder:
                      InputBorder.none,
                  contentPadding:
                      const EdgeInsets
                          .symmetric(
                    horizontal:
                        AppSpacing.lg,
                    vertical: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: isListening
                  ? theme.colorScheme.primary
                  : inputBackground,
              borderRadius:
                  AppRadius.large,
              child: InkWell(
                onTap: isSending
                    ? null
                    : onToggleSpeech,
                borderRadius:
                    AppRadius.large,
                child: Tooltip(
                  message: isListening
                      ? 'Остановить голосовой ввод'
                      : 'Голосовой ввод',
                  child: Icon(
                    isListening
                        ? Icons
                            .stop_rounded
                        : Icons.mic_none_rounded,
                    color: isListening
                        ? theme
                            .colorScheme
                            .onPrimary
                        : theme
                            .colorScheme
                            .primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            width: AppSpacing.sm,
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              onPressed:
                  isSending ? null : onSend,
              style:
                  FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      AppRadius.large,
                ),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons
                          .arrow_upward_rounded,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final CBTMessageModel message;
  final String Function(String) techniqueTitle;

  const _MessageBubble({
    required this.message,
    required this.techniqueTitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isUser =
        message.role == 'user';

    final isAssistant =
        message.role == 'assistant';

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.cardTheme.color ??
            theme.colorScheme.surface;

    final textColor = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final technique =
        message.usedTechnique;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppSpacing.md,
        ),
        constraints:
            const BoxConstraints(
          maxWidth: 520,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      Radius.circular(
                    AppRadius.lg,
                  ),
                  topRight:
                      Radius.circular(
                    AppRadius.lg,
                  ),
                  bottomLeft:
                      Radius.circular(
                    isUser
                        ? AppRadius.lg
                        : AppRadius.sm,
                  ),
                  bottomRight:
                      Radius.circular(
                    isUser
                        ? AppRadius.sm
                        : AppRadius.lg,
                  ),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: theme
                            .dividerColor
                            .withOpacity(
                          0.6,
                        ),
                      ),
              ),
              child: Text(
                message.content ?? '',
                style: theme
                    .textTheme.bodyMedium
                    ?.copyWith(
                  color: textColor,
                ),
              ),
            ),
            if (isAssistant &&
                technique != null &&
                technique
                    .trim()
                    .isNotEmpty &&
                technique != 'NONE') ...[
              const SizedBox(
                height: AppSpacing.xs,
              ),
              Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      AppSpacing.sm,
                  vertical: 3,
                ),
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme.primary
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                      AppRadius.medium,
                ),
                child: Text(
                  techniqueTitle(
                    technique,
                  ),
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme
                        .primary,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssistantLoadingBubble
    extends StatelessWidget {
  const _AssistantLoadingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppSpacing.md,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ??
              theme.colorScheme.surface,
          borderRadius:
              BorderRadius.only(
            topLeft: Radius.circular(
              AppRadius.lg,
            ),
            topRight: Radius.circular(
              AppRadius.lg,
            ),
            bottomLeft:
                Radius.circular(
              AppRadius.sm,
            ),
            bottomRight:
                Radius.circular(
              AppRadius.lg,
            ),
          ),
          border: Border.all(
            color: theme.dividerColor
                .withOpacity(
              0.6,
            ),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
                color: theme
                    .colorScheme.primary,
              ),
            ),
            const SizedBox(
              width: AppSpacing.sm,
            ),
            Text(
              'Ассистент отвечает...',
              style: theme
                  .textTheme.bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatState
    extends StatelessWidget {
  final bool isSending;

  const _EmptyChatState({
    required this.isSending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(
        AppSpacing.xl,
      ),
      children: [
        AppCard(
          hasShadow: false,
          child: Text(
            'Пока сообщений нет. Напишите первое сообщение, чтобы начать КПТ-сессию.',
            style: theme
                .textTheme.bodyMedium
                ?.copyWith(
              color: theme.colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ),
        if (isSending) ...[
          const SizedBox(
            height: AppSpacing.lg,
          ),
          const _AssistantLoadingBubble(),
        ],
      ],
    );
  }
}