import 'package:flutter/widgets.dart';
import 'package:xkcd/comic_data.dart';

/// A class that holds the comic, including the image provider.
class Comic {
  Comic({
    @required this.data,
    this.isMonochromatic,
    this.focuses
  }) {
    originalImage = Image.network(data.imageUrl).image;
  }

  final ComicData data;

  ImageProvider originalImage;
  bool isMonochromatic;
  List<Rect> focuses;
}
