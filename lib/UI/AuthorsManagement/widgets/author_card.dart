// lib/UI/AuthorsManagement/widgets/author_card.dart
import 'package:flutter/material.dart';
import '../../../Models/Author.dart';
import '../../../Styles/TextSyles.dart';
import '../../LibraryCommon/library_icon.dart';

/// Widget for displaying author card
class AuthorCard extends StatelessWidget {
  final Author author;
  final int bookCount;
  final VoidCallback onTap;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AuthorCard({
    Key? key,
    required this.author,
    required this.bookCount,
    required this.onTap,
    required this.onViewDetails,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    textDirection: TextDirection.rtl,
                    children: [
                      Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                author.name,
                                style: normalStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (bookCount > 0) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  '$bookCount كتاب',
                                  style: normalStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (author.deathYear != null && author.deathYear!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            'تاريخ الوفاة (هجري): ${author.deathYear!}',
                            style: normalStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                      if (author.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            author.description,
                            style: normalStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w400,
                            ).copyWith(height: 1.5),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Actions Menu
                PopupMenuButton<String>(
                  icon: LibraryIcon.fromIcon(
                    Icons.more_vert,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'details':
                        onViewDetails();
                        break;
                      case 'edit':
                        onEdit();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          LibraryIcon.fromIcon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'التفاصيل',
                            style: normalStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          LibraryIcon.fromIcon(
                            Icons.edit,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'تعديل',
                            style: normalStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          LibraryIcon.fromIcon(
                            Icons.delete,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'حذف',
                            style: normalStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

