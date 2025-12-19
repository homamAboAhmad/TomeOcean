import 'dart:async';
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
  rendering, // pageRender.exe
  fixingImages, // fix_word_images.exe
  parsing,
  caching,
  indexing,
  completed,
  failed,
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

  ActiveTask({
    required this.id,
    required this.title,
    this.state = ProcessingState.preparing,
    this.progress = 0.0,
    this.message = "",
    this.isCancelled = false,
  });
}

/// خدمة مركزية لإدارة معالجة الكتب (تخطيط، تحليل، كاش، فهرسة)
class BookProcessingService {
  // Singleton
  static final BookProcessingService _instance =
      BookProcessingService._internal();
  factory BookProcessingService() => _instance;
  BookProcessingService._internal();

  // State management for UI (Background Task Bar)
  final ValueNotifier<List<ActiveTask>> activeTasksNotifier = ValueNotifier([]);

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

  /// إلغاء مهمة بناءً على مسار الملف
  void cancelTask(String taskId) {
    final task = _activeTasks[taskId];
    if (task != null) {
      task.isCancelled = true;
      debugPrint("Task Cancelled: ${task.title}");
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

  Future<void> _executeProcess(
    StreamController<BookProcessingEvent> controller,
    String sourceFilePath,
    ActiveTask task,
  ) async {
    void emit(ProcessingState state, double progress, String message) {
      if (controller.isClosed) return;
      controller.add(BookProcessingEvent(state, progress, message));
      _updateTask(task, state, progress, message);
    }

    // Helper to check cancellation
    bool checkCancelled() {
      if (task.isCancelled) {
        emit(ProcessingState.failed, 0.0, "تم إلغاء العملية");
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

    // 1. صفحة التخطيط
    emit(ProcessingState.rendering, 0.1, "تحديث تخطيط الصفحات...");

    String finalBookPath = "";
    String fileName = p.basename(sourceFilePath);
    finalBookPath = p.join(BOOKS_FOLDER_PATH, fileName);

    try {
      await ExeRunner().runExe(BOOKS_FOLDER_PATH, fileName, (output) {
        if (task.isCancelled) return;
        if (output.startsWith('PROGRESS:')) {
          final pct = int.tryParse(output.replaceFirst('PROGRESS:', '')) ?? 0;
          if (pct > 0 && pct < 100) {
            emit(
              ProcessingState.rendering,
              pct / 100,
              "تحديث تخطيط الصفحات... ($pct%)",
            );
          }
        } else if (output.startsWith('WARNING:FONT_RESTRICTED')) {
          emit(ProcessingState.rendering, 0.9, "تنبيه: خطوط محمية");
        }
      });
    } catch (e) {
      emit(ProcessingState.failed, 0.0, "خطأ في معالجة الملف: $e");
      return;
    }

    if (checkCancelled()) return;

    if (!File(finalBookPath).existsSync()) {
      emit(ProcessingState.failed, 0.0, "فشل في إنشاء ملف الكتاب");
      return;
    }

    emit(ProcessingState.rendering, 1.0, "تم تحديث التخطيط");

    if (checkCancelled()) return;

    // 2. إصلاح الصور
    emit(ProcessingState.fixingImages, 0.0, "فحص الصور...");
    await _runImageFixer(finalBookPath);
    emit(ProcessingState.fixingImages, 1.0, "تم فحص الصور");

    if (checkCancelled()) return;

    // 3. تحليل وكاش
    emit(ProcessingState.parsing, 0.0, "تحليل المحتوى...");

    List<WordPage> pages = [];
    try {
      // نمرر دالة emit بدلاً من Controller لتحديث task أيضاً
      pages = await _parseAndCacheBookInternal(
        finalBookPath,
        (s, p, m) => emit(s, p, m),
        isCancelled: () => task.isCancelled,
      );

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
      emit(ProcessingState.failed, 0.0, "فشل التحليل: $e");
      return;
    }

    if (checkCancelled()) return;

    // 4. الفهرسة
    emit(ProcessingState.indexing, 0.0, "بناء الفهرس...");
    final indexer = ShamelaSearchIndexer();
    final indexResult = await indexer.indexBookFromPages(
      finalBookPath,
      pages,
      onProgress: (progress, message) {
        if (!task.isCancelled) {
          emit(ProcessingState.indexing, progress, message);
        }
      },
    );

    if (checkCancelled()) return;

    if (indexResult) {
      emit(ProcessingState.indexing, 1.0, "تمت الفهرسة");
    } else {
      emit(ProcessingState.indexing, 1.0, "تخطي الفهرسة (خطأ أو فارغ)");
    }

    emit(ProcessingState.completed, 1.0, "اكتملت العملية");
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
        exePath = "dist\\$exeName";
        if (!await File(exePath).exists()) {
          exePath = "scripts\\$exeName";
          if (!await File(exePath).exists()) {
            exePath = exeName;
          }
        }
      }

      if (await File(exePath).exists()) {
        await Process.run(exePath, [filePath]);
      }
    } catch (e) {
      debugPrint("Could not run Image Fixer: $e");
    }
  }

  /// المنطق الداخلي للتحليل والكاش
  Future<List<WordPage>> _parseAndCacheBookInternal(
    String filePath,
    Function(ProcessingState, double, String)? emit, {
    bool Function()? isCancelled,
  }) async {
    WordDocument wordDocument = WordDocument();
    wordDocument.title = getFileName(filePath);

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
