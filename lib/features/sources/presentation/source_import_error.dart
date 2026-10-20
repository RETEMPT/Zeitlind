import 'package:zeitlind/utils/translations.dart';

String sourceImportError(Object error) =>
    (error is FormatException ? error.message : error.toString()).tl;
