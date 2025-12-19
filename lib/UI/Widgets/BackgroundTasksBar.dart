import 'package:flutter/material.dart';
import 'package:golden_shamela/Services/BookProcessingService.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

class BackgroundTasksBar extends StatelessWidget {
  const BackgroundTasksBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActiveTask>>(
      valueListenable: BookProcessingService().activeTasksNotifier,
      builder: (context, tasks, child) {
        // If no tasks, verify if bar should slide down or disappear
        // For simple MVP: Empty container
        if (tasks.isEmpty) {
          return const SizedBox.shrink();
        }

        // We only show the latest task for now or a summary
        final task = tasks.last;

        return Container(
          width: double.infinity,
          height: 36, // Slim bar
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 4,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Icon
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value:
                      task.state == ProcessingState.preparing ||
                          task.state == ProcessingState.rendering
                      ? null // indetermined for preparing
                      : null, // spinning
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Text(
                  "${task.title}: ${task.message}",
                  style: normalStyle().copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Percentage
              if (task.progress > 0)
                Text(
                  "${(task.progress * 100).toInt()}%",
                  style: normalStyle().copyWith(
                    fontSize: 12,
                    color: primaryColor,
                  ),
                ),

              const SizedBox(width: 12),

              // Count if multiple
              if (tasks.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "+${tasks.length - 1}",
                    style: normalStyle().copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
