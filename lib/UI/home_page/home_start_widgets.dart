part of 'home_start_view.dart';

class _EntryCard extends StatelessWidget {
  final _Entry entry;
  final double width;

  const _EntryCard({required this.entry, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
        child: InkWell(
          onTap: entry.onTap,
          borderRadius: BorderRadius.circular(AppChrome.radius),
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(16),
            decoration: AppChrome.surfaceDecoration(
              radius: AppChrome.radius,
              shadow: false,
            ),
            child: Row(
              children: [
                _IconBadge(icon: entry.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(entry.title, style: mediumStyle(color: accentColor)),
                      const SizedBox(height: 4),
                      Text(
                        entry.subtitle,
                        style: smallStyle(color: accentColor.withOpacity(0.68)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: AppChrome.borderSide(opacity: 0.85),
        borderRadius: BorderRadius.circular(AppChrome.radius),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                LibraryIcon.fromIcon(icon, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: mediumStyle(color: accentColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class _RecentBooksList extends StatelessWidget {
  final List<_RecentBook> books;
  final ValueChanged<String> onOpen;

  const _RecentBooksList({required this.books, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const _EmptyRows(text: 'لا توجد كتب حديثة');
    return Column(
      children: [
        for (final book in books)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            hoverColor: organicHoverColor,
            mouseCursor: SystemMouseCursors.click,
            leading: LibraryIcon.fromIcon(
              Icons.menu_book_outlined,
              color: primaryColor.withOpacity(0.82),
            ),
            title: Text(
              book.title,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              book.author.isEmpty ? 'مؤلف غير محدد' : book.author,
              textAlign: TextAlign.right,
            ),
            trailing: book.pageCount.isEmpty
                ? null
                : Text('${book.pageCount} ص', style: smallStyle()),
            onTap: () => onOpen(book.path),
          ),
      ],
    );
  }
}

class _SectionsList extends StatelessWidget {
  final List<LibraryEntityRow> sections;
  final ValueChanged<String> onOpenSection;

  const _SectionsList({required this.sections, required this.onOpenSection});

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const _EmptyRows(text: 'لا توجد أقسام');
    return Column(
      children: [
        for (final section in sections)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            hoverColor: organicHoverColor,
            mouseCursor: SystemMouseCursors.click,
            title: Text(
              section.title,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Text(
              section.count.toString(),
              style: smallStyle(color: actionColor),
            ),
            onTap: () => onOpenSection(section.id),
          ),
      ],
    );
  }
}

class _EmptyRows extends StatelessWidget {
  final String text;

  const _EmptyRows({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: Center(child: Text(text, style: normalStyle(color: Colors.black38))),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;

  const _SearchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: mutedColor,
        borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
        border: Border.all(color: borderColor.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LibraryIcon(LibraryIconType.chevronDown, size: 18, color: primaryColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: normalStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSubmitButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchSubmitButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actionColor,
      borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppChrome.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('بحث', style: mediumStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(width: 8),
              LibraryIcon.fromIcon(Icons.search_rounded, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;

  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: organicHighlightColor,
        borderRadius: BorderRadius.circular(AppChrome.radius),
      ),
      child: LibraryIcon.fromIcon(icon, color: primaryColor, size: 28),
    );
  }
}

class _HomePanels extends StatelessWidget {
  final _HomeStartData data;
  final ValueChanged<String> onOpenRecentBook;
  final ValueChanged<String> onOpenSection;

  const _HomePanels({
    required this.data,
    required this.onOpenRecentBook,
    required this.onOpenSection,
  });

  @override
  Widget build(BuildContext context) {
    final recent = _Panel(
      title: 'آخر الكتب',
      icon: Icons.history_edu_rounded,
      child: _RecentBooksList(books: data.recentBooks, onOpen: onOpenRecentBook),
    );
    final sections = _Panel(
      title: 'الأقسام (${data.sectionCount})',
      icon: Icons.category_outlined,
      child: _SectionsList(
        sections: data.sections.take(6).toList(),
        onOpenSection: onOpenSection,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850) {
          return Column(children: [recent, const SizedBox(height: 14), sections]);
        }
        return SizedBox(
          height: 470,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: sections),
              const SizedBox(width: 14),
              Expanded(flex: 3, child: recent),
            ],
          ),
        );
      },
    );
  }
}

class _Entry {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _Entry(this.title, this.subtitle, this.icon, this.onTap);
}

class _RecentBook {
  final String path;
  final String title;
  final String author;
  final String pageCount;

  const _RecentBook({
    required this.path,
    required this.title,
    required this.author,
    required this.pageCount,
  });
}

class _HomeStartData {
  final int bookCount;
  final int authorCount;
  final int sectionCount;
  final List<_RecentBook> recentBooks;
  final List<LibraryEntityRow> sections;

  const _HomeStartData({
    this.bookCount = 0,
    this.authorCount = 0,
    this.sectionCount = 0,
    this.recentBooks = const [],
    this.sections = const [],
  });
}
