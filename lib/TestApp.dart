import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Helpers/ExeRunner.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'Services/AppStoragePaths.dart';

/// عرض ديالوج معالجة الملف
Future<Map<String, dynamic>?> showFileProcessDialog(
  BuildContext context,
  String filePath, {
  bool? update,
}) async {
  return await showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: false,
    builder: (c) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: FileProcessingDialog(filePath, update: update),
      );
    },
  );
}

// للتوافق مع الكود القديم
showFileProcessDailog(
  BuildContext context,
  String filePath, {
  bool? update,
}) async {
  return await showFileProcessDialog(context, filePath, update: update);
}

class FileProcessingDialog extends StatefulWidget {
  final String filePath;
  final bool? update;

  const FileProcessingDialog(this.filePath, {super.key, this.update});

  @override
  State<FileProcessingDialog> createState() => _FileProcessingDialogState();
}

class _FileProcessingDialogState extends State<FileProcessingDialog> {
  double progress = 0.0;
  String statusMessage = "جاري التجهيز...";
  String? warningMessage;
  String? errorMessage;
  bool isComplete = false;
  bool hasWarning = false;

  @override
  void initState() {
    super.initState();

    if (_alreadyExists(widget.filePath) && widget.update != true) {
      _onComplete();
    } else {
      _processFile(widget.filePath);
    }
  }

  Future<void> _processFile(String filePath) async {
    final bookId = AppStoragePaths.bookIdFromPath(filePath);
    final sessionDir = await AppStoragePaths.createProcessingSessionDir(bookId);
    try {
      await ExeRunner().runExe(sessionDir.path, filePath, (output) {
        _handleOutput(output.trim());
      });
    } finally {
      if (await sessionDir.exists()) {
        await sessionDir.delete(recursive: true);
      }
    }

    // إذا لم يحدث خطأ، أكمل
    if (errorMessage == null) {
      _onComplete();
    }
  }

  void _handleOutput(String output) {
    for (var line in output.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('PROGRESS:')) {
        // تحديث شريط التقدم
        final pct = int.tryParse(line.replaceFirst('PROGRESS:', '')) ?? 0;
        setState(() {
          progress = pct / 100;
        });
      } else if (line.startsWith('STATUS:')) {
        // تحديث رسالة الحالة
        setState(() {
          statusMessage = line.replaceFirst('STATUS:', '');
        });
      } else if (line.startsWith('WARNING:')) {
        // رسالة تحذير
        final warning = line.replaceFirst('WARNING:', '');
        if (warning == 'FONT_RESTRICTED') {
          hasWarning = true;
          warningMessage =
              'المستند يحتوي على خطوط محمية.\n'
              'تم نسخ الملف لكن قد تحتاج لفتحه في Word وحفظه يدوياً لتحديث تقسيم الصفحات.';
        }
      } else if (line.startsWith('ERROR:')) {
        // رسالة خطأ
        setState(() {
          errorMessage = line.replaceFirst('ERROR:', '');
        });
      } else if (line == 'SUCCESS') {
        setState(() {
          progress = 1.0;
          statusMessage = "تمت إضافة الكتاب بنجاح!";
        });
      }
    }
  }

  void _onComplete() {
    setState(() {
      isComplete = true;
      progress = 1.0;
      if (errorMessage == null) {
        statusMessage = "تمت إضافة الكتاب بنجاح!";
      }
    });

    // إغلاق تلقائي بعد ثانيتين إذا لم يكن هناك تحذير أو خطأ
    if (!hasWarning && errorMessage == null) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pop({'success': true});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الأيقونة
          _buildIcon(),
          const SizedBox(height: 20),

          // العنوان
          Text(
            isComplete
                ? (errorMessage != null ? 'حدث خطأ' : 'تم بنجاح!')
                : 'جاري معالجة الكتاب',
            style: bigStyle().copyWith(
              color: errorMessage != null ? Colors.red : primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // اسم الملف
          Text(
            _getFileName(widget.filePath),
            style: normalStyle().copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // شريط التقدم
          if (!isComplete || errorMessage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  errorMessage != null ? Colors.red : primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // رسالة الحالة
          Text(
            errorMessage ?? statusMessage,
            style: normalStyle().copyWith(
              color: errorMessage != null ? Colors.red : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),

          // رسالة التحذير
          if (warningMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      warningMessage!,
                      style: normalStyle().copyWith(
                        color: Colors.orange[800],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // زر الإغلاق
          if (isComplete || hasWarning || errorMessage != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).pop(errorMessage == null ? {'success': true} : null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  hasWarning ? 'فهمت' : (errorMessage != null ? 'إغلاق' : 'تم'),
                  style: normalStyle().copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    if (errorMessage != null) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.error_outline, color: Colors.red, size: 32),
      );
    } else if (isComplete) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check_circle_outline, color: primaryColor, size: 32),
      );
    } else {
      return SizedBox(
        width: 60,
        height: 60,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
        ),
      );
    }
  }

  String _getFileName(String path) {
    return path.split('\\').last.split('/').last;
  }

  bool _alreadyExists(String filePath) {
    final txtFile = File(filePath.replaceFirst(".docx", "_pages.txt"));
    return txtFile.existsSync();
  }
}
