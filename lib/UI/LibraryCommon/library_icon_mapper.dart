part of 'library_icon.dart';

LibraryIconType? _libraryIconTypeForIcon(IconData icon) {
  if (icon == Icons.auto_stories_rounded ||
      icon == Icons.auto_stories_outlined) return LibraryIconType.quran;
  if (icon == Icons.menu_book_rounded ||
      icon == Icons.menu_book_outlined ||
      icon == Icons.menu_book ||
      icon == Icons.book ||
      icon == Icons.book_outlined ||
      icon == Icons.library_books ||
      icon == Icons.library_books_outlined) return LibraryIconType.books;
  if (icon == Icons.search_rounded ||
      icon == Icons.search ||
      icon == Icons.manage_search ||
      icon == Icons.manage_search_rounded ||
      icon == Icons.search_off ||
      icon == Icons.search_off_rounded) return LibraryIconType.search;
  if (icon == Icons.save || icon == Icons.save_outlined) {
    return LibraryIconType.save;
  }
  if (icon == Icons.settings_rounded || icon == Icons.settings) {
    return LibraryIconType.settings;
  }
  if (icon == Icons.people_outline_rounded ||
      icon == Icons.people_alt_outlined ||
      icon == Icons.person_add_alt_1_outlined ||
      icon == Icons.person ||
      icon == Icons.person_outline ||
      icon == Icons.people_outline) return LibraryIconType.authors;
  if (icon == Icons.fact_check_outlined) return LibraryIconType.control;
  if (icon == Icons.picture_as_pdf_outlined ||
      icon == Icons.picture_as_pdf) return LibraryIconType.pdf;
  if (icon == Icons.vertical_split ||
      icon == Icons.horizontal_split ||
      icon == Icons.web_asset_outlined ||
      icon == Icons.view_sidebar ||
      icon == Icons.fullscreen ||
      icon == Icons.view_list ||
      icon == Icons.view_list_outlined) return LibraryIconType.split;
  if (icon == Icons.first_page_rounded || icon == Icons.first_page) {
    return LibraryIconType.firstPage;
  }
  if (icon == Icons.last_page_rounded || icon == Icons.last_page) {
    return LibraryIconType.lastPage;
  }
  if (icon == Icons.chevron_left_rounded ||
      icon == Icons.chevron_left ||
      icon == Icons.navigate_before ||
      icon == Icons.arrow_back_rounded ||
      icon == Icons.arrow_back) return LibraryIconType.arrowLeft;
  if (icon == Icons.chevron_right_rounded ||
      icon == Icons.navigate_next ||
      icon == Icons.arrow_forward_rounded ||
      icon == Icons.arrow_forward ||
      icon == Icons.arrow_forward_ios_rounded) return LibraryIconType.arrowRight;
  if (icon == Icons.arrow_upward || icon == Icons.keyboard_arrow_up) {
    return LibraryIconType.arrowUp;
  }
  if (icon == Icons.arrow_downward || icon == Icons.keyboard_arrow_down) {
    return LibraryIconType.arrowDown;
  }
  if (icon == Icons.keyboard_arrow_down_rounded ||
      icon == Icons.expand_more) return LibraryIconType.chevronDown;
  if (icon == Icons.open_in_new) return LibraryIconType.external;
  if (icon == Icons.keyboard_return) return LibraryIconType.returnArrow;
  if (icon == Icons.close || icon == Icons.close_rounded || icon == Icons.clear) {
    return LibraryIconType.close;
  }
  if (icon == Icons.note_add_outlined) return LibraryIconType.addBook;
  if (icon == Icons.add_rounded ||
      icon == Icons.add ||
      icon == Icons.add_circle ||
      icon == Icons.add_circle_outline_rounded) {
    return LibraryIconType.zoomIn;
  }
  if (icon == Icons.remove_rounded ||
      icon == Icons.remove ||
      icon == Icons.remove_circle ||
      icon == Icons.minimize_rounded) return LibraryIconType.zoomOut;
  if (icon == Icons.copy_rounded || icon == Icons.copy) {
    return LibraryIconType.copy;
  }
  if (icon == Icons.tab_rounded) return LibraryIconType.duplicate;
  if (icon == Icons.info_outline_rounded || icon == Icons.info_outline) {
    return LibraryIconType.info;
  }
  if (icon == Icons.mode_comment_outlined ||
      icon == Icons.comment ||
      icon == Icons.comment_outlined) return LibraryIconType.comments;
  if (icon == Icons.folder_open_rounded ||
      icon == Icons.folder_open ||
      icon == Icons.folder_outlined ||
      icon == Icons.create_new_folder_outlined ||
      icon == Icons.folder_special_outlined) return LibraryIconType.folder;
  if (icon == Icons.calendar_today ||
      icon == Icons.calendar_month ||
      icon == Icons.event ||
      icon == Icons.view_timeline) {
    return LibraryIconType.calendar;
  }
  if (icon == Icons.palette) return LibraryIconType.palette;
  if (icon == Icons.font_download ||
      icon == Icons.text_fields ||
      icon == Icons.text_fields_rounded ||
      icon == Icons.font_download_outlined) return LibraryIconType.font;
  if (icon == Icons.tune_rounded ||
      icon == Icons.spellcheck_rounded ||
      icon == Icons.lightbulb_outline_rounded ||
      icon == Icons.build) return LibraryIconType.tune;
  if (icon == Icons.edit ||
      icon == Icons.edit_outlined ||
      icon == Icons.edit_note ||
      icon == Icons.edit_note_rounded) return LibraryIconType.edit;
  if (icon == Icons.drive_file_rename_outline) return LibraryIconType.rename;
  if (icon == Icons.delete ||
      icon == Icons.delete_outline ||
      icon == Icons.delete_sweep_rounded) return LibraryIconType.delete;
  if (icon == Icons.download) return LibraryIconType.download;
  if (icon == Icons.upload_file || icon == Icons.ios_share_outlined) {
    return LibraryIconType.upload;
  }
  if (icon == Icons.description || icon == Icons.description_outlined) {
    return LibraryIconType.document;
  }
  if (icon == Icons.article ||
      icon == Icons.article_outlined ||
      icon == Icons.school_outlined ||
      icon == Icons.sticky_note_2_outlined ||
      icon == Icons.title ||
      icon == Icons.format_list_numbered_rtl ||
      icon == Icons.collections_bookmark ||
      icon == Icons.chrome_reader_mode ||
      icon == Icons.chrome_reader_mode_outlined) {
    return LibraryIconType.article;
  }
  if (icon == Icons.history_edu || icon == Icons.history_edu_rounded) {
    return LibraryIconType.bookCard;
  }
  if (icon == Icons.storage_outlined) return LibraryIconType.folder;
  if (icon == Icons.album_outlined) return LibraryIconType.circle;
  if (icon == Icons.format_quote || icon == Icons.format_quote_rounded) {
    return LibraryIconType.quote;
  }
  if (icon == Icons.warning_amber_rounded ||
      icon == Icons.error ||
      icon == Icons.error_rounded ||
      icon == Icons.error_outline) return LibraryIconType.warning;
  if (icon == Icons.more_vert) return LibraryIconType.more;
  if (icon == Icons.play_arrow) return LibraryIconType.play;
  if (icon == Icons.star || icon == Icons.star_border) {
    return LibraryIconType.star;
  }
  if (icon == Icons.history || icon == Icons.access_time) {
    return LibraryIconType.history;
  }
  if (icon == Icons.cleaning_services_outlined) return LibraryIconType.clean;
  if (icon == Icons.clear_all) return LibraryIconType.clearAll;
  if (icon == Icons.undo) return LibraryIconType.undo;
  if (icon == Icons.redo) return LibraryIconType.redo;
  if (icon == Icons.push_pin || icon == Icons.push_pin_outlined) {
    return LibraryIconType.pin;
  }
  if (icon == Icons.pause || icon == Icons.vertical_align_bottom) {
    return LibraryIconType.pause;
  }
  if (icon == Icons.timer_outlined || icon == Icons.hourglass_empty) {
    return LibraryIconType.timer;
  }
  if (icon == Icons.refresh) return LibraryIconType.refresh;
  if (icon == Icons.terminal_rounded) return LibraryIconType.terminal;
  if (icon == Icons.inbox_rounded) return LibraryIconType.inbox;
  if (icon == Icons.category || icon == Icons.category_outlined) {
    return LibraryIconType.categories;
  }
  if (icon == Icons.check ||
      icon == Icons.check_circle_outline ||
      icon == Icons.check_circle ||
      icon == Icons.check_circle_rounded ||
      icon == Icons.library_add_check_rounded) {
    return LibraryIconType.check;
  }
  if (icon == Icons.circle_outlined ||
      icon == Icons.radio_button_unchecked ||
      icon == Icons.radio_button_checked) return LibraryIconType.circle;
  if (icon == Icons.remove_circle_outline ||
      icon == Icons.cancel ||
      icon == Icons.cancel_outlined ||
      icon == Icons.cancel_rounded) {
    return LibraryIconType.remove;
  }
  return null;
}

