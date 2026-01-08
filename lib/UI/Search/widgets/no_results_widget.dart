import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';

/// A professional, premium "No Results Found" widget for search
/// Designed to match the Islamic Library theme with empathetic guidance
class NoResultsWidget extends StatelessWidget {
  final List<String> searchQueries;
  final VoidCallback? onNewSearch;

  const NoResultsWidget({
    Key? key,
    required this.searchQueries,
    this.onNewSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decorative Icon Container
              _buildIconContainer(),

              const SizedBox(height: 32),

              // Main Message
              Text(
                'عذراً، لم نجد نتائج',
                style: bigStyle(fontSize: 24, color: primaryColor),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Search Query Display
              if (searchQueries.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    '« ${searchQueries.join(' | ')} »',
                    style: normalStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Subtitle
              Text(
                'لم نتمكن من العثور على ما تبحث عنه في المتن أو الحواشي',
                style: normalStyle(color: Colors.grey.shade600, fontSize: 16),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Suggestions Card
              _buildSuggestionsCard(),

              const SizedBox(height: 32),

              // New Search Button
              if (onNewSearch != null) _buildNewSearchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.1),
            secondaryColor.withOpacity(0.1),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Book icon
          Icon(
            Icons.auto_stories_outlined,
            size: 50,
            color: primaryColor.withOpacity(0.7),
          ),
          // Search indicator
          Positioned(
            bottom: 25,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 22,
                color: secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsCard() {
    final suggestions = [
      _SuggestionItem(
        icon: Icons.spellcheck_rounded,
        title: 'تحقق من الإملاء',
        subtitle: 'تأكد من صحة كتابة الكلمات المطلوبة',
      ),
      _SuggestionItem(
        icon: Icons.text_fields_rounded,
        title: 'جرّب كلمات مختلفة',
        subtitle: 'استخدم مرادفات أو تعبيرات مشابهة',
      ),
      _SuggestionItem(
        icon: Icons.format_quote_rounded,
        title: 'قلّل من الكلمات',
        subtitle: 'ابحث بكلمة أو كلمتين فقط للبدء',
      ),
      _SuggestionItem(
        icon: Icons.tune_rounded,
        title: 'عدّل خيارات البحث',
        subtitle: 'جرّب تفعيل البحث الصرفي أو البحث بالمرادفات',
      ),
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'نصائح لتحسين البحث',
                style: mediumStyle(fontSize: 17, color: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...suggestions.map((suggestion) => _buildSuggestionRow(suggestion)),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(_SuggestionItem suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              suggestion.icon,
              color: primaryColor.withOpacity(0.7),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: normalStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.subtitle,
                  style: smallStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSearchButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onNewSearch,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.85)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, color: secondaryColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'بحث جديد',
                style: normalStyle(
                  color: secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionItem {
  final IconData icon;
  final String title;
  final String subtitle;

  _SuggestionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
