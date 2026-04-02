import 'dart:async';
import 'dart:isolate';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

import 'package:golden_shamela/Helpers/ExeRunner.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Models/BookCard.dart';
import 'package:golden_shamela/Services/EmbeddedFontExtractor.dart';
import 'package:golden_shamela/FontsLoaderController.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:golden_shamela/Controllers/PathController.dart';
import 'package:golden_shamela/Utils/StatusTranslator.dart';

enum ProcessingState {
  preparing,
  waitingForWord, // Pipeline: في انتظار دور Word
  rendering, // pageRender.exe
  fixingImages, // fix_word_images.exe
  parsing,
  caching,
  indexing,
  completed,
  failed,
  cancelled,
}

class BookProcessingEvent {
  final ProcessingState state;
  final double progress;
  final String message;

  BookProcessingEvent(this.state, this.progress, this.message);
}

class ActiveTask {
  final String id; // usually filePath
  final String title;
  ProcessingState state;
  double progress;
  String message;
  bool isCancelled;
  Process? activeProcess; // للإلغاء الفعلي

  ActiveTask({
    required this.id,
    required this.title,
    this.state = ProcessingState.preparing,
    this.progress = 0.0,
    this.message = "",
    this.isCancelled = false,
    this.activeProcess,
  });
}

class _WordQueueItem {
  final ActiveTask task;
  final Completer<void> completer;

  _WordQueueItem({required this.task}) : completer = Completer<void>();
}

/// إصدار الكاش — يُزاد عند تغيير بنية التحليل أو الفهرس
const int CACHE_VERSION = 4;

/// خدمة مركزية لإدارة معالجة الكتب (تخطيط، تحليل، كاش، فهرسة)
class BookProcessingService {
  // Singleton
  static final BookProcessingService _instance =
      BookProcessingService._internal();
  factory BookProcessingService() => _instance;
  BookProcessingService._internal();

  // Pipeline: تقييد Word لـ 1 فقط في نفس الوقت
  final _wordLock = Completer<void>(); // Word Lock Mechanism
  bool _isWordProcessing = false;
  final Queue<_WordQueueItem> _wordQueue = Queue();

  // Indexing Lock Mechanism (to prevent DB contention)
  bool _isIndexing = false;
  final Queue<Completer<void>> _indexingQueue = Queue();

  // State management for UI (Background Task Bar)
  final ValueNotifier<List<ActiveTask>> activeTasksNotifier = ValueNotifier([]);

  // قائمة ملفات الدفعة الحالية (تبقى حتى بعد الاكتمال)
  List<String> currentBatchFiles = [];

  // نتائج الدفعة الحالية (id -> state) لضمان بقاء الحالة حتى بعد اكتمال المهمة
  final Map<String, ProcessingState> batchResults = {};

  // بدء دفعة جديدة
  void startBatch(List<String> files) {
    currentBatchFiles = List.from(files);
    batchResults.clear(); // مسح النتائج السابقة
  }

  // إنهاء الدفعة
  void clearBatch() {
    currentBatchFiles.clear();
    batchResults.clear();
  }

  /// المعالجة الكاملة للكتاب (Event Stream)
  Stream<BookProcessingEvent> processBook(
    String sourceFilePath, {
    bool allowWordRunning = false,
    BookCard? bookCard,
  }) {
    final fileName = p.basename(sourceFilePath);
    final task = ActiveTask(id: sourceFilePath, title: fileName);

    // broadcast allows multiple listeners (Dialog + Background Bar)
    final controller = StreamController<BookProcessingEvent>.broadcast();

    // Use microtask to avoid updating state immediately during a build phase
    Future.microtask(() {
      _addTask(task);
      _executeProcess(
        controller,
        sourceFilePath,
        task,
        allowWordRunning: allowWordRunning,
        bookCard: bookCard,
      ).then((_) {
        // Ensure controller is closed if not already
        if (!controller.isClosed) {
          controller.close();
        }
        _removeTask(task);
      });
    });

    return controller.stream;
  }

