import 'dart:async';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

/// عرض ديالوج معالجة الملف
Future<ProcessingResult?> showBookProcessingDialog(
  BuildContext context,
  String filePath, {
  bool forceReprocess = false,
}) async {
  return await showDialog<ProcessingResult?>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
        ),
        child: BookProcessingDialog(filePath, forceReprocess: forceReprocess),
      );
    },
  );
}

/// للتوافق مع الكود القديم
showFileProcessDailog(
  BuildContext context,
  String filePath, {
  bool? update,
}) async {
  return await showBookProcessingDialog(
    context,
    filePath,
    forceReprocess: update ?? false,
  );
}

class BookProcessingDialog extends StatefulWidget {
  final String filePath;
  final bool forceReprocess;

  const BookProcessingDialog(
    this.filePath, {
    super.key,
    this.forceReprocess = false,
  });

  @override
  State<BookProcessingDialog> createState() => _BookProcessingDialogState();
}

class _BookProcessingDialogState extends State<BookProcessingDialog> {
  // Map service states to UI stages
  final Map<ProcessingState, ProcessingStage> _stateToStageMap = {
    ProcessingState.preparing: ProcessingStage.preparing,
    ProcessingState.rendering: ProcessingStage.processing,
    ProcessingState.fixingImages:
        ProcessingStage.processing, // Combine with processing
    ProcessingState.parsing: ProcessingStage.parsing,
    ProcessingState.caching: ProcessingStage.caching,
    ProcessingState.indexing: ProcessingStage.indexing,
    ProcessingState.completed: ProcessingStage.complete,
  };

  final Map<ProcessingStage, StageStatus> _stageStatuses = {
    ProcessingStage.preparing: StageStatus.pending,
    ProcessingStage.processing: StageStatus.pending,
    ProcessingStage.parsing: StageStatus.pending,
    ProcessingStage.caching: StageStatus.pending,
    ProcessingStage.indexing: StageStatus.pending,
  };

  ProcessingStage _currentStage = ProcessingStage.preparing;
  double _globalProgress = 0.0;
  String _currentMessage = "جاري التجهيز...";
  String? _errorMessage;
  String? _warningMessage;

  StreamSubscription<BookProcessingEvent>? _subscription;
  final BookProcessingService _processingService = BookProcessingService();

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startProcessing() {
    _startWithWordCheck();
  }

