import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:golden_shamela/Helpers/ExeRunner.dart';
import 'package:golden_shamela/Helpers/FileHelper.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Models/WordDocument.dart';
import 'package:golden_shamela/Models/WordPage.dart';
import 'package:golden_shamela/Utils/FileToArchive.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/wordToHTML/AddDocData.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:golden_shamela/Controllers/PathController.dart';

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
  final Queue<Completer<void>> _wordQueue = Queue();

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
  Stream<BookProcessingEvent> processBook(String sourceFilePath) {
    final fileName = p.basename(sourceFilePath);
    final task = ActiveTask(id: sourceFilePath, title: fileName);

    // broadcast allows multiple listeners (Dialog + Background Bar)
    final controller = StreamController<BookProcessingEvent>.broadcast();

    // Use microtask to avoid updating state immediately during a build phase
    Future.microtask(() {
      _addTask(task);
      _executeProcess(controller, sourceFilePath, task).then((_) {
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

  // Pipeline: انتظار دور Word
  Future<void> _acquireWordLock() async {
    if (!_isWordProcessing) {
      _isWordProcessing = true;
      return;
    }
    // انتظار في الطابور
    final completer = Completer<void>();
    _wordQueue.add(completer);
    await completer.future;
    // عند هنا، نكون قد حصلنا على القفل (لأن releaseWordLock يكملنا ولا يحرر المتغير)
    // لكن المتغير يبقى true لأن هناك عملية نشطة (نحن)
  }

  // Pipeline: تحرير Word للتالي في الطابور
  void _releaseWordLock() {
    if (_wordQueue.isNotEmpty) {
      final next = _wordQueue.removeFirst();
      next.complete();
    } else {
      _isWordProcessing = false;
    }
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
    ActiveTask task,
  ) async {
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
        return true;
      }
      return false;
    }

    emit(ProcessingState.preparing, 0.0, "تجهيز الملف...");

    if (!sourceFilePath.toLowerCase().endsWith('.docx')) {
      emit(ProcessingState.failed, 0.0, "الملف يجب أن يكون بصيغة docx");
      return;
    }

    if (p.basename(sourceFilePath).startsWith('~\$')) {
      emit(ProcessingState.failed, 0.0, "لا يمكن معالجة الملفات المؤقتة");
      return;
    }

    if (checkCancelled()) return;

    // 1. مرحلة Word (مقيدة بـ 1 في نفس الوقت)
    emit(ProcessingState.waitingForWord, 0.1, "في انتظار دور Word...");
    await _acquireWordLock();

    if (checkCancelled()) {
      _releaseWordLock();
      return;
    }

    emit(ProcessingState.rendering, 0.2, "تحديث تخطيط الصفحات (Word)...");

    String fileName = p.basename(sourceFilePath);
    String fileNameNoExt = p.basenameWithoutExtension(sourceFilePath);
    String tempFilePath = p.join(
      BOOKS_FOLDER_PATH,
      "_temp_$fileNameNoExt.docx",
    );
    String finalBookPath = p.join(BOOKS_FOLDER_PATH, fileName);

    String? wordError; // لالتقاط رسالة الخطأ من سكريبت Python
    try {
      // المرحلة 1: Word Repaginate فقط
      await ExeRunner().runExe(
        BOOKS_FOLDER_PATH,
        sourceFilePath,
        (output) {
          if (task.isCancelled) return;
          if (output.startsWith('STATUS:')) {
            emit(
              ProcessingState.rendering,
              0.4,
              output.replaceFirst('STATUS:', ''),
            );
          } else if (output.startsWith('ERROR:')) {
            // التقاط رسالة الخطأ
            wordError = output.replaceFirst('ERROR:', '').trim();
            debugPrint("WORD ERROR: $wordError");
          } else {
            debugPrint("WORD OUTPUT: $output");
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

    // 2. مرحلة XML (متوازية - بدون قيود)
    emit(ProcessingState.rendering, 0.6, "معالجة XML...");

    try {
      await ExeRunner().runExe(
        BOOKS_FOLDER_PATH,
        tempFilePath, // المدخل هو الملف المؤقت
        (output) {
          if (task.isCancelled) return;
          if (output.startsWith('PROGRESS:')) {
            final pct = int.tryParse(output.replaceFirst('PROGRESS:', '')) ?? 0;
            if (pct > 0 && pct < 100) {
              emit(
                ProcessingState.rendering,
                0.6 + (pct / 100) * 0.3,
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
    emit(ProcessingState.fixingImages, 0.0, "فحص الصور...");

    // Copy finalBookPath back to tempFilePath to ensure we have the XML markers
    // This allows us to fix images and parse without modifying the persistent library file
    try {
      await File(finalBookPath).copy(tempFilePath);
    } catch (e) {
      debugPrint("Failed to copy final book to temp: $e");
      emit(ProcessingState.failed, 0.0, "فشل في إعداد الملف المؤقت: $e");
      return;
    }

    // تشغيل الإصلاح على الملف المؤقت
    await _runImageFixer(tempFilePath);
    emit(ProcessingState.fixingImages, 1.0, "تم فحص الصور");

    if (checkCancelled()) {
      try {
        if (File(tempFilePath).existsSync()) await File(tempFilePath).delete();
      } catch (_) {}
      return;
    }

    // 4. تحليل وكاش (من الملف المؤقت)
    emit(ProcessingState.parsing, 0.0, "تحليل المحتوى...");

    List<WordPage> pages = [];
    try {
      // نمرر دالة emit بدلاً من Controller لتحديث task أيضاً
      // ونستخدم الملف المؤقت كمصدر، لكن العنوان الأصلي للكاش
      pages = await _parseAndCacheBookInternal(
        tempFilePath,
        (s, p, m) => emit(s, p, m),
        isCancelled: () => task.isCancelled,
        titleOverride:
            fileNameNoExt, // مهم: الحفظ باسم الملف الأصلي (بدون لاحقة)
      );

      // الآن يمكننا حذف الملف المؤقت
      try {
        if (File(tempFilePath).existsSync()) {
          await File(tempFilePath).delete();
        }
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

      emit(ProcessingState.caching, 1.0, "تم الحفظ في الذاكرة");
    } catch (e) {
      debugPrint("Error parsing book: $e");
      // محاولة تنظيف المؤقت عند الخطأ
      try {
        if (File(tempFilePath).existsSync()) await File(tempFilePath).delete();
      } catch (_) {}

      emit(ProcessingState.failed, 0.0, "فشل التحليل: $e");
      return;
    }

    if (checkCancelled()) return;

    if (checkCancelled()) return;

    if (checkCancelled()) return;

    // 4. الفهرسة (متوازية منطقياً - متسلسلة في الحفظ فقط)
    emit(ProcessingState.indexing, 0.0, "جاري بناء الفهرس...");

    // No Global Lock Here - Passed to Engine instead

    try {
      final indexer = ShamelaSearchIndexer();
      final indexResult = await indexer.indexBookFromPages(
        finalBookPath,
        pages,
        onProgress: (progress, message) {
          if (!task.isCancelled) {
            emit(ProcessingState.indexing, progress, message);
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

    emit(ProcessingState.completed, 1.0, "اكتملت العملية");

    // تسجيل النتيجة النهائية
    batchResults[task.id] = ProcessingState.completed;
  }

  /// معالجة سريعة لفتح الكتاب (بدون تتبع كـ Task في البار)
  Future<void> parseAndCacheForOpening(String filePath) async {
    // 1. إصلاح الصور
    await _runImageFixer(filePath);

    // 2. تحليل وكاش
    await _parseAndCacheBookInternal(filePath, null);
  }

  /// تشغيل أداة إصلاح الصور
  Future<void> _runImageFixer(String filePath) async {
    try {
      String exeName = "fix_word_images.exe";
      String exePath =
          "${File(Platform.resolvedExecutable).parent.path}\\$exeName";

      if (!await File(exePath).exists()) {
        // Check inside assets (Release mode)
        exePath =
            "${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\exe\\$exeName";
      }

      if (!await File(exePath).exists()) {
        exePath = "dist\\$exeName";
        if (!await File(exePath).exists()) {
          exePath = "scripts\\$exeName";
          if (!await File(exePath).exists()) {
            // New check: scripts/dist/fix_word_images.exe
            exePath = "scripts\\dist\\$exeName";
            if (!await File(exePath).exists()) {
              exePath = exeName;
            }
          }
        }
      }

      print("🔍 Looking for Image Fixer EXE. CWD: ${Directory.current.path}");
      if (await File(exePath).exists()) {
        print("🚀 Running Image Fixer EXE at: $exePath");
        try {
          final result = await Process.run(exePath, [filePath]);
          print("🏁 Fixer Finished. Exit Code: ${result.exitCode}");
          if (result.stdout.toString().isNotEmpty)
            print("STDOUT: ${result.stdout}");
          if (result.stderr.toString().isNotEmpty)
            print("STDERR: ${result.stderr}");
        } catch (e) {
          print("❌ Error launching process: $e");
        }
      } else {
        print(
          "⚠️ Image Fixer EXE not found in any expected location. Checked: $exePath (and others)",
        );
      }
    } catch (e) {
      print("❌ Could not run Image Fixer: $e");
    }
  }

  /// المنطق الداخلي للتحليل والكاش
  Future<List<WordPage>> _parseAndCacheBookInternal(
    String filePath,
    Function(ProcessingState, double, String)? emit, {
    bool Function()? isCancelled,
    String? titleOverride, // Optional override for cache key
  }) async {
    WordDocument wordDocument = WordDocument();
    wordDocument.title = titleOverride ?? getFileName(filePath);

    final appDocsDir = await getApplicationDocumentsDirectory();
    final tomeOceanDir = Directory('${appDocsDir.path}/tome_ocean');
    final bookCacheDir = Directory(
      '${tomeOceanDir.path}/${wordDocument.title}',
    );
    final metadataFile = File('${bookCacheDir.path}/metadata.json');
    final pagesDir = Directory('${bookCacheDir.path}/pages');

    // التحليل
    final appState = AppState();
    appState.docArchive = await FileToArchive(filePath);
    wordDocument.archive = appState.docArchive;

    emit?.call(ProcessingState.parsing, 0.5, "قراءة هيكل المستند...");

    List<WordPage> parsedPages = await AddDocData(
      appState.docArchive,
      wordDocument,
      onProgress: (current, total) {
        if (total > 0) {
          // Map from 50% to 100%
          double progress = 0.5 + (0.5 * current / total);
          emit?.call(
            ProcessingState.parsing,
            progress,
            "تحليل: $current/$total",
          );
        }
      },
    );
    wordDocument.setLoadedPages(parsedPages);

    emit?.call(ProcessingState.parsing, 1.0, "تم التحليل");

    // الحفظ
    emit?.call(ProcessingState.caching, 0.0, "جاري الحفظ...");

    await bookCacheDir.create(recursive: true);
    await pagesDir.create(recursive: true);

    final metadataJsonMap = wordDocument.toMetadataJson();
    await metadataFile.writeAsString(jsonEncode(metadataJsonMap));

    // حفظ الصفحات
    for (int i = 0; i < parsedPages.length; i++) {
      final jsonFile = File('${pagesDir.path}/$i.json');

      // Save pages using GZIP
      final pagesJson = jsonEncode(parsedPages[i].toJson());
      final gzipBytes = GZipCodec().encode(utf8.encode(pagesJson));
      final jsonGzFile = File('${jsonFile.path}.gz');
      await jsonGzFile.writeAsBytes(gzipBytes);

      // Clean up old json file if it exists to save space
      if (await jsonFile.exists()) {
        await jsonFile.delete();
      }

      if (i % 10 == 0) {
        double progress = i / parsedPages.length;
        emit?.call(ProcessingState.caching, progress, "حفظ صفحة $i...");
      }
    }
    return parsedPages;
  }
}
