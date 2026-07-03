import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_icon.dart';
import 'package:golden_shamela/UI/Settings/app_other_settings.dart';

class OtherSettingsPanel extends StatelessWidget {
  final AppOtherDraft draft;
  final ValueChanged<AppOtherDraft> onChanged;

  const OtherSettingsPanel({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton(
              onPressed: () => onChanged(AppOtherDraft.defaults()),
              child: const Text('استعادة الافتراضي'),
            ),
            const Spacer(),
            Text('إعدادات أخرى', style: mediumStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const LibraryIcon(LibraryIconType.tune, color: primaryColor),
          ],
        ),
        const Divider(height: 24),
        Expanded(
          child: ListView(
            children: [
              _sectionTitle('خيارات البحث'),
              _check(
                'عرض الإكمال التلقائي في مربعات البحث',
                draft.showSearchAutocomplete,
                (v) => onChanged(draft.copyWith(showSearchAutocomplete: v)),
              ),
              _check(
                'اعرض نتيجة البحث بمجرد الانتقال إليها',
                draft.openSearchResultOnKeyboardSelection,
                (v) => onChanged(
                  draft.copyWith(openSearchResultOnKeyboardSelection: v),
                ),
              ),
              _check(
                'إظهار لائحة العناوين الجانبية افتراضيا مع الكتاب في نتائج البحث',
                draft.showSearchBookIndexByDefault,
                (v) => onChanged(draft.copyWith(showSearchBookIndexByDefault: v)),
              ),
              _check(
                'ترقيم مربعات البحث',
                draft.showSearchFieldNumbers,
                (v) => onChanged(draft.copyWith(showSearchFieldNumbers: v)),
              ),
              _number(
                'عدد مربعات البحث',
                draft.searchFieldCount,
                (v) => onChanged(draft.copyWith(searchFieldCount: v)),
              ),
              const SizedBox(height: 18),
              _sectionTitle('خيارات التحميل'),
              _disabledCheck('تحميل تلقائي للكتب'),
              _disabledCheck('تحميل المصورات يتبع تحميل النصوص تلقائيا'),
              const SizedBox(height: 18),
              _sectionTitle('متفرقات'),
              _check(
                'تذكر آخر موضع في الكتاب من: شاشة مؤخرًا',
                draft.rememberRecentBookPosition,
                (v) => onChanged(draft.copyWith(rememberRecentBookPosition: v)),
              ),
              _check(
                'تذكر آخر موضع في الكتاب من: شاشة المفضلة',
                draft.rememberFavoriteBookPosition,
                (v) => onChanged(draft.copyWith(rememberFavoriteBookPosition: v)),
              ),
              _check(
                'تذكر آخر موضع في الكتاب من: الشاشات الأخرى',
                draft.rememberOtherBookPosition,
                (v) => onChanged(draft.copyWith(rememberOtherBookPosition: v)),
              ),
              _check(
                'إنشاء اختصار للمكتبة: على سطح المكتب',
                draft.createDesktopShortcut,
                (v) => onChanged(draft.copyWith(createDesktopShortcut: v)),
              ),
              _check(
                'إنشاء اختصار للمكتبة: في قائمة ابدأ',
                draft.createStartMenuShortcut,
                (v) => onChanged(draft.copyWith(createStartMenuShortcut: v)),
              ),
              _check(
                'عند بدء تشغيل البرنامج: قم باسترجاع التبويبات المفتوحة آخر مرة',
                draft.restoreTabsOnStartup,
                (v) => onChanged(draft.copyWith(restoreTabsOnStartup: v)),
              ),
              _check(
                'عند بدء تشغيل البرنامج: تغيير لوحة المفاتيح إلى العربية',
                draft.switchKeyboardToArabicOnStartup,
                (v) => onChanged(draft.copyWith(switchKeyboardToArabicOnStartup: v)),
              ),
              _number(
                'الحد الأقصى للكلمات في رأس التبويب',
                draft.maxTabTitleWords,
                (v) => onChanged(draft.copyWith(maxTabTitleWords: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: normalStyle(
          fontSize: 13,
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.zero,
      activeColor: primaryColor,
      title: Text(label, style: normalStyle(fontSize: 13)),
      value: value,
      onChanged: (next) => onChanged(next ?? false),
    );
  }

  Widget _disabledCheck(String label) {
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: normalStyle(fontSize: 13, color: Colors.grey)),
      value: false,
      onChanged: null,
    );
  }

  Widget _number(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: normalStyle(fontSize: 13))),
          SizedBox(
            width: 72,
            child: TextFormField(
              key: ValueKey('$label:$value'),
              initialValue: value.toString(),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onChanged: (text) {
                final next = int.tryParse(text);
                if (next != null) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}
