enum ReadingPreset {
  standard('Standard', 'galleryLeftToRight'),
  manga('Manga', 'galleryRightToLeft'),
  webtoon('Webtoon', 'continuousTopToBottom');

  const ReadingPreset(this.label, this.mode);
  final String label;
  final String mode;

  Map<String, dynamic> get settings => {
    'readerMode': mode,
    'readerScreenPicNumberForLandscape': 1,
    'readerScreenPicNumberForPortrait': 1,
  };
}
