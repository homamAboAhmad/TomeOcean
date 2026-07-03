import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'library_book_card_panel.dart';
import 'library_book_item.dart';

class LibraryLazyBookCardPanel extends StatelessWidget {
  final ValueListenable<Future<LibraryBookItem?>?> details;

  const LibraryLazyBookCardPanel({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Future<LibraryBookItem?>?>(
      valueListenable: details,
      builder: (_, future, __) {
        if (future == null) return const LibraryBookCardPanel(item: null);
        return FutureBuilder<LibraryBookItem?>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return LibraryBookCardPanel(item: snapshot.data);
          },
        );
      },
    );
  }
}
