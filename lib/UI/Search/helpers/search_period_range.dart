import 'package:golden_shamela/Utils/AuthorDeathDateParser.dart';

enum SearchPeriodRangeType { year, century }

class SearchPeriodRange {
  final SearchPeriodRangeType type;
  final int startYear;
  final int endYear;
  final String label;

  const SearchPeriodRange({
    required this.type,
    required this.startYear,
    required this.endYear,
    required this.label,
  });

  String get id => '${type.name}:$startYear:$endYear';

  bool containsDeathYear(String? deathYear) {
    return AuthorDeathDateParser.parse(deathYear).matchesRange(
      startYear,
      endYear,
    );
  }

  Map<String, dynamic> toSearchItem() {
    return {
      'type': 'period',
      'name': label,
      'periodId': id,
      'periodType': type.name,
      'periodStartYear': startYear,
      'periodEndYear': endYear,
      'bookPath': null,
      'authorId': null,
      'deathYear': null,
    };
  }

  factory SearchPeriodRange.year({
    required int fromYear,
    required int toYear,
  }) {
    final start = fromYear <= toYear ? fromYear : toYear;
    final end = fromYear <= toYear ? toYear : fromYear;
    final label = start == end
        ? 'وفاة المؤلف سنة $start هـ'
        : 'وفاة المؤلف من $start إلى $end هـ';
    return SearchPeriodRange(
      type: SearchPeriodRangeType.year,
      startYear: start,
      endYear: end,
      label: label,
    );
  }

  factory SearchPeriodRange.century({
    required int fromCentury,
    required int toCentury,
    required int currentHijriYear,
  }) {
    final startCentury = fromCentury <= toCentury ? fromCentury : toCentury;
    final endCentury = fromCentury <= toCentury ? toCentury : fromCentury;
    final startYear = startCentury == 0 ? 0 : ((startCentury - 1) * 100) + 1;
    final endYear = endCentury == 0
        ? 0
        : _centuryEndYear(endCentury, currentHijriYear);
    final label = startCentury == endCentury
        ? 'وفاة المؤلف في ${centuryLabel(startCentury, currentHijriYear)}'
        : 'وفاة المؤلف من ${centuryLabel(startCentury, currentHijriYear)} إلى ${centuryLabel(endCentury, currentHijriYear)}';
    return SearchPeriodRange(
      type: SearchPeriodRangeType.century,
      startYear: startYear,
      endYear: endYear,
      label: label,
    );
  }

  factory SearchPeriodRange.fromSearchItem(Map<String, dynamic> item) {
    final typeName = item['periodType'] as String? ?? 'year';
    final type = SearchPeriodRangeType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => SearchPeriodRangeType.year,
    );
    return SearchPeriodRange(
      type: type,
      startYear: (item['periodStartYear'] as num?)?.toInt() ?? 0,
      endYear: (item['periodEndYear'] as num?)?.toInt() ?? 0,
      label: item['name'] as String? ?? 'فترة وفاة المؤلف',
    );
  }

  static List<SearchPeriodRange> fromSearchItems(
    List<Map<String, dynamic>> items,
  ) {
    return items
        .where((item) => item['type'] == 'period')
        .map(SearchPeriodRange.fromSearchItem)
        .toList();
  }

  static int currentHijriYear() {
    final now = DateTime.now();
    return (((now.year - 622) * 33) / 32).floor();
  }

  static int currentHijriCentury() {
    final year = currentHijriYear();
    return ((year - 1) ~/ 100) + 1;
  }

  static String centuryLabel(int century, int currentHijriYear) {
    if (century == 0) return 'قبل القرن الأول الهجري';
    final currentCentury = ((currentHijriYear - 1) ~/ 100) + 1;
    if (century == currentCentury) return 'القرن الحالي';
    const names = [
      '',
      'الأول',
      'الثاني',
      'الثالث',
      'الرابع',
      'الخامس',
      'السادس',
      'السابع',
      'الثامن',
      'التاسع',
      'العاشر',
      'الحادي عشر',
      'الثاني عشر',
      'الثالث عشر',
      'الرابع عشر',
      'الخامس عشر',
    ];
    final name = century < names.length ? names[century] : '$century';
    return 'القرن $name الهجري';
  }

  static int _centuryEndYear(int century, int currentHijriYear) {
    final end = century * 100;
    return end > currentHijriYear ? currentHijriYear : end;
  }
}
