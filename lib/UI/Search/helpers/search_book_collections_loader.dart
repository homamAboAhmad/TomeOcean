import 'package:golden_shamela/Helpers/BooksMetadataDatabase.dart';

class SearchBookCollections {
  final Set<String> favoritePaths;
  final List<String> recentPaths;

  const SearchBookCollections({
    required this.favoritePaths,
    required this.recentPaths,
  });
}

class SearchBookCollectionsLoader {
  final BooksMetadataDatabase _db = BooksMetadataDatabase();

  Future<SearchBookCollections> load() async {
    await _db.initialize();
    final results = await Future.wait([
      _db.getFavoriteBookPaths(),
      _db.getRecentBookPaths(),
    ]);
    return SearchBookCollections(
      favoritePaths: results[0] as Set<String>,
      recentPaths: results[1] as List<String>,
    );
  }
}