  void _addTask(ActiveTask task) {
    final current = List<ActiveTask>.from(activeTasksNotifier.value);
    current.add(task);
    activeTasksNotifier.value = current;
    _activeTasks[task.id] = task;
    debugPrint("Task Added: ${task.title}. Total: ${current.length}");
  }

  void _removeTask(ActiveTask task) {
    final current = List<ActiveTask>.from(activeTasksNotifier.value);
    current.removeWhere((t) => t.id == task.id);
    activeTasksNotifier.value = current;
    _activeTasks.remove(task.id);
    debugPrint("Task Removed: ${task.title}. Remaining: ${current.length}");
  }

  // Track active tasks by ID for cancellation
  final Map<String, ActiveTask> _activeTasks = {};

  /// إلغاء مهمة بناءً على مسار الملف (مع قتل العملية الفعلية)
  void cancelTask(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null) {
      task.isCancelled = true;
      // حفظ النتيجة كملغاة
      batchResults[taskId] = ProcessingState.cancelled;
      // قتل العملية الفعلية إذا كانت تعمل
      if (task.activeProcess != null) {
        ExeRunner.killProcess(task.activeProcess);
        task.activeProcess = null;
      }

      // إذا كانت المهمة تنتظر قفل Word، أخرجها من الطابور فوراً
      if (_wordQueue.isNotEmpty) {
        final remaining = <_WordQueueItem>[];
        for (final item in _wordQueue) {
          if (item.task.id == taskId) {
            if (!item.completer.isCompleted) {
              item.completer.complete();
            }
          } else {
            remaining.add(item);
          }
        }
        _wordQueue
          ..clear()
          ..addAll(remaining);
      }

      // في حال كان القفل محرراً ولكن أول عنصر ملغي، حرّك الطابور
      _releaseWordLock();
      debugPrint("Task Cancelled + Process Killed: ${task.title}");
    }
  }

  void _updateTask(
    ActiveTask task,
    ProcessingState state,
    double progress,
    String message,
  ) {
    task.state = state;
    task.progress = progress;
    task.message = message;
    // Trigger notify
    activeTasksNotifier.value = List.from(activeTasksNotifier.value);
  }

  // Pipeline: انتظار دور Word (قابل للإلغاء)
  Future<bool> _acquireWordLock(ActiveTask task) async {
    if (!_isWordProcessing) {
      _isWordProcessing = true;
      return true;
    }
    // انتظار في الطابور
    final item = _WordQueueItem(task: task);
    _wordQueue.add(item);
    await item.completer.future;

    if (task.isCancelled) {
      return false;
    }
    // عند هنا، نكون قد حصلنا على القفل (لأن releaseWordLock يكملنا ولا يحرر المتغير)
    // لكن المتغير يبقى true لأن هناك عملية نشطة (نحن)
    return true;
  }

  // Pipeline: تحرير Word للتالي في الطابور
  void _releaseWordLock() {
    while (_wordQueue.isNotEmpty) {
      final next = _wordQueue.removeFirst();
      if (next.task.isCancelled) {
        if (!next.completer.isCompleted) next.completer.complete();
        continue;
      }
      if (!next.completer.isCompleted) next.completer.complete();
      return;
    }
    _isWordProcessing = false;
  }

  // Pipeline: انتظار دور Indexing
  Future<void> _acquireIndexingLock() async {
    if (!_isIndexing) {
      _isIndexing = true;
      return;
    }
    final completer = Completer<void>();
    _indexingQueue.add(completer);
    await completer.future;
  }

  // Pipeline: تحرير Indexing
  void _releaseIndexingLock() {
    if (_indexingQueue.isNotEmpty) {
      final next = _indexingQueue.removeFirst();
      next.complete();
    } else {
      _isIndexing = false;
    }
  }

  Future<void> _executeProcess(
    StreamController<BookProcessingEvent> controller,
    String sourceFilePath,
    ActiveTask task, {
    bool allowWordRunning = false,
    BookCard? bookCard,
  }) async {
    String tempFilePath = '';

    void emit(ProcessingState state, double progress, String message) {
      if (controller.isClosed) return;
      controller.add(BookProcessingEvent(state, progress, message));
      _updateTask(task, state, progress, message);

      // حفظ النتيجة إذا كانت نهائية لضمان المزامنة عند إعادة فتح الديالوج
      if (state == ProcessingState.completed ||
          state == ProcessingState.failed ||
          state == ProcessingState.cancelled) {
        batchResults[task.id] = state;
      }
    }

    // Helper to check cancellation
    bool checkCancelled() {
      if (task.isCancelled) {
        emit(ProcessingState.cancelled, 0.0, "تم إلغاء العملية");
        if (tempFilePath.isNotEmpty) {
          try {
            final f = File(tempFilePath);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
        return true;
      }
      return false;
    }

    emit(ProcessingState.preparing, 0.02, "تجهيز الملف...");

    if (!sourceFilePath.toLowerCase().endsWith('.docx')) {
      emit(ProcessingState.failed, 0.0, "الملف يجب أن يكون بصيغة docx");
      return;
    }

    if (p.basename(sourceFilePath).startsWith('~\$')) {
      emit(ProcessingState.failed, 0.0, "لا يمكن معالجة الملفات المؤقتة");
      return;
    }

    // DispatchEx ينشئ instance معزول — لم يعد ضرورياً إغلاق Word
    // if (!allowWordRunning && await _isWordRunning()) {
    //   emit(
    //     ProcessingState.failed,
    //     0.0,
    //     "يوجد ملف وورد مفتوح حالياً. يرجى حفظ عملك وإغلاقه قبل المتابعة.",
    //   );
    //   return;
    // }

    if (checkCancelled()) return;

    // 1. مرحلة Word (مقيدة بـ 1 في نفس الوقت)
    emit(ProcessingState.waitingForWord, 0.05, "في انتظار دور Word...");
    final acquired = await _acquireWordLock(task);
    if (!acquired) {
      // تم الإلغاء أثناء الانتظار
      checkCancelled();
      return;
    }

    if (checkCancelled()) {
      _releaseWordLock();
      return;
    }

    emit(ProcessingState.rendering, 0.1, "تحديث تخطيط الصفحات (Word)...");

    String fileName = p.basename(sourceFilePath);
    String fileNameNoExt = p.basenameWithoutExtension(sourceFilePath);
    tempFilePath = p.join(PROCESSING_TEMP_PATH, "_temp_$fileNameNoExt.docx");
    String finalBookPath = p.join(BOOKS_FOLDER_PATH, fileName);

    try {
      // تنظيف أي ملف مؤقت متبقٍ قبل البدء لتجنب PathExistsException
      await _deleteIfExists(tempFilePath);

      String? wordError; // لالتقاط رسالة الخطأ من سكريبت Python
      try {
        // المرحلة 1: Word Repaginate فقط
        await ExeRunner().runExe(
          PROCESSING_TEMP_PATH,
          sourceFilePath,
          (output) {
            if (task.isCancelled) return;

            final lines = output.split(RegExp(r'\r?\n'));
            for (var line in lines) {
              line = line.trim();
              if (line.isEmpty) continue;

              if (line.startsWith('STATUS:')) {
                String status = line.replaceFirst('STATUS:', '').trim();
                String translated = StatusTranslator.translate(status);

                double subProgress = 0.0;
                if (status.contains('pages')) {
                  final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(status);
                  if (match != null) {
                    int current = int.parse(match.group(1)!);
                    int total = int.parse(match.group(2)!);
                    if (total > 0) subProgress = current / total;
                  }
                }

                emit(
                  ProcessingState.rendering,
                  0.1 + (subProgress * 0.3),
                  translated,
                );
              } else if (line.startsWith('ERROR:')) {
                wordError = StatusTranslator.translate(
                  line.replaceFirst('ERROR:', '').trim(),
                );
                debugPrint("WORD ERROR: $wordError");
              } else {
                debugPrint("WORD OUTPUT: $line");
              }
            }
          },
          onProcessStarted: (process) {
            task.activeProcess = process;
          },
          stage: 'word', // Pipeline: Word فقط
        );
      } catch (e) {
        _releaseWordLock();
        emit(ProcessingState.failed, 0.0, "خطأ في Word: $e");
        return;
      }

      // تحرير Word للكتاب التالي في الطابور
      _releaseWordLock();
      debugPrint("📗 Word released for: $fileName");

      if (checkCancelled()) return;

      // التحقق من وجود الملف المؤقت
      if (!File(tempFilePath).existsSync()) {
        final errorMsg = wordError ?? "فشل في إنشاء ملف Word المؤقت";
        emit(ProcessingState.failed, 0.0, errorMsg);
        return;
      }

      // 2. مرحلة XML (متوازية - دون قيود)
      emit(ProcessingState.rendering, 0.4, "معالجة XML...");

      try {
        await ExeRunner().runExe(
          BOOKS_FOLDER_PATH, // الناتج يجب أن يذهب لمجلد الكتب النهائي
          tempFilePath, // المدخل هو الملف المؤقت من مرحلة الوورد
          (output) {
            if (task.isCancelled) return;
            if (output.startsWith('PROGRESS:')) {
              final pct =
                  int.tryParse(output.replaceFirst('PROGRESS:', '')) ?? 0;
              if (pct > 0 && pct < 100) {
                emit(
                  ProcessingState.rendering,
                  0.4 + (pct / 100) * 0.3,
                  "معالجة XML... ($pct%)",
                );
              }
            } else {
              debugPrint("XML OUTPUT: $output");
            }
          },
          onProcessStarted: (process) {
            task.activeProcess = process;
          },
          stage: 'xml', // Pipeline: XML فقط
        );
      } catch (e) {
        emit(ProcessingState.failed, 0.0, "خطأ في XML: $e");
        return;
      }

      // 3. إصلاح الصور + تحليل (على الملف المؤقت)
      emit(ProcessingState.fixingImages, 0.7, "فحص الصور...");

      // Copy finalBookPath back to tempFilePath to ensure we have the XML markers
      // This allows us to fix images and parse without modifying the persistent library file
      try {
        await _deleteIfExists(tempFilePath);
        await _copyWithRetry(finalBookPath, tempFilePath);
      } catch (e) {
        debugPrint("Failed to copy final book to temp: $e");
        emit(ProcessingState.failed, 0.0, "فشل في إعداد الملف المؤقت: $e");
        return;
      }

      // تشغيل الإصلاح على الملف المؤقت
      await _runImageFixer(tempFilePath);
      emit(ProcessingState.fixingImages, 0.75, "تم فحص الصور");

      if (checkCancelled()) {
        try {
          if (File(tempFilePath).existsSync())
            await File(tempFilePath).delete();
        } catch (_) {}
        return;
      }

      // 4. تحليل وكاش (من الملف المؤقت)
      emit(ProcessingState.parsing, 0.75, "تحليل المحتوى...");

      try {
        // نمرر دالة emit بدلاً من Controller لتحديث task أيضاً
        // ونستخدم الملف المؤقت كمصدر، لكن العنوان الأصلي للكاش
        await _parseAndCacheBookInternal(
          tempFilePath,
          (s, p, m) => emit(s, p, m),
          isCancelled: () => task.isCancelled,
          titleOverride:
              fileNameNoExt, // مهم: الحفظ باسم الملف الأصلي (بدون لاحقة)
        );

        // الآن يمكننا حذف الملف المؤقت
        try {
          await _deleteIfExists(tempFilePath);
        } catch (_) {}

        if (checkCancelled()) {
          // Clean up cache on cancel
          final bookCacheDir = Directory(
            '${p.dirname(finalBookPath)}/tome_ocean/${p.basenameWithoutExtension(finalBookPath)}',
          );
          if (await bookCacheDir.exists()) {
            await bookCacheDir.delete(recursive: true);
          }
          return;
        }

        emit(ProcessingState.caching, 0.95, "تم الحفظ في الذاكرة");
      } catch (e) {
        debugPrint("Error parsing book: $e");
        // محاولة تنظيف المؤقت عند الخطأ
        try {
          await _deleteIfExists(tempFilePath);
        } catch (_) {}

        emit(ProcessingState.failed, 0.0, "فشل التحليل: $e");
        return;
      }

      if (checkCancelled()) return;

      // 4. الفهرسة (متوازية منطقياً - متسلسلة في الحفظ فقط)
      emit(ProcessingState.indexing, 0.95, "جاري تجهيز صفحات الفهرس...");

      // تحميل الصفحات من الكاش
      // المسار يجب أن يطابق مسار الحفظ في _parseAndCacheBookInternal
      // الذي يستخدم getApplicationDocumentsDirectory() وليس مجلد الكتب
      List<WordPage> pages = [];
      try {
        final appDocsDir = await getApplicationDocumentsDirectory();
        final bookCacheDir = Directory(
          '${appDocsDir.path}/tome_ocean/$fileNameNoExt',
        );
        final pagesDir = Directory('${bookCacheDir.path}/pages');
        if (await pagesDir.exists()) {
          final pageFiles = await pagesDir.list().toList();
          pageFiles.sort((a, b) {
            final aName = p.basename(a.path).split('.').first;
            final bName = p.basename(b.path).split('.').first;
            return (int.tryParse(aName) ?? 0).compareTo(
              int.tryParse(bName) ?? 0,
            );
          });

          WordDocument dummyDoc = WordDocument();
          for (var file in pageFiles) {
            if (file.path.endsWith('.gz')) {
              final compressedBytes = await File(file.path).readAsBytes();
              final decodedBytes = GZipCodec().decode(compressedBytes);
              final pageJsonString = utf8.decode(decodedBytes);
              final pageJsonMap =
                  jsonDecode(pageJsonString) as Map<String, dynamic>;
              pages.add(WordPage.fromMap(pageJsonMap, dummyDoc));
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading pages for indexer: $e");
      }

      emit(ProcessingState.indexing, 0.95, "جاري بناء الفهرس...");

      // No Global Lock Here - Passed to Engine instead

      try {
        final indexer = ShamelaSearchIndexer();
        final indexResult = await indexer.indexBookFromPages(
          finalBookPath,
          pages,
          onProgress: (progress, message) {
            if (!task.isCancelled) {
              // التوزيع من 95% إلى 100%
              double globalProgress = 0.95 + (progress * 0.05);
              emit(ProcessingState.indexing, globalProgress, message);
            }
          },
          shouldStop: () => task.isCancelled,
          acquireLock: _acquireIndexingLock, // Pass callback
          releaseLock: _releaseIndexingLock, // Pass callback
        );

        if (checkCancelled()) return;

        if (indexResult) {
          emit(ProcessingState.indexing, 1.0, "تمت الفهرسة");
        } else {
          emit(ProcessingState.indexing, 1.0, "تخطي الفهرسة (خطأ أو فارغ)");
        }
      } catch (e) {
        if (!task.isCancelled) {
          emit(ProcessingState.failed, 0.0, "خطأ في الفهرسة: $e");
          return;
        }
      }

      if (checkCancelled()) return;

      // 5. حفظ البيانات الوصفية (Metadata)
      if (bookCard != null) {
        emit(ProcessingState.completed, 0.95, "حفظ بيانات الكتاب...");
        try {
          final db = BooksMetadataDatabase();
          await db.saveBook(bookCard, finalBookPath);
          debugPrint("Book Metadata Saved: ${bookCard.title}");
        } catch (e) {
          debugPrint("Error saving book metadata: $e");
          // لا نعتبره فشلاً للمهمة بالكامل، لكن نسجله
        }
      }

      emit(ProcessingState.completed, 1.0, "اكتملت العملية");

      // تسجيل النتيجة النهائية
      batchResults[task.id] = ProcessingState.completed;
    } finally {
      // ضمان حذف الملف المؤقت في كل الحالات (نجاح، فشل، إلغاء)
      try {
        await _deleteIfExists(tempFilePath);
      } catch (e) {
        debugPrint("Failed to delete temp file in finally: $e");
      }
    }
  }

  /// معالجة سريعة لفتح الكتاب (بدون تتبع كـ Task في البار)
  Future<void> parseAndCacheForOpening(
    String filePath, {
    Function(ProcessingState, double, String)? emit,
  }) async {
    // 1. إصلاح الصور
    await _runImageFixer(filePath);

    // 2. تحليل وكاش
    await _parseAndCacheBookInternal(filePath, emit);
  }

  /// تشغيل أداة إصلاح الصور
  Future<void> _runImageFixer(String filePath) async {
    try {
      String exeName = "fix_word_images.exe";
      
      // 1. Check inside assets (Release mode)
      String exePath =
          "${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\exe\\$exeName";

      // 2. Fallback: Use ApplicationSupportDirectory to avoid Temp/AV access denied issues
      if (!await File(exePath).exists()) {
        final supportDir = await getApplicationSupportDirectory();
        final supportExePath = '${supportDir.path}\\$exeName';
        
        try {
          final byteData = await rootBundle.load('assets/exe/$exeName');
          final newFileSize = byteData.lengthInBytes;
          
          // Check if existing file needs update (compare size as version check)
          bool needsUpdate = true;
          if (await File(supportExePath).exists()) {
            try {
              final existingSize = await File(supportExePath).length();
              if (existingSize == newFileSize) {
                needsUpdate = false;
              } else {
                // Delete old version to replace it
                await File(supportExePath).delete();
              }
            } catch (e) {
              debugPrint("Could not check existing fix_word_images.exe size: $e");
            }
          }
          
          if (needsUpdate) {
            await File(supportExePath).writeAsBytes(byteData.buffer.asUint8List());
            debugPrint("✓ fix_word_images.exe extracted/updated to: $supportExePath");
          }
        } catch (e) {
          debugPrint("Failed to extract fix_word_images.exe to support dir: $e");
        }
        
        if (await File(supportExePath).exists()) {
          exePath = supportExePath;
        }
      }

      if (await File(exePath).exists()) {
        try {
          await Process.run(exePath, [filePath]);
        } catch (e) {
          debugPrint("❌ Error launching process: $e");
        }
      } else {
        debugPrint(
          "⚠️ Image Fixer EXE not found in any expected location. Checked: $exePath (and others)",
        );
      }
    } catch (e) {
      debugPrint("❌ Could not run Image Fixer: $e");
    }
  }

  /// المنطق الداخلي للتحليل والكاش
  Future<void> _parseAndCacheBookInternal(
    String filePath,
    Function(ProcessingState, double, String)? emit, {
    bool Function()? isCancelled,
    String? titleOverride, // Optional override for cache key
  }) async {
    final title = titleOverride ?? getFileName(filePath);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final tomeOceanDir = Directory('${appDocsDir.path}/tome_ocean');
    final bookCacheDir = Directory('${tomeOceanDir.path}/$title');
    final sharedFontsDirPath = '${tomeOceanDir.path}/_shared_fonts';

    // التحقق من الإلغاء
    if (isCancelled != null && isCancelled()) return;

    final receivePort = ReceivePort();

    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        ProcessingState state = message['state'];
        double progress = message['progress'];
        String msg = message['message'];
        emit?.call(state, progress, msg);
      }
    });

    final String isolateFilePath = filePath;
    final String isolateTitle = title;
    final String isolateBookCacheDirPath = bookCacheDir.path;
    final String isolateSharedFontsDirPath = sharedFontsDirPath;
    final SendPort isolateSendPort = receivePort.sendPort;

    Map<String, dynamic> isolateResult = {};
    try {
      final args = {
        'filePath': isolateFilePath,
        'title': isolateTitle,
        'bookCacheDirPath': isolateBookCacheDirPath,
        'sharedFontsDirPath': isolateSharedFontsDirPath,
        'sendPort': isolateSendPort,
      };

      isolateResult = await _startParseIsolate(args);
    } catch (e) {
      debugPrint("Isolate error: $e");
      rethrow;
    } finally {
      receivePort.close();
    }

    // التحقق مجدداً من الإلغاء
    if (isCancelled != null && isCancelled()) return;

    // تحميل الخطوط المستخرجة على الـ Main Thread
    if (isolateResult['success'] == true) {
      final extractedFontPaths =
          isolateResult['extractedFontPaths'] as Map<String, dynamic>?;
      final fontsList = (isolateResult['fontsList'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      if (extractedFontPaths != null && extractedFontPaths.isNotEmpty) {
        final Map<String, String> fontsStrMap = extractedFontPaths.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        await loadExtractedFonts(fontsStrMap);
      }
      await loadKnownSystemFontsForDocument(fontsList);
    }
  }

  /// Helper static function to ensure the Isolate.run closure ONLY captures `args`.
  static Future<Map<String, dynamic>> _startParseIsolate(
    Map<String, dynamic> args,
  ) async {
    return await Isolate.run(() => _isolateParseAndCacheHandler(args));
  }

  static Future<Map<String, dynamic>> _isolateParseAndCacheHandler(
    Map<String, dynamic> args,
  ) async {
    final String filePath = args['filePath'];
    final String title = args['title'];
    final String bookCacheDirPath = args['bookCacheDirPath'];
    final String sharedFontsDirPath = args['sharedFontsDirPath'];
    final SendPort sendPort = args['sendPort'];

    void emitProgress(ProcessingState state, double progress, String message) {
      sendPort.send({'state': state, 'progress': progress, 'message': message});
    }

    WordDocument wordDocument = WordDocument();
    wordDocument.title = title;

    final bookCacheDir = Directory(bookCacheDirPath);
    final metadataFile = File('${bookCacheDir.path}/metadata.json');
    final pagesDir = Directory('${bookCacheDir.path}/pages');

    emitProgress(ProcessingState.parsing, 0.76, "جاري فك ضغط الكتاب...");
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    wordDocument.archive = archive;

    emitProgress(
      ProcessingState.parsing,
      0.78,
      "جاري استخراج الخطوط المدمجة...",
    );
    Map<String, String> extractedFontPaths =
        await EmbeddedFontExtractor.extractEmbeddedFonts(
          archive,
          bookCacheDir.path,
          sharedFontsDirPath,
        );
    wordDocument.extractedFontPaths = extractedFontPaths;

    emitProgress(ProcessingState.parsing, 0.80, "قراءة هيكل المستند...");
    List<WordPage> parsedPages = await AddDocData(
      archive,
      wordDocument,
      onProgress: (current, total) {
        if (total > 0) {
          double progress = 0.80 + (0.10 * current / total);
          emitProgress(
            ProcessingState.parsing,
            progress,
            "تحليل: $current/$total",
          );
        }
      },
    );
    wordDocument.setLoadedPages(parsedPages);

    emitProgress(ProcessingState.parsing, 0.90, "تم التحليل");
    emitProgress(ProcessingState.caching, 0.90, "جاري الحفظ...");

    await bookCacheDir.create(recursive: true);
    await pagesDir.create(recursive: true);

    final metadataJsonMap = wordDocument.toMetadataJson();
    metadataJsonMap['_cacheVersion'] = CACHE_VERSION;
    await metadataFile.writeAsString(jsonEncode(metadataJsonMap));

    // حفظ الصفحات
    for (int i = 0; i < parsedPages.length; i++) {
      final jsonFile = File('${pagesDir.path}/$i.json');
      final pagesJson = jsonEncode(parsedPages[i].toJson());
      final gzipBytes = GZipCodec().encode(utf8.encode(pagesJson));
      final jsonGzFile = File('${jsonFile.path}.gz');
      await jsonGzFile.writeAsBytes(gzipBytes);

      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      if (i % 10 == 0) {
        double progress = 0.90 + (0.04 * i / parsedPages.length);
        emitProgress(ProcessingState.caching, progress, "حفظ صفحة $i...");
      }
    }

    wordDocument.archive = null;

    return {
      'success': true,
      'extractedFontPaths': extractedFontPaths,
      'fontsList': wordDocument.fontsList,
    };
  }

  Future<void> _deleteIfExists(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _copyWithRetry(
    String source,
    String destination, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        await File(source).copy(destination);
        return;
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(const Duration(milliseconds: 150));
        await _deleteIfExists(destination);
      }
    }
  }

  Future<bool> _isWordRunning() async {
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'IMAGENAME eq WINWORD.EXE',
        '/NH',
      ]);
      final stdoutStr = result.stdout.toString().toLowerCase();
      return stdoutStr.contains('winword.exe');
    } catch (_) {
      return false;
    }
  }

  Future<bool> isWordRunning() => _isWordRunning();
}
