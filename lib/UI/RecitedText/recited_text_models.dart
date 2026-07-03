class ChapterInfo {
  final int number;
  final String name;
  final String englishName;
  final int totalPassages;
  final int startIndex;

  const ChapterInfo({
    required this.number,
    required this.name,
    required this.englishName,
    required this.totalPassages,
    required this.startIndex,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) {
    return ChapterInfo(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      totalPassages: json['totalPassages'] as int? ?? 0,
      startIndex: json['startIndex'] as int? ?? 0,
    );
  }
}

class PassageUnit {
  final int chapterNumber;
  final int passageNumber;
  final String passageKey;
  final int pageNumber;
  final int juzNumber;
  final int hizbNumber;
  final int quarterNumber;
  final int quarterIndex;
  final String text;
  final String textImlaei;

  const PassageUnit({
    required this.chapterNumber,
    required this.passageNumber,
    required this.passageKey,
    required this.pageNumber,
    required this.juzNumber,
    required this.hizbNumber,
    required this.quarterNumber,
    required this.quarterIndex,
    required this.text,
    required this.textImlaei,
  });

  factory PassageUnit.fromJson(Map<String, dynamic> json) {
    return PassageUnit(
      chapterNumber: json['chapterNumber'] as int? ?? 0,
      passageNumber: json['passageNumber'] as int? ?? 0,
      passageKey: json['passageKey'] as String? ?? '',
      pageNumber: json['pageNumber'] as int? ?? 0,
      juzNumber: json['juzNumber'] as int? ?? 1,
      hizbNumber: json['hizbNumber'] as int? ?? 1,
      quarterNumber: json['quarterNumber'] as int? ?? 1,
      quarterIndex: json['quarterIndex'] as int? ?? 1,
      text: json['text'] as String? ?? '',
      textImlaei: json['textImlaei'] as String? ??
          json['text_imlaei'] as String? ??
          '',
    );
  }

  String displayText({required bool useImlaeiText}) {
    if (useImlaeiText && textImlaei.isNotEmpty) return textImlaei;
    return text;
  }
}

class TafsirResource {
  final int id;
  final String name;
  final String authorName;
  final String languageName;
  final String fileName;
  final int recordCount;
  final bool isDefault;

  const TafsirResource({
    required this.id,
    required this.name,
    required this.authorName,
    required this.languageName,
    required this.fileName,
    required this.recordCount,
    required this.isDefault,
  });

  factory TafsirResource.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int? ?? 0;
    return TafsirResource(
      id: id,
      name: _localizedName(id, json['name'] as String? ?? ''),
      authorName: json['authorName'] as String? ?? '',
      languageName: json['languageName'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      recordCount: json['recordCount'] as int? ?? 0,
      isDefault: json['isDefault'] == true,
    );
  }

  static String _localizedName(int id, String fallback) {
    // ponytail: quran.com exposes this Urdu resource with a non-Urdu title.
    if (id == 157) return 'فی ظلال القرآن';
    return fallback;
  }
}

class RecitedTextFontOption {
  final String label;
  final String? fontFamily;
  final bool useImlaeiText;

  const RecitedTextFontOption({
    required this.label,
    required this.fontFamily,
    this.useImlaeiText = false,
  });
}

class RecitedTextSnapshot {
  final List<ChapterInfo> chapters;
  final List<PassageUnit> passages;
  final List<TafsirResource> tafsirResources;

  const RecitedTextSnapshot({
    required this.chapters,
    required this.passages,
    required this.tafsirResources,
  });

  TafsirResource? get defaultTafsir {
    for (final resource in tafsirResources) {
      if (resource.isDefault) return resource;
    }
    return tafsirResources.isEmpty ? null : tafsirResources.first;
  }
}

class RecitedTextSearchResult {
  final PassageUnit passage;
  final ChapterInfo chapter;
  final String snippet;

  const RecitedTextSearchResult({
    required this.passage,
    required this.chapter,
    required this.snippet,
  });
}
