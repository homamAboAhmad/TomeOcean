// lib/Dialogs/Author/author_dialog_view_model.dart
import '../../Models/Author.dart';
import 'author_dialog_controller.dart';

/// ViewModel for author dialog - handles state and business logic
class AuthorDialogViewModel {
  final AuthorDialogController _controller = AuthorDialogController();
  
  /// Creates and saves an author from form data
  Future<Author> saveAuthor({
    String? id,
    required String name,
    String? deathYear,
    String description = '',
  }) async {
    final author = _controller.createAuthorFromFormData(
      id: id,
      name: name,
      deathYear: deathYear,
      description: description,
    );
    
    await _controller.saveAuthor(author);
    return author;
  }
}

