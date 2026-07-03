import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/dialogs/batch_file_processing_dialog.dart';

class BackgroundTasksBar extends StatelessWidget {
  const BackgroundTasksBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActiveTask>>(
      valueListenable: BookProcessingService().activeTasksNotifier,
      builder: (context, tasks, child) {
        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        // إيجاد أول كتاب نشط (ليس في الانتظار)
        final activeTask = tasks.firstWhere(
          (t) => t.state != ProcessingState.waitingForWord && t.state != ProcessingState.preparing,
          orElse: () => tasks.first,
        );
        
        final service = BookProcessingService();
        final totalTasks = service.currentBatchFiles.isEmpty
            ? tasks.length
            : service.currentBatchFiles.length;
        // حساب المكتملين نجاحاً من السجل المPersistent
        final completedTasks = service.batchResults.values
            .where((v) => v == ProcessingState.completed)
            .length
            .clamp(0, totalTasks);

        return InkWell(
          onTap: () {
            // إعادة فتح نافذة التفاصيل مع جميع ملفات الدفعة
            final filePaths = service.currentBatchFiles;
            if (filePaths.isEmpty) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => BatchFileProcessingDialog(
                filePaths: filePaths,
                isResuming: true, // لا نبدأ معالجة جديدة
              ),
            );
          },
          child: Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppChrome.headerGradient,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.16),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Icon
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: activeTask.progress > 0 ? activeTask.progress : null,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),

                // Text
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "جاري معالجة الكتب ($completedTasks/$totalTasks)",
                        style: normalStyle().copyWith(fontSize: 12, color: Colors.white),
                      ),
                      Text(
                        activeTask.message,
                        style: normalStyle().copyWith(fontSize: 10, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // اضغط للتفاصيل
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppChrome.radiusSmall),
                  ),
                  child: Text(
                    "تفاصيل",
                    style: normalStyle().copyWith(fontSize: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
