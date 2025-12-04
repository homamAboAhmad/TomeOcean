import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ShamelaSearchIndexer.dart';
import 'package:golden_shamela/Models/indexing_progress.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/core/preferences_helper.dart';
import 'package:golden_shamela/core/app_state.dart';
import 'package:golden_shamela/UI/SettingsScreen.dart';

class IndexingDialog extends StatefulWidget {
  const IndexingDialog({super.key});

  @override
  State<IndexingDialog> createState() => _IndexingDialogState();
}

class _IndexingDialogState extends State<IndexingDialog> {
  IndexingProgress _progress = IndexingProgress(message: 'جاهز للفهرسة...');
  bool _isIndexing = false;
  final ShamelaSearchIndexer _indexer = ShamelaSearchIndexer();
  final ValueNotifier<bool> _cancellationNotifier = ValueNotifier(false);
  
  // New state variables for the enhanced UI
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  Timer? _timer;
  int _elapsedSeconds = 0;
  String _currentBookName = "";

  @override
  void dispose() {
    _cancellationNotifier.dispose();
    _timer?.cancel();
    _logScrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _addLog(String message) {
    if (message.isEmpty) return;
    // Avoid duplicate consecutive logs
    if (_logs.isNotEmpty && _logs.first == message) return;
    
    setState(() {
      _logs.insert(0, message); // Add to top
      if (_logs.length > 100) _logs.removeLast(); // Keep last 100 logs
    });
  }

  Future<void> _startIndexing() async {
    setState(() {
      _isIndexing = true;
      _logs.clear();
      _addLog('بدء عملية الفهرسة...');
      _progress = IndexingProgress(message: 'جارٍ التحضير...');
    });
    _startTimer();
    _cancellationNotifier.value = false;

    try {
      String? selectedDirectory = PreferencesHelper.prefs.getString('books_directory_path');
      
      if (selectedDirectory == null || selectedDirectory.isEmpty) {
        _handleError('يرجى اختيار مجلد الكتب من الإعدادات أولاً');
        return;
      }

      final dir = Directory(selectedDirectory);
      if (!await dir.exists()) {
        _handleError('المجلد المحدد غير موجود: $selectedDirectory');
        return;
      }

      _addLog('جاري فحص المجلد: $selectedDirectory');
      setState(() {
        _progress = IndexingProgress(message: 'جارٍ البحث عن ملفات .docx...');
      });

      final List<String> bookPaths = [];
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.docx')) {
          bookPaths.add(entity.path);
        }
      }

      if (bookPaths.isEmpty) {
        _handleError('لم يتم العثور على ملفات .docx في المجلد المحدد.');
        return;
      }

      _addLog('تم العثور على ${bookPaths.length} كتاب.');
      setState(() {
        _progress = IndexingProgress(
          message: 'جاري البدء...',
          totalBooks: bookPaths.length,
        );
      });

      await _indexer.indexBooks(bookPaths, (progressUpdate) {
        if (mounted) {
          setState(() {
            _progress = progressUpdate;
            
            // Extract book name from message if it contains "Indexing" or similar
            // This depends on how the indexer sends messages, but we can try to parse or just use the message
            if (progressUpdate.message.isNotEmpty) {
               // Update current book name if it looks like a path or name
               if (progressUpdate.message.contains('.docx')) {
                 _currentBookName = progressUpdate.message.split(Platform.pathSeparator).last;
               } else {
                 // Try to infer from context or just show the message
               }
            }
            
            // Add significant updates to log
            if (progressUpdate.currentBookNum > 0 && 
                progressUpdate.currentBookProgress == 0.0) {
               // Likely started a new book
               _addLog('جاري فهرسة الكتاب ${progressUpdate.currentBookNum}: $_currentBookName');
            }
          });
        }
      }, _cancellationNotifier);

      if (mounted) {
        _addLog('اكتملت الفهرسة بنجاح!');
        setState(() {
          _progress = IndexingProgress(message: 'تمت العملية بنجاح');
        });
        AppState().cachedIndexedBooks = null;
      }
    } catch (e) {
      if (mounted) {
        _handleError('حدث خطأ: $e');
      }
    } finally {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _isIndexing = false;
        });
      }
    }
  }

  void _handleError(String message) {
    _addLog('خطأ: $message');
    setState(() {
      _progress = IndexingProgress(message: message);
      _isIndexing = false;
    });
    _timer?.cancel();
  }

  void _cancelIndexing() {
    _cancellationNotifier.value = true;
    _addLog('تم طلب إلغاء العملية...');
    setState(() {
      _progress = IndexingProgress(
        message: 'جارٍ الإلغاء...',
        totalBooks: _progress.totalBooks,
        currentBookNum: _progress.currentBookNum,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 700,
        height: 550,
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
            _buildHeader(),
            Expanded(
              child: Row(
                children: [
                  // Left Side: Progress & Stats
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: _buildProgressSection(),
                    ),
                  ),
                  // Right Side: Logs (RTL: actually appears on left)
                  Expanded(
                    flex: 4,
                    child: _buildLogsSection(),
                  ),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, color: secondaryColor, size: 28),
          const SizedBox(width: 12),
          Text(
            'فهرسة المكتبة',
            style: bigStyle(color: Colors.white, fontSize: 20),
          ),
          const Spacer(),
          if (!_isIndexing)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    if (!_isIndexing && _progress.message.contains('جاهز')) {
      return _buildWelcomeState();
    }

    if (!_isIndexing && (_progress.message.contains('يرجى') || _progress.message.contains('غير موجود'))) {
      return _buildErrorState();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Circular Progress
        SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _progress.overallProgress,
                strokeWidth: 12,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(_progress.overallProgress * 100).toInt()}%',
                      style: bigStyle(color: primaryColor, fontSize: 36),
                    ),
                    Text(
                      'مكتمل',
                      style: normalStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Current Book Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('الكتاب الحالي:', style: normalStyle(color: primaryColor, fontSize: 14)),
                  Text('${_progress.currentBookNum} / ${_progress.totalBooks}', style: normalStyle(color: primaryColor, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currentBookName.isEmpty ? '...' : _currentBookName,
                style: normalStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _progress.currentBookProgress,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        // Stats Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.timer, 'الوقت المنقضي', _formatDuration(_elapsedSeconds)),
            _buildStatItem(Icons.book, 'الكتب المتبقية', '${_progress.totalBooks - _progress.currentBookNum}'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(height: 4),
        Text(value, style: bigStyle(fontSize: 16, color: primaryColor)),
        Text(label, style: smallStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildLogsSection() {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('سجل العمليات', style: normalStyle(color: Colors.grey.shade700)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logs.isEmpty
                ? Center(child: Text('لا توجد سجلات بعد', style: smallStyle(color: Colors.grey)))
                : ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.arrow_left, size: 16, color: secondaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _logs[index],
                                style: smallStyle(color: Colors.grey.shade800),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.library_books_rounded, size: 64, color: primaryColor.withOpacity(0.5)),
        const SizedBox(height: 16),
        Text(
          'مرحباً بك في مفهرس الشاملة',
          style: bigStyle(color: primaryColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'سيقوم النظام بفهرسة جميع ملفات الكتب (.docx) لتتمكن من البحث فيها بسرعة فائقة.',
          style: normalStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _startIndexing,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('بدء الفهرسة الآن'),
          style: ElevatedButton.styleFrom(
            backgroundColor: secondaryColor,
            foregroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          'تنبيه',
          style: bigStyle(color: Colors.red.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          _progress.message,
          style: normalStyle(color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('الذهاب للإعدادات'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    if (!_isIndexing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _cancelIndexing,
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            label: const Text('إلغاء العملية', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
