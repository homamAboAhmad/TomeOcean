import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:golden_shamela/Models/Author.dart';
import 'package:golden_shamela/Models/BookMetadataOptions.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_book_item.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_books_fragment.dart';
import 'package:golden_shamela/UI/LibraryCommon/library_design_tokens.dart';
import 'package:golden_shamela/UI/Settings/app_color_settings.dart';
import 'package:golden_shamela/UI/Settings/app_font_settings.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';

class LibraryDataListShell extends StatelessWidget {
  final String countLabel;
  final Widget child;

  const LibraryDataListShell({
    super.key,
    required this.countLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 30,
          alignment: Alignment.center,
          color: LibraryDesignTokens.header,
          child: Text(
            countLabel,
            style: const TextStyle(color: accentColor),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class LibraryDataBooksPane extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final List<LibraryBookItem> books;
  final String? selectedPath;
  final String scope;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onScopeChanged;
  final ValueChanged<LibraryBookItem> onSelected;
  final List<Widget> leadingActions;

  const LibraryDataBooksPane({
    super.key,
    required this.controller,
    required this.hint,
    required this.books,
    required this.selectedPath,
    required this.scope,
    required this.onSearchChanged,
    required this.onScopeChanged,
    required this.onSelected,
    this.leadingActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LibraryBooksFragment(
      searchController: controller,
      searchHint: hint,
      books: books,
      selectedPath: selectedPath,
      favoritePaths: const {},
      leadingActions: leadingActions,
      onSearchChanged: onSearchChanged,
      onSelected: onSelected,
      onDoubleTap: onSelected,
      onFavoriteChanged: (_, __) {},
      searchScope: scope,
      onSearchScopeChanged: onScopeChanged,
    );
  }
}

class LibraryDataAuthorDetailsPane extends StatelessWidget {
  final Author? author;

  const LibraryDataAuthorDetailsPane({super.key, required this.author});

  @override
  Widget build(BuildContext context) {
    final currentAuthor = author;
    if (currentAuthor == null) {
      return const Center(child: Text('اختر مؤلفًا'));
    }
    return _DetailsSurface(child: _AuthorBio(author: currentAuthor));
  }
}

class LibraryDataBookDetailsPane extends StatelessWidget {
  final ValueListenable<Future<LibraryBookItem?>?> details;

  const LibraryDataBookDetailsPane({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return _FutureDetailsPane(
      details: details,
      emptyText: 'اختر كتابًا لعرض بياناته',
      errorText: 'تعذر تحميل بيانات الكتاب',
      builder: (item) => _DetailsSurface(child: _BookMetadata(item: item)),
    );
  }
}

class LibraryDataBriefDetailsPane extends StatelessWidget {
  final ValueListenable<Future<LibraryBookItem?>?> details;

  const LibraryDataBriefDetailsPane({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return _FutureDetailsPane(
      details: details,
      emptyText: 'اختر نبذة',
      errorText: 'تعذر تحميل النبذة',
      builder: (item) => _DetailsSurface(child: _BriefMetadata(item: item)),
    );
  }
}

class _FutureDetailsPane extends StatelessWidget {
  final ValueListenable<Future<LibraryBookItem?>?> details;
  final String emptyText;
  final String errorText;
  final Widget Function(LibraryBookItem item) builder;

  const _FutureDetailsPane({
    required this.details,
    required this.emptyText,
    required this.errorText,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Future<LibraryBookItem?>?>(
      valueListenable: details,
      builder: (_, future, __) {
        if (future == null) return Center(child: Text(emptyText));
        return FutureBuilder<LibraryBookItem?>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final item = snapshot.data;
            if (item == null) return Center(child: Text(errorText));
            return builder(item);
          },
        );
      },
    );
  }
}

class _DetailsSurface extends StatelessWidget {
  final Widget child;

  const _DetailsSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(left: AppChrome.borderSide()),
      ),
      padding: const EdgeInsets.all(18),
      child: SingleChildScrollView(child: child),
    );
  }
}

class _AuthorBio extends StatelessWidget {
  final Author author;

  const _AuthorBio({required this.author});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(_title),
        const SizedBox(height: 12),
        _TextBlock(
          author.description.isEmpty
              ? 'لا توجد ترجمة محفوظة لهذا المؤلف.'
              : author.description,
        ),
      ],
    );
  }

  String get _title {
    final death = author.deathYear?.trim() ?? '';
    if (death.isEmpty) return author.name;
    return '${author.name} ($death)';
  }
}

class _BookMetadata extends StatelessWidget {
  final LibraryBookItem item;

  const _BookMetadata({required this.item});

  @override
  Widget build(BuildContext context) {
    final book = item.book;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(book.title),
        const SizedBox(height: 12),
        _Line('المؤلف', item.authorDisplay),
        _Line('القسم', item.sectionTitle),
        _Line('النوع', BookMetadataOptions.typeLabel(book.bookType)),
        _Line(
          'التقييم',
          book.matchesPrinted ? 'موافق للمطبوع' : 'غير موافق للمطبوع',
        ),
        if (book.publisher.isNotEmpty) _Line('الناشر', book.publisher),
        if (book.edition.isNotEmpty) _Line('الطبعة', book.edition),
        if (book.pageCount.isNotEmpty) _Line('عدد الصفحات', book.pageCount),
        if (book.description.trim().isNotEmpty) ...[
          const Divider(height: 28, color: LibraryDesignTokens.divider),
          const _SectionTitle('نبذة عن الكتاب'),
          _TextBlock(book.description),
        ],
      ],
    );
  }
}

class _BriefMetadata extends StatelessWidget {
  final LibraryBookItem item;

  const _BriefMetadata({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Title(item.title),
        const SizedBox(height: 8),
        _Line('المؤلف', item.authorDisplay),
        if (item.sectionTitle.isNotEmpty) _Line('القسم', item.sectionTitle),
        const Divider(height: 28, color: LibraryDesignTokens.divider),
        _TextBlock(_briefText),
      ],
    );
  }

  String get _briefText {
    final brief = item.book.description.trim();
    return brief.isEmpty ? 'لا توجد نبذة محفوظة.' : brief;
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    final titleColor = AppUiColors.color(AppColorRole.titles);
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppUiFonts.style(
        AppFontRole.bookCard,
        TextStyle(
        color: titleColor,
        fontSize: 21,
        fontWeight: FontWeight.bold,
        ),
        sizeOffset: 6,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final titleColor = AppUiColors.color(AppColorRole.titles);
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppUiFonts.style(
        AppFontRole.bookCard,
        TextStyle(
        color: titleColor,
        fontSize: 17,
        fontWeight: FontWeight.bold,
        ),
        sizeOffset: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: AppUiFonts.style(
            AppFontRole.bookCard,
            const TextStyle(color: accentColor, fontSize: 16),
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppUiColors.color(AppColorRole.titles),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String text;

  const _TextBlock(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: AppUiFonts.style(
        AppFontRole.bookCard,
        const TextStyle(fontSize: 17, height: 1.7),
        sizeOffset: 2,
      ),
    );
  }
}
