import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:golden_shamela/Services/DebugLogService.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';

class DebugConsoleScreen extends StatefulWidget {
  const DebugConsoleScreen({super.key});

  @override
  State<DebugConsoleScreen> createState() => _DebugConsoleScreenState();
}

class _DebugConsoleScreenState extends State<DebugConsoleScreen> {
  final _service = DebugLogService();
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _service.logsNotifier.addListener(_onNewLog);
  }

  @override
  void dispose() {
    _service.logsNotifier.removeListener(_onNewLog);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNewLog() {
    if (mounted) {
      setState(() {});
      if (_autoScroll) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyAll(List<DebugLogEntry> logs) {
    final text = logs
        .map((e) => '[${_fmt(e.timestamp)}] ${e.source}: ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم نسخ ${logs.length} سطر',
          style: normalStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  Color _rowColor(DebugLogEntry e) {
    if (e.message.startsWith('ERROR:')) return Colors.red.withOpacity(0.12);
    if (e.source.contains('WORD')) return Colors.blue.withOpacity(0.06);
    if (e.source.contains('XML')) return Colors.green.withOpacity(0.06);
    return Colors.transparent;
  }

  Color _sourceColor(String source) {
    if (source.contains('WORD')) return Colors.blue[700]!;
    if (source.contains('XML')) return Colors.green[700]!;
    return Colors.grey[600]!;
  }

  @override
  Widget build(BuildContext context) {
    final allLogs = _service.logsNotifier.value;
    final logs = _filter.isEmpty
        ? allLogs
        : allLogs
              .where(
                (e) =>
                    e.message.toLowerCase().contains(_filter.toLowerCase()) ||
                    e.source.toLowerCase().contains(_filter.toLowerCase()),
              )
              .toList();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2A2A3E),
          elevation: 0,
          leading: IconButton(
            icon: const LibraryIcon(LibraryIconType.arrowLeft, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.terminal_rounded,
                color: Color(0xFF89DCEB),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Debug Console',
                style: normalStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${logs.length} سطر',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Auto-scroll toggle
            Tooltip(
              message: _autoScroll
                  ? 'إيقاف التمرير التلقائي'
                  : 'تفعيل التمرير التلقائي',
              child: IconButton(
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                  color: _autoScroll ? const Color(0xFFA6E3A1) : Colors.white54,
                  size: 20,
                ),
                onPressed: () => setState(() => _autoScroll = !_autoScroll),
              ),
            ),
            // Copy all
            Tooltip(
              message: 'نسخ الكل',
              child: IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: logs.isEmpty ? null : () => _copyAll(logs),
              ),
            ),
            // Clear
            Tooltip(
              message: 'مسح السجل',
              child: IconButton(
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                onPressed: logs.isEmpty
                    ? null
                    : () {
                        _service.clear();
                        setState(() {});
                      },
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Filter bar
            Container(
              color: const Color(0xFF2A2A3E),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'فلترة الرسائل...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white38,
                    size: 18,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
            // Log list
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inbox_rounded,
                            color: Colors.white12,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'لا توجد رسائل بعد\nشغّل كتاباً لترى مخرجات pageRender',
                            textAlign: TextAlign.center,
                            style: normalStyle(
                              color: Colors.white24,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final e = logs[i];
                        return _LogRow(
                          entry: e,
                          index: i,
                          bgColor: _rowColor(e),
                          sourceColor: _sourceColor(e.source),
                          timeStr: _fmt(e.timestamp),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final DebugLogEntry entry;
  final int index;
  final Color bgColor;
  final Color sourceColor;
  final String timeStr;

  const _LogRow({
    required this.entry,
    required this.index,
    required this.bgColor,
    required this.sourceColor,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: entry.message));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ السطر'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line number
            SizedBox(
              width: 36,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Timestamp
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: sourceColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.source,
                style: TextStyle(
                  color: sourceColor,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Message
            Expanded(
              child: Text(
                entry.message,
                style: TextStyle(
                  color: entry.message.startsWith('ERROR:')
                      ? const Color(0xFFF38BA8)
                      : const Color(0xFFCDD6F4),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
