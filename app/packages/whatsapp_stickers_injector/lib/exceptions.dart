class WhatsappStickersException implements Exception {
  final String? cause;

  WhatsappStickersException(this.cause);

  @override
  String toString() => 'Unknown error: $cause';
}

class WhatsappStickersFileNotFoundException extends WhatsappStickersException {
  static const String code = 'FILE_NOT_FOUND';

  WhatsappStickersFileNotFoundException(String? cause) : super(cause);

  @override
  String toString() => 'File not found';
}

class WhatsappStickersNumOutsideAllowableRangeException
    extends WhatsappStickersException {
  static const String code = 'OUTSIDE_ALLOWABLE_RANGE';

  WhatsappStickersNumOutsideAllowableRangeException(String? cause) : super(cause);

  @override
  String toString() => 'Outside allowable range';
}

class WhatsappStickersUnsupportedImageFormatException
    extends WhatsappStickersException {
  static const String code = 'UNSUPPORTED_IMAGE_FORMAT';

  WhatsappStickersUnsupportedImageFormatException(String? cause) : super(cause);

  @override
  String toString() => 'Unsupported image format';
}

class WhatsappStickersImageTooBigException extends WhatsappStickersException {
  static const String code = 'IMAGE_TOO_BIG';

  WhatsappStickersImageTooBigException(String? cause) : super(cause);

  @override
  String toString() => 'Image too big';
}

class WhatsappStickersIncorrectImageSizeException
    extends WhatsappStickersException {
  static const String code = 'INCORRECT_IMAGE_SIZE';

  WhatsappStickersIncorrectImageSizeException(String? cause) : super(cause);

  @override
  String toString() => 'Incorrect image size';
}

class WhatsappStickersAnimatedImagesNotSupportedException
    extends WhatsappStickersException {
  static const String code = 'ANIMATED_IMAGES_NOT_SUPPORTED';

  WhatsappStickersAnimatedImagesNotSupportedException(String? cause) : super(cause);

  @override
  String toString() => 'Animated images not supported';
}

class WhatsappStickersTooManyEmojisException extends WhatsappStickersException {
  static const String code = 'TOO_MANY_EMOJIS';

  WhatsappStickersTooManyEmojisException(String? cause) : super(cause);

  @override
  String toString() => 'Too many emojis';
}

class WhatsappStickersEmptyStringException extends WhatsappStickersException {
  static const String code = 'EMPTY_STRING';

  WhatsappStickersEmptyStringException(String? cause) : super(cause);

  @override
  String toString() => 'Contain empty string';
}

class WhatsappStickersStringTooLongException extends WhatsappStickersException {
  static const String code = 'STRING_TOO_LONG';

  WhatsappStickersStringTooLongException(String? cause) : super(cause);

  @override
  String toString() => 'String too long';
}

class WhatsappStickersAlreadyAddedException extends WhatsappStickersException {
  static const String code = 'ALREADY_ADDED';

  WhatsappStickersAlreadyAddedException(String? cause) : super(cause);

  @override
  String toString() => 'Stickers already added';
}

class WhatsappStickersCancelledException extends WhatsappStickersException {
  static const String code = 'CANCELLED';

  WhatsappStickersCancelledException(String? cause) : super(cause);

  @override
  String toString() => 'Cancelled';
}
