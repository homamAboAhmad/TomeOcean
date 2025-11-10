import 'package:golden_shamela/Utils/NumberUtils.dart';

class IndexItem {
  String _title;
  int _page;
  String _type;
  String id = generateRandomKey();

  IndexItem({
    required String title,
    required int page,
    required String type,
  })  : _title = title,
        _page = page,
        _type = type;

  // getters
  String get title => _title;
  int get page => _page;
  String get type => _type;

  // setters
  set title(String value) {
    _title = value;
  }

  set page(int value) {
    _page = value;
  }

  set type(String value) {
    _type = value;
  }

  // fromJson
  factory IndexItem.fromJson(Map<String, dynamic> json) {
    return IndexItem(
      title: json['title'] ?? '',
      page: json['page'] ?? 0,
      type: json['type'] ?? '',
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'title': _title,
      'page': _page,
      'type': _type,
    };
  }
}
