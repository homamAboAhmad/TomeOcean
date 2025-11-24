import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Models/Author.dart';

/// Authors table panel widget
class AuthorsTablePanel extends StatelessWidget {
  final List<Author> authors;
  final Set<String> selectedAuthorIds;
  final Function(String) onAuthorToggled;
  final Function() onSelectAllAuthors;
  final Map<String, int> authorBookCounts;
  final Map<String, String> authorDeathYears;
  final bool isLoading;

  const AuthorsTablePanel({
    Key? key,
    required this.authors,
    required this.selectedAuthorIds,
    required this.onAuthorToggled,
    required this.onSelectAllAuthors,
    required this.authorBookCounts,
    required this.authorDeathYears,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (authors.isEmpty) {
      return Center(
        child: Text(
          'لا توجد مؤلفين',
          style: normalStyle(color: Colors.grey),
        ),
      );
    }
    
    return Column(
      children: [
        // Table header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              SizedBox(width: 40), // Checkbox column
              Expanded(
                flex: 2,
                child: Text('الكتب', style: mediumStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text('الوفاة', style: mediumStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 4,
                child: Text('المؤلف', style: mediumStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        // Select all checkbox
        CheckboxListTile(
          title: Text('كل المؤلفين', style: normalStyle()),
          value: authors.isNotEmpty &&
              authors.every((author) => selectedAuthorIds.contains(author.id)),
          onChanged: (val) => onSelectAllAuthors(),
        ),
        Divider(height: 1),
        // Authors list
        Expanded(
          child: ListView.builder(
            itemCount: authors.length,
            itemBuilder: (context, index) {
              final author = authors[index];
              final bookCount = authorBookCounts[author.id] ?? 0;
              final deathYear = authorDeathYears[author.id] ?? '';
              final isSelected = selectedAuthorIds.contains(author.id);
              
              return InkWell(
                onTap: () => onAuthorToggled(author.id),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) => onAuthorToggled(author.id),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          bookCount.toString(),
                          style: normalStyle(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          deathYear.isNotEmpty ? '$deathYear م' : '-',
                          style: normalStyle(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          author.name,
                          style: normalStyle(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