  Future<void> _startWithWordCheck() async {
    // DispatchEx ينشئ instance معزول — لم يعد ضرورياً تحذير المستخدم
    final wordRunning = false;

    _subscription = _processingService
        .processBook(widget.filePath, allowWordRunning: wordRunning)
        .listen(
          (event) {
            if (mounted) {
              _handleEvent(event);
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = error.toString();
                _setStageStatus(_currentStage, StageStatus.failed);
              });
            }
          },
          onDone: () {
            // Stream closed
          },
        );
  }

  void _handleEvent(BookProcessingEvent event) {
    if (event.state == ProcessingState.failed) {
      setState(() {
        _errorMessage = event.message;
        _setStageStatus(_currentStage, StageStatus.failed);
      });
      return;
    }

    if (event.state == ProcessingState.completed) {
      setState(() {
        _currentStage = ProcessingStage.complete;
        // Mark all as completed just in case
        _stageStatuses.forEach((key, value) {
          _stageStatuses[key] = StageStatus.completed;
        });
      });

      // Auto close after delay
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.of(context).pop(ProcessingResult(success: true));
        }
      });
      return;
    }

    final stage = _stateToStageMap[event.state];
    if (stage != null) {
      setState(() {
        // Mark previous stages as completed
        for (var s in _stageStatuses.keys) {
          if (s.index < stage.index) {
            _stageStatuses[s] = StageStatus.completed;
          }
        }

        _currentStage = stage;
        _setStageStatus(stage, StageStatus.active);
        _globalProgress = event.progress;
        _currentMessage = event.message;
      });
    }

    // Check for specific warnings
    if (event.message.contains("خطوط محمية")) {
      setState(() {
        _warningMessage = "المستند يحتوي على خطوط محمية.";
      });
    }
  }

  void _setStageStatus(ProcessingStage stage, StageStatus status) {
    _stageStatuses[stage] = status;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      decoration: AppChrome.surfaceDecoration(radius: AppChrome.radiusLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              LibraryIcon.fromIcon(Icons.library_books, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'إضافة كتاب جديد',
                  style: bigStyle().copyWith(color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            widget.filePath.split('\\').last.split('/').last,
            style: normalStyle().copyWith(color: accentColor.withOpacity(0.68)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          ..._buildStagesList(),

          const SizedBox(height: 16),
          _buildGlobalProgress(),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorWidget(),
          ],

          if (_warningMessage != null && _errorMessage == null) ...[
            const SizedBox(height: 16),
            _buildWarningWidget(),
          ],

          const SizedBox(height: 20),

          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_currentStage != ProcessingStage.complete &&
            _errorMessage == null) ...[
          // Continue in background
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ProcessingResult(success: false, continuedInBackground: true),
            ),
            child: Text(
              'في الخلفية',
              style: normalStyle(color: Colors.grey[600]!),
            ),
          ),
          const SizedBox(width: 8),
          // Cancel
          TextButton(
            onPressed: () {
              _processingService.cancelTask(widget.filePath);
              Navigator.of(
                context,
              ).pop(ProcessingResult(success: false, cancelled: true));
            },
            child: Text('إلغاء', style: normalStyle(color: Colors.red)),
          ),
        ],
        if (_errorMessage != null || _currentStage == ProcessingStage.complete)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(
                ProcessingResult(
                  success: _errorMessage == null,
                  error: _errorMessage,
                  warning: _warningMessage,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              _errorMessage != null ? 'إغلاق' : 'تم',
              style: normalStyle().copyWith(color: Colors.white),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildStagesList() {
    final stageNames = {
      ProcessingStage.preparing: 'تجهيز الملف',
      ProcessingStage.processing: 'معالجة الملف',
      ProcessingStage.parsing: 'تحليل المحتوى',
      ProcessingStage.caching: 'حفظ في الذاكرة',
      ProcessingStage.indexing: 'بناء الفهرس',
    };

    return _stageStatuses.entries.map((entry) {
      return _buildStageRow(
        stageNames[entry.key]!,
        entry.value,
        entry.key == _currentStage,
      );
    }).toList();
  }

  Widget _buildStageRow(String name, StageStatus status, bool isActive) {
    IconData icon;
    Color iconColor;

    switch (status) {
      case StageStatus.completed:
        icon = Icons.check_circle;
        iconColor = Colors.green;
        break;
      case StageStatus.active:
        icon = Icons.radio_button_checked;
        iconColor = primaryColor;
        break;
      case StageStatus.failed:
        icon = Icons.error;
        iconColor = Colors.red;
        break;
      case StageStatus.pending:
        icon = Icons.radio_button_unchecked;
        iconColor = Colors.grey[400]!;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          LibraryIcon.fromIcon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(
            name,
            style: normalStyle().copyWith(
              color: status == StageStatus.pending
                  ? accentColor.withOpacity(0.52)
                  : accentColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (status == StageStatus.completed)
            const LibraryIcon(LibraryIconType.check, color: Colors.green, size: 16),
          if (isActive)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlobalProgress() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _currentMessage,
                style: normalStyle(fontSize: 12, color: Colors.grey[700]!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(_globalProgress * 100).toInt()}%',
              style: bigStyle(fontSize: 14, color: primaryColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0, end: _globalProgress),
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: mutedColor,
                valueColor: AlwaysStoppedAnimation<Color>(actionColor),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const LibraryIcon(LibraryIconType.warning, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: normalStyle().copyWith(
                color: Colors.red[700],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _warningMessage!,
              style: normalStyle().copyWith(
                color: Colors.orange[800],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// UI definitions needed for logic above
enum ProcessingStage {
  preparing,
  processing,
  parsing,
  caching,
  indexing, // Add explicit indexing stage in UI
  complete,
}

enum StageStatus { pending, active, completed, failed }

class ProcessingResult {
  final bool success;
  final String? error;
  final String? warning;
  final bool cancelled;
  final bool continuedInBackground;

  ProcessingResult({
    required this.success,
    this.error,
    this.warning,
    this.cancelled = false,
    this.continuedInBackground = false,
  });
}
