import 'package:flutter/material.dart';
import 'library_design_tokens.dart';

part 'library_icon_mapper.dart';

enum LibraryIconType {
  books,
  categories,
  authors,
  star,
  clock,
  bookCard,
  addBook,
  bookRow,
  quran,
  search,
  save,
  settings,
  control,
  pdf,
  split,
  close,
  zoomIn,
  zoomOut,
  copy,
  duplicate,
  info,
  comments,
  folder,
  calendar,
  check,
  remove,
  palette,
  font,
  image,
  tune,
  arrowLeft,
  arrowRight,
  arrowUp,
  arrowDown,
  firstPage,
  lastPage,
  chevronDown,
  external,
  returnArrow,
  edit,
  delete,
  download,
  upload,
  document,
  article,
  quote,
  warning,
  more,
  play,
  history,
  clean,
  clearAll,
  circle,
  rename,
  undo,
  redo,
  pin,
  pause,
  timer,
  refresh,
  terminal,
  inbox,
}

class LibraryIcon extends StatelessWidget {
  final LibraryIconType type;
  final double size;
  final Color color;

  const LibraryIcon(
    this.type, {
    super.key,
    this.size = 24,
    this.color = LibraryDesignTokens.icon,
  });

  static Widget fromIcon(
    IconData icon, {
    Key? key,
    double size = 24,
    Color color = LibraryDesignTokens.icon,
  }) {
    final type = _libraryIconTypeForIcon(icon);
    if (type == null) return Icon(icon, key: key, size: size, color: color);
    return LibraryIcon(type, key: key, size: size, color: color);
  }

  static String assetFor(LibraryIconType type) {
    return 'assets/icons/library/${_libraryIconFileName(type)}.png';
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetFor(type),
      width: size,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    );
  }
}
