// lib/Dialogs/Author/author_dialog_controller.dart
import '../../Models/Author.dart';
import '../../Helpers/AuthorStorage.dart';

/// Controller for author dialog business logic
class AuthorDialogController {
  final AuthorStorage _authorStorage = AuthorStorage();

  /// Creates an Author object from form data
  Author createAuthorFromFormData({
    String? id,
    required String name,
    String? deathYear,
    String description = '',
  }) {
    return Author(
      id: id,
      name: name.trim(),
      deathYear: deathYear?.trim().isEmpty == true ? null : deathYear?.trim(),
      description: description.trim(),
    );
  }

  /// Saves author to storage
  Future<void> saveAuthor(Author author) async {
    await _authorStorage.addAuthor(author);
  }
}

