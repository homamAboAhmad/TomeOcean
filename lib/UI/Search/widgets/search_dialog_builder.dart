import 'package:flutter/material.dart';
import 'package:golden_shamela/Styles/AppResourses.dart';
import 'package:golden_shamela/Styles/TextSyles.dart';
import 'package:golden_shamela/UI/Search/widgets/search_options_panel.dart';
import 'package:golden_shamela/UI/Search/widgets/sidebar_navigation.dart';
import 'package:golden_shamela/UI/Search/widgets/bottom_bar.dart';
import 'package:golden_shamela/UI/Search/widgets/results_view.dart';
import 'package:golden_shamela/UI/Search/widgets/middle_panel_content.dart';

/// Helper class to build search dialog UI components
class SearchDialogBuilder {
  /// Build the dialog header
  static Widget buildHeader(VoidCallback onClose) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'البحث',
            style: bigStyle(color: secondaryColor, fontSize: 18),
          ),
          IconButton(
            icon: Icon(Icons.close, color: secondaryColor, size: 20),
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  /// Build the main content area with three panels
  static Widget buildContent({
    required String selectedTab,
    required Function(String) onTabSelected,
    required Widget searchOptionsPanel,
    required Widget middlePanelContent,
  }) {
    return Expanded(
      child: Row(
        children: [
          // Sidebar navigation (left side)
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: SidebarNavigation(
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
            ),
          ),
          
          // Middle panel - Content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: middlePanelContent,
            ),
          ),
          
          // Search options panel (right side)
          Container(
            width: 350,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: searchOptionsPanel,
          ),
        ],
      ),
    );
  }

  /// Build results panel
  static Widget? buildResultsPanel({
    required List<Map<String, dynamic>> results,
    required int totalCount,
    required Function(String, int) onResultTapped,
    required VoidCallback onClose,
    required List<String> searchQueries,
    required bool morphologicalSearch,
  }) {
    if (results.isEmpty) return null;
    
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SearchResultsView(
        results: results,
        totalCount: totalCount,
        onResultTapped: onResultTapped,
        onClose: onClose,
        searchQueries: searchQueries,
        morphologicalSearch: morphologicalSearch,
      ),
    );
  }
}



