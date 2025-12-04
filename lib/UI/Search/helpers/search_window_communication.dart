import 'package:desktop_multi_window/desktop_multi_window.dart';

/// مسؤول عن التواصل بين نافذة البحث والنافذة الرئيسية
class SearchWindowCommunication {
  static const String _channelName = 'golden_shamela/main_window';
  static const ChannelMode _channelMode = ChannelMode.unidirectional;

  /// إرسال معاملات البحث إلى النافذة الرئيسية
  Future<void> sendSearchParamsToMainWindow(Map<String, dynamic> searchParams) async {
    final safeParams = _convertToSafeParams(searchParams);
    const channel = WindowMethodChannel(_channelName, mode: _channelMode);
    await channel.invokeMethod('performSearch', safeParams);
  }

  /// إرسال كتاب إلى النافذة الرئيسية
  Future<void> sendBookToMainWindow(String bookPath, int pageNumber) async {
    const channel = WindowMethodChannel(_channelName, mode: _channelMode);
    await channel.invokeMethod('openBook', {
      'bookPath': bookPath,
      'pageNumber': pageNumber,
    });
  }

  Map<String, dynamic> _convertToSafeParams(Map<String, dynamic> params) {
    final safeParams = <String, dynamic>{};
    
    params.forEach((key, value) {
      if (value is Map) {
        safeParams[key] = Map<String, dynamic>.from(value);
      } else if (value is List) {
        safeParams[key] = value.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return item;
        }).toList();
      } else {
        safeParams[key] = value;
      }
    });
    
    return safeParams;
  }
}


