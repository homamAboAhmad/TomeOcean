import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';

enum DuplicateAction { replace, skip }

class DuplicateResolutionResult {
  final DuplicateAction action;
  final bool applyToAll;
  DuplicateResolutionResult(this.action, this.applyToAll);
}

class DuplicateResolutionDialog extends StatefulWidget {
  final String fileName;
  final int remainingDuplicates;

  const DuplicateResolutionDialog({
    super.key,
    required this.fileName,
    required this.remainingDuplicates,
  });

  @override
  State<DuplicateResolutionDialog> createState() => _DuplicateResolutionDialogState();
}

class _DuplicateResolutionDialogState extends State<DuplicateResolutionDialog> {
  bool _applyToAll = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text("ملف موجود مسبقاً", style: bigStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: normalStyle(),
                children: [
                  const TextSpan(text: "الكتاب "),
                  TextSpan(
                    text: widget.fileName, 
                    style: normalStyle(fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const TextSpan(text: " موجود بالفعل في المكتبة."),
                  const TextSpan(text: "\nماذا تريد أن تفعل؟"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.remainingDuplicates > 0)
              InkWell(
                onTap: () => setState(() => _applyToAll = !_applyToAll),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _applyToAll,
                        onChanged: (v) => setState(() => _applyToAll = v!),
                        activeColor: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "تطبيق على باقي الملفات (${widget.remainingDuplicates})",
                      style: normalStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context, 
              DuplicateResolutionResult(DuplicateAction.skip, _applyToAll),
            ),
            child: Text("تجاوز", style: normalStyle(color: Colors.grey[700]!)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(
              context, 
              DuplicateResolutionResult(DuplicateAction.replace, _applyToAll),
            ),
            child: Text("استبدال", style: normalStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
