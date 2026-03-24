import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Controllers/PathController.dart';
import 'package:golden_shamela/UI/dialogs/duplicate_resolution_dialog.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/UI/dialogs/book_metadata_input_dialog.dart';
import 'package:golden_shamela/UI/dialogs/batch_metadata_input_dialog.dart';
import 'package:golden_shamela/Helpers/AuthorStorage.dart';
import 'package:golden_shamela/Helpers/SectionStorage.dart';
import 'package:path/path.dart' as p;

class BatchFileProcessingDialog extends StatefulWidget {
  final List<String> filePaths;
  final bool isResuming; // عند إعادة الفتح من الخلفية

  const BatchFileProcessingDialog({
    required this.filePaths,
    this.isResuming = false,
    super.key,
  });

  @override
  State<BatchFileProcessingDialog> createState() =>
      _BatchFileProcessingDialogState();
}

class _BatchFileProcessingDialogState extends State<BatchFileProcessingDialog> {
  // Track status for each file
  late List<BatchItemStatus> _items;
  int _currentIndex = 0;
  bool _isProcessing = false;
  bool _isCancelled = false;
  StreamSubscription<BookProcessingEvent>? _currentSubscription;
  final BookProcessingService _processingService = BookProcessingService();

  // Scroll controller to auto-scroll to active item
  final ScrollController _scrollController = ScrollController();

  // لمنع تعليق الانتظار عند الإلغاء
  final Map<String, Completer<void>> _itemCompleters = {};

  @override
  void initState() {
    super.initState();
    _items = widget.filePaths
        .map((path) => BatchItemStatus(filePath: path))
        .toList();

    // إذا كنا نستأنف من الخلفية، نعرض الحالة فقط
    if (widget.isResuming) {
      _syncWithActiveTasksIfResuming();
    } else {
      // فحص قبل البدء
      _validateAndStart();
    }
  }