String _libraryIconFileName(LibraryIconType type) {
  switch (type) {
    case LibraryIconType.books:
      return 'books';
    case LibraryIconType.categories:
      return 'categories';
    case LibraryIconType.authors:
      return 'authors';
    case LibraryIconType.star:
      return 'star';
    case LibraryIconType.clock:
      return 'clock';
    case LibraryIconType.bookCard:
      return 'book_card';
    case LibraryIconType.addBook:
      return 'add_book';
    case LibraryIconType.bookRow:
      return 'book_row';
    case LibraryIconType.quran:
      return 'quran';
    case LibraryIconType.search:
      return 'search';
    case LibraryIconType.save:
      return 'save';
    case LibraryIconType.settings:
      return 'settings';
    case LibraryIconType.control:
      return 'control';
    case LibraryIconType.pdf:
      return 'pdf';
    case LibraryIconType.split:
      return 'split';
    case LibraryIconType.close:
      return 'close';
    case LibraryIconType.zoomIn:
      return 'zoom_in';
    case LibraryIconType.zoomOut:
      return 'zoom_out';
    case LibraryIconType.copy:
      return 'copy';
    case LibraryIconType.duplicate:
      return 'duplicate';
    case LibraryIconType.info:
      return 'info';
    case LibraryIconType.comments:
      return 'comments';
    case LibraryIconType.folder:
      return 'folder';
    case LibraryIconType.calendar:
      return 'calendar';
    case LibraryIconType.check:
      return 'check';
    case LibraryIconType.remove:
      return 'remove';
    case LibraryIconType.palette:
      return 'palette';
    case LibraryIconType.font:
      return 'font';
    case LibraryIconType.image:
      return 'image';
    case LibraryIconType.tune:
      return 'tune';
    case LibraryIconType.arrowLeft:
      return 'arrow_left';
    case LibraryIconType.arrowRight:
      return 'arrow_right';
    case LibraryIconType.arrowUp:
      return 'arrow_up';
    case LibraryIconType.arrowDown:
      return 'arrow_down';
    case LibraryIconType.firstPage:
      return 'first_page';
    case LibraryIconType.lastPage:
      return 'last_page';
    case LibraryIconType.chevronDown:
      return 'chevron_down';
    case LibraryIconType.external:
      return 'external';
    case LibraryIconType.returnArrow:
      return 'return_arrow';
    case LibraryIconType.edit:
      return 'edit';
    case LibraryIconType.delete:
      return 'delete';
    case LibraryIconType.download:
      return 'download';
    case LibraryIconType.upload:
      return 'upload';
    case LibraryIconType.document:
      return 'document';
    case LibraryIconType.article:
      return 'article';
    case LibraryIconType.quote:
      return 'quote';
    case LibraryIconType.warning:
      return 'warning';
    case LibraryIconType.more:
      return 'more';
    case LibraryIconType.play:
      return 'play';
    case LibraryIconType.history:
      return 'history';
    case LibraryIconType.clean:
      return 'clean';
    case LibraryIconType.clearAll:
      return 'clear_all';
    case LibraryIconType.circle:
      return 'circle';
    case LibraryIconType.rename:
      return 'rename';
    case LibraryIconType.undo:
      return 'undo';
    case LibraryIconType.redo:
      return 'redo';
    case LibraryIconType.pin:
      return 'pin';
    case LibraryIconType.pause:
      return 'pause';
    case LibraryIconType.timer:
      return 'timer';
    case LibraryIconType.refresh:
      return 'refresh';
    case LibraryIconType.terminal:
      return 'terminal';
    case LibraryIconType.inbox:
      return 'inbox';
  }
}