  void _validateAndStart() async {
    // 1. كشف التكرار (نفس الملف مرتين في القائمة الحالية)
    final seen = <String>{};
    for (int i = 0; i < _items.length; i++) {
      if (seen.contains(_items[i].filePath)) {
        _items[i].status = ProcessingStatus.failed;
        _items[i].message = "ملف مكرر - تم تخطيه";
      }
      seen.add(_items[i].filePath);
    }

    // 2. فحص الكتب الموجودة مسبقاً في المكتبة
    final duplicatesIndices = <int>[];
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].status == ProcessingStatus.failed) continue;
      final fileName = p.basename(_items[i].filePath);
      final existingPath = '$BOOKS_FOLDER_PATH\\$fileName';
      bool exists = await File(existingPath).exists();
      // debugPrint("Checking duplicate: $existingPath (Exists: $exists)");

      if (exists) {
        duplicatesIndices.add(i);
      }
    }

    // 3. معالجة التكرارات (تفاعلياً)
    if (duplicatesIndices.isNotEmpty && mounted) {
      bool applyToAll = false;
      DuplicateAction? groupAction;

      for (int k = 0; k < duplicatesIndices.length; k++) {
        final index = duplicatesIndices[k];
        final item = _items[index];
        final fileName = p.basename(item.filePath);
        final existingPath = '$BOOKS_FOLDER_PATH\\$fileName';

        DuplicateAction action;

        if (applyToAll && groupAction != null) {
          action = groupAction;
        } else {
          // إظهار الديالوج للمستخدم
          final result = await showDialog<DuplicateResolutionResult>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => DuplicateResolutionDialog(
              fileName: fileName,
              remainingDuplicates: duplicatesIndices.length - k - 1,
            ),
          );

          if (result == null) {
            // إلغاء العملية بالكامل (زر الرجوع أو خارج الديالوج إذا كان مسموحاً)
            // هنا barrierDismissible: false لذا result لن يكون null إلا إذا قمنا بإعادته صراحة أو حدث خطأ
            if (mounted) Navigator.pop(context, false);
            return;
          }

          action = result.action;
          if (result.applyToAll) {
            applyToAll = true;
            groupAction = action;
          }
        }

        if (action == DuplicateAction.skip) {
          setState(() {
            item.status = ProcessingStatus.cancelled;
            item.message = "تم التخطي (موجود مسبقاً)";
            item.fullErrorMessage =
                "تم تخطي الملف لأن المستخدم اختار عدم استبدال الملف الموجود.";
          });
          // حفظ النتيجة في الخدمة لضمان استمراريتها عند إعادة فتح الديالوج
          _processingService.batchResults[item.filePath] =
              ProcessingState.cancelled;
        } else if (action == DuplicateAction.replace) {
          // حذف الملف القديم لضمان نظافة العملية
          try {
            final file = File(existingPath);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            debugPrint("فشل حذف الملف القديم: $e");
            // يمكننا الاستمرار، ربما عملية الكتابة اللاحقة ستنجح في الاستبدال
          }
        }
      }
    }

    // 4. فحص الحجم (للملفات الصالحة المتبقية)
    final largeFiles = <String>[];
    for (final item in _items) {
      if (item.status == ProcessingStatus.failed) continue;
      final file = File(item.filePath);
      if (await file.exists()) {
        final size = await file.length();
        if (size > 50 * 1024 * 1024) {
          // 50MB (رفعنا الحد قليلاً)
          final fileName = p.basename(item.filePath);
          largeFiles.add(
            '$fileName (${(size / 1024 / 1024).toStringAsFixed(1)}MB)',
          );
        }
      }
    }

    // عرض تحذير للملفات الكبيرة جداً فقط
    if (mounted && largeFiles.isNotEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Text("ملفات كبيرة الحجم"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("الملفات التالية كبيرة جداً وقد تستغرق وقتاً طويلاً:"),
              const SizedBox(height: 8),
              ...largeFiles
                  .take(5)
                  .map(
                    (f) => Text("• $f", style: const TextStyle(fontSize: 12)),
                  ),
              if (largeFiles.length > 5)
                Text("...و ${largeFiles.length - 5} آخرين"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("متابعة"),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        if (mounted) Navigator.pop(context, false);
        return;
      }
    }

    // 5. جمع البيانات الوصفية (Metadata)
    if (mounted) {
      if (_items
              .where(
                (i) =>
                    i.status != ProcessingStatus.failed &&
                    i.status != ProcessingStatus.cancelled,
              )
              .length ==
          1) {
        final item = _items.firstWhere(
          (i) =>
              i.status != ProcessingStatus.failed &&
              i.status != ProcessingStatus.cancelled,
        );

        final result = await showDialog<BookMetadataResult>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => BookMetadataInputDialog(filePath: item.filePath),
        );

        if (result == null) {
          if (mounted) Navigator.pop(context, false);
          return;
        }

        // Save new author/section if any
        if (result.newAuthor != null)
          await AuthorStorage().addAuthor(result.newAuthor!);
        if (result.newSection != null)
          await SectionStorage().addSection(result.newSection!);

        item.bookCard = result.bookCard;
      } else {
        // Batch metadata entry
        final validItems = _items
            .where(
              (i) =>
                  i.status != ProcessingStatus.failed &&
                  i.status != ProcessingStatus.cancelled,
            )
            .toList();

        if (validItems.isNotEmpty) {
          final validPaths = validItems.map((i) => i.filePath).toList();
          final result = await showDialog<Map<String, dynamic>>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => BatchMetadataInputDialog(filePaths: validPaths),
          );

          if (result == null) {
            if (mounted) Navigator.pop(context, false);
            return;
          }

          final Map<String, BookCard> bookCards = result['results'];
          final List<Author> newAuthors = result['newAuthors'];

          // Save new authors
          for (var author in newAuthors) {
            await AuthorStorage().addAuthor(author);
          }

          // Assign to items
          for (var item in _items) {
            if (bookCards.containsKey(item.filePath)) {
              item.bookCard = bookCards[item.filePath];
            }
          }
        }
      }
    }

    if (mounted) {
      // تحديث الحالة في الواجهة قبل البدء
      setState(() {});
      // حفظ قائمة الملفات لاستخدامها عند الاستئناف
      _processingService.startBatch(widget.filePaths);
      _startBatchProcessing();
    }
  }

  @override
  void dispose() {
    _currentSubscription?.cancel();
    _scrollController.dispose();
    if (widget.isResuming) {
      _processingService.activeTasksNotifier.removeListener(
        _onActiveTasksChanged,
      );
    }
    super.dispose();
  }

  // مزامنة الحالة مع المهام النشطة (عند الاستئناف من الخلفية)
  void _syncWithActiveTasksIfResuming() {
    final activeTasks = _processingService.activeTasksNotifier.value;

    for (var item in _items) {
      final activeTask = activeTasks.firstWhere(
        (t) => t.id == item.filePath,
        orElse: () => ActiveTask(id: '', title: ''),
      );

      if (activeTask.id.isNotEmpty) {
        item.message = activeTask.message;
        item.progress = activeTask.progress;

        if (activeTask.state == ProcessingState.completed) {
          item.status = ProcessingStatus.completed;
        } else if (activeTask.state == ProcessingState.failed) {
          item.status = ProcessingStatus.failed;
        } else {
          item.status = ProcessingStatus.processing;
        }
      } else {
        // فحص النتائج المكتملة المخزنة في الخدمة
        final result = _processingService.batchResults[item.filePath];
        if (result != null) {
          if (result == ProcessingState.completed) {
            item.status = ProcessingStatus.completed;
            item.message = "تمت الإضافة بنجاح";
            item.progress = 1.0;
          } else if (result == ProcessingState.failed) {
            item.status = ProcessingStatus.failed;
            item.message = "فشلت المعالجة";
            item.progress = 0.0;
          } else if (result == ProcessingState.cancelled) {
            item.status = ProcessingStatus.cancelled;
            item.message = "تم الإلغاء";
          }
        }
      }
    }

    _isProcessing = activeTasks.isNotEmpty;
    _processingService.activeTasksNotifier.addListener(_onActiveTasksChanged);

    if (mounted) setState(() {});
  }

  void _onActiveTasksChanged() {
    if (!mounted) return;

    final activeTasks = _processingService.activeTasksNotifier.value;

    setState(() {
      for (var item in _items) {
        final activeTask = activeTasks.firstWhere(
          (t) => t.id == item.filePath,
          orElse: () => ActiveTask(id: '', title: ''),
        );

        if (activeTask.id.isNotEmpty) {
          item.message = activeTask.message;
          item.progress = activeTask.progress;

          if (activeTask.state == ProcessingState.completed) {
            item.status = ProcessingStatus.completed;
          } else if (activeTask.state == ProcessingState.failed) {
            item.status = ProcessingStatus.failed;
          } else {
            item.status = ProcessingStatus.processing;
          }
        } else {
          // فحص النتائج المكتملة
          final result = _processingService.batchResults[item.filePath];
          if (result != null) {
            if (result == ProcessingState.completed) {
              item.status = ProcessingStatus.completed;
              item.message = "تمت الإضافة بنجاح";
              item.progress = 1.0;
            } else if (result == ProcessingState.failed) {
              item.status = ProcessingStatus.failed;
              item.message = "فشلت المعالجة";
              item.progress = 0.0;
            } else if (result == ProcessingState.cancelled) {
              item.status = ProcessingStatus.cancelled;
              item.message = "تم الإلغاء";
            }
          }
        }
      }

      _isProcessing = activeTasks.isNotEmpty;

      // إغلاق تلقائي إذا اكتمل كل شيء بنجاح أثناء فتح الديالوج
      if (!_isProcessing && widget.isResuming) {
        bool allSuccess = _items.every(
          (i) => i.status == ProcessingStatus.completed,
        );
        if (allSuccess) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    });
  }

  void _startBatchProcessing() async {
    // P0: منع تشغيل حلقات متعددة في نفس الوقت
    if (_isProcessing) return;

    // DispatchEx ينشئ instance معزول — لم يعد ضرورياً تحذير المستخدم
    const wordRunning = false;

    _isProcessing = true;
    _isCancelled = false; // P0: إصلاح فخ الإلغاء الدائم
    _itemCompleters.clear();

    // Pipeline: بدء جميع الكتب معاً (BookProcessingService يدير Word Lock)
    final futures = <Future<void>>[];
    final completers = <Completer<void>>[];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      // تخطي الملفات المكتملة أو الفاشلة أو الملغاة (مثل المكررة التي تم تخطيها)
      if (item.status == ProcessingStatus.completed ||
          item.status == ProcessingStatus.failed ||
          item.status == ProcessingStatus.cancelled)
        continue;

      setState(() {
        item.status = ProcessingStatus.processing;
        item.message = "في الانتظار...";
      });

      final completer = Completer<void>();
      completers.add(completer);
      _itemCompleters[item.filePath] = completer;

      // بدء المعالجة لهذا الكتاب (لا ننتظر - نتركه يعمل)
      _processingService
          .processBook(
            item.filePath,
            allowWordRunning: wordRunning,
            bookCard: item.bookCard,
          )
          .listen(
            (event) {
              if (!mounted) return;
              if (_isCancelled && event.state != ProcessingState.cancelled) {
                return;
              }

              if (mounted) {
                setState(() {
                  if (event.state == ProcessingState.failed) {
                    item.status = ProcessingStatus.failed;
                    item.message = event.message.split('\n').first;
                    item.fullErrorMessage = event.message;
                    item.progress = 0.0;
                  } else if (event.state == ProcessingState.completed) {
                    item.status = ProcessingStatus.completed;
                    item.message = "تمت الإضافة بنجاح";
                    item.progress = 1.0;
                  } else if (event.state == ProcessingState.cancelled) {
                    item.status = ProcessingStatus.cancelled;
                    item.message = "تم الإلغاء";
                    item.progress = 0.0;
                  } else {
                    item.status = ProcessingStatus.processing;
                    item.message = event.message;
                    item.progress = event.progress;
                  }
                });

                if (event.state == ProcessingState.failed ||
                    event.state == ProcessingState.completed ||
                    event.state == ProcessingState.cancelled) {
                  if (!completer.isCompleted) completer.complete();
                  _itemCompleters.remove(item.filePath);
                }
              }
            },
            onError: (e) {
              if (mounted) {
                setState(() {
                  item.status = ProcessingStatus.failed;
                  item.message = e.toString().split('\n').first;
                  item.fullErrorMessage = e.toString();
                });
              }
              if (!completer.isCompleted) completer.complete();
              _itemCompleters.remove(item.filePath);
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
              _itemCompleters.remove(item.filePath);
            },
          );

      futures.add(completer.future);
    }

    // انتظار اكتمال جميع الكتب
    await Future.wait(futures);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      bool allSuccess = _items.every(
        (i) => i.status == ProcessingStatus.completed,
      );
      if (allSuccess) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    }
  }

  void _retryItem(int index) {
    // P0: منع الإعادة أثناء المعالجة النشطة
    if (_isProcessing) return;

    setState(() {
      _items[index].status = ProcessingStatus.pending;
      _items[index].message = "في الانتظار...";
      _items[index].progress = 0.0;
    });
    _startBatchProcessing();
  }

  void _retryAllFailed() {
    // P0: منع الإعادة أثناء المعالجة النشطة
    if (_isProcessing) return;

    setState(() {
      for (var item in _items) {
        if (item.status == ProcessingStatus.failed) {
          item.status = ProcessingStatus.pending;
          item.message = "في الانتظار...";
          item.progress = 0.0;
        }
      }
    });
    _startBatchProcessing();
  }

  void _cancelBatch() {
    _isCancelled = true;
    // _currentSubscription?.cancel(); // لم يعد مستخدماً في التوازي

    // إلغاء جميع المهام النشطة
    for (var item in _items) {
      if (item.status != ProcessingStatus.completed &&
          item.status != ProcessingStatus.failed &&
          item.status != ProcessingStatus.cancelled) {
        _processingService.cancelTask(item.filePath);
        _processingService.batchResults[item.filePath] =
            ProcessingState.cancelled;
      }
    }

    // تحديث الواجهة وإلغاء أي انتظار متبقٍ
    setState(() {
      for (final item in _items) {
        if (item.status != ProcessingStatus.completed &&
            item.status != ProcessingStatus.failed &&
            item.status != ProcessingStatus.cancelled) {
          item.status = ProcessingStatus.cancelled;
          item.message = "تم الإلغاء";
          item.progress = 0.0;
        }
      }
      // فرض إعادة بناء اللائحة (لضمان تحديث العناصر بصرياً)
      _items = List.from(_items);
      _isProcessing = false;
    });

    for (final completer in _itemCompleters.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _itemCompleters.clear();

    // نبقي الديالوج مفتوحاً لعرض حالة الإلغاء، ولا نغلقه تلقائياً
  }

  void _showErrorDetails(BatchItemStatus item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text('تفاصيل الخطأ', style: bigStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  getFileName(item.filePath),
                  style: normalStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    item.fullErrorMessage.isNotEmpty
                        ? item.fullErrorMessage
                        : item.message,
                    style: normalStyle(fontSize: 12, color: Colors.grey[800]!),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: item.fullErrorMessage.isNotEmpty
                      ? item.fullErrorMessage
                      : item.message,
                ),
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم نسخ الخطأ')));
            },
            child: Text('نسخ', style: normalStyle(color: primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: Text('إغلاق', style: normalStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int completed = _items
        .where((i) => i.status == ProcessingStatus.completed)
        .length;
    int failed = _items
        .where((i) => i.status == ProcessingStatus.failed)
        .length;
    int cancelled = _items
        .where((i) => i.status == ProcessingStatus.cancelled)
        .length;
    int total = _items.length;

    // حساب النسبة الإجمالية كمتوسط تقدم لجميع العناصر الصالحة
    double globalProgress = 0.0;
    if (total > 0) {
      double totalProgressSum = 0.0;
      for (var item in _items) {
        if (item.status == ProcessingStatus.completed) {
          totalProgressSum += 1.0;
        } else if (item.status == ProcessingStatus.failed ||
            item.status == ProcessingStatus.cancelled) {
          // المهام الفاشلة أو الملغاة نعتبرها مساهمة بتقدمها الأخير أو 1.0 (لأنه تم إنتاجها)
          totalProgressSum += 1.0;
        } else {
          totalProgressSum += item.progress;
        }
      }
      globalProgress = totalProgressSum / total;
    }

    // Responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 600 ? 500.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height > 700
        ? 600.0
        : screenSize.height * 0.85;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          if (_isProcessing) {
            _cancelBatch();
          } else {
            bool anySuccess = _items.any(
              (i) => i.status == ProcessingStatus.completed,
            );
            Navigator.pop(context, anySuccess);
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.library_add_check_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إضافة كتب جديدة',
                                style: bigStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isProcessing
                                    ? (failed > 0
                                          ? 'اكتمل $completed | فشل $failed من أصل $total'
                                          : 'جاري معالجة $completed من أصل $total...')
                                    : cancelled == total && total > 0
                                    ? 'تم الإلغاء لكل العناصر'
                                    : failed > 0
                                    ? 'اكتمل $completed | فشل $failed من أصل $total'
                                    : 'اكتمل $completed من أصل $total',
                                style: normalStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 45,
                              height: 45,
                              child: CircularProgressIndicator(
                                value: globalProgress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                                strokeWidth: 3,
                              ),
                            ),
                            Text(
                              "${(globalProgress * 100).toInt()}%",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        tween: Tween<double>(begin: 0, end: globalProgress),
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // List with Scrollbar
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  controller: _scrollController,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _buildItemRow(
                        item,
                        index == _currentIndex && _isProcessing,
                        index,
                      );
                    },
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isProcessing) ...[
                      // زر العمل في الخلفية
                      TextButton.icon(
                        onPressed: () {
                          // إغلاق الديالوج مع الاحتفاظ بالمعالجة نشطة
                          Navigator.pop(
                            context,
                            null,
                          ); // null = continued in background
                        },
                        icon: const Icon(
                          Icons.minimize_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                        label: Text(
                          'في الخلفية',
                          style: normalStyle(color: Colors.grey[700]!),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _cancelBatch,
                        icon: const Icon(
                          Icons.cancel_outlined,
                          color: Colors.red,
                          size: 20,
                        ),
                        label: Text(
                          'إيقاف العملية',
                          style: normalStyle(color: Colors.red),
                        ),
                      ),
                    ] else ...[
                      if (failed > 0)
                        TextButton.icon(
                          onPressed: _retryAllFailed,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.orange,
                            size: 20,
                          ),
                          label: Text(
                            'إعادة المحاولة ($failed)',
                            style: normalStyle(color: Colors.orange),
                          ),
                        ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          bool anySuccess = _items.any(
                            (i) => i.status == ProcessingStatus.completed,
                          );
                          Navigator.pop(context, anySuccess);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'إتمام',
                          style: normalStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(BatchItemStatus item, bool isActive, int index) {
    IconData icon = Icons.timer_outlined;
    Color iconColor = Colors.grey;
    Color textColor = Colors.grey[600]!;

    if (item.status == ProcessingStatus.completed) {
      icon = Icons.check_circle_rounded;
      iconColor = Colors.green;
      textColor = Colors.green[700]!;
    } else if (item.status == ProcessingStatus.failed) {
      icon = Icons.error_rounded;
      iconColor = Colors.red;
      textColor = Colors.red[700]!;
    } else if (item.status == ProcessingStatus.cancelled) {
      icon = Icons.cancel_rounded;
      iconColor = Colors.orange;
      textColor = Colors.orange[700]!;
    } else if (item.status == ProcessingStatus.processing) {
      textColor = primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? primaryColor.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Leading Icon / Loader
          if (item.status == ProcessingStatus.processing)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: iconColor, size: 24),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getFileName(item.filePath),
                  style: normalStyle(
                    color: isActive ? Colors.black : Colors.black87,
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.message,
                  style: normalStyle(
                    color: textColor, // Dynamic text color
                    fontSize: 12,
                  ),
                ),
                if (item.status == ProcessingStatus.processing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(begin: 0, end: item.progress),
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value > 0 ? value : null,
                            backgroundColor: Colors.grey[200],
                            minHeight: 4,
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Retry & Error Details Actions
          if (!_isProcessing &&
              (item.status == ProcessingStatus.failed ||
                  item.status == ProcessingStatus.cancelled)) ...[
            if (item.status == ProcessingStatus.failed &&
                item.fullErrorMessage.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.grey),
                onPressed: () => _showErrorDetails(item),
                tooltip: "تفاصيل الخطأ",
              ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.orange),
              onPressed: () => _retryItem(index),
              tooltip: "إعادة المحاولة",
            ),
          ],
        ],
      ),
    );
  }
}

enum ProcessingStatus { pending, processing, completed, failed, cancelled }

class BatchItemStatus {
  final String filePath;
  ProcessingStatus status;
  String message;
  String fullErrorMessage; // الخطأ الكامل للعرض
  double progress;
  BookCard? bookCard;

  BatchItemStatus({
    required this.filePath,
    this.status = ProcessingStatus.pending,
    this.message = "في الانتظار...",
    this.fullErrorMessage = "",
    this.progress = 0.0,
    this.bookCard,
  });
}
