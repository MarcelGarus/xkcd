import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// This class holds information about a single comic and is used as a means of
/// communication between the [Bloc] and the UI.
/// 
/// Over time, new information about a comic become available, i.e. through:
/// * The xkcd api returned some json.
/// * The image loaded.
/// * An analysis of the images monochromacy finished.
/// * The inverse image was calculated.
/// * AI detected comic borders.
/// * ...
/// As this [Comic] is immutable, new [Comic]s may be created for the same
/// logical comic.
@immutable
class Comic {
  Comic({
    @required this.id,
    @required this.title,
    @required this.safeTitle,
    @required this.imageUrl,
    this.published,
    this.alt = '',
    this.link = '',
    this.news = '',
    this.transcript = '',
    this.image,
    this.inversedImage,
    this.isMonochromatic,
    this.focuses
  });

  /// The id (provided by api).
  final int id;

  /// The title and safe title (provided by api).
  final String title, safeTitle;

  /// The image url (provided by api).
  final String imageUrl;

  /// The alt text (provided by api).
  final String alt;

  /// The published date (provided by api).
  final DateTime published;

  /// A link (provided by api).
  final String link;

  /// Some news. (provided by api).
  final String news;

  /// A transcript (provided by api).
  final String transcript;


  /// The actual image.
  final ImageProvider image, inversedImage;

  /// Whether the image is monochromatic.
  final bool isMonochromatic;

  /// Focus points of the comic.
  final List<Rect> focuses;


  /// Fetches comic from the given url.
  static Future<Comic> _fromUrl(String url) async {
    final jsonString = (await http.get(url)).body;
    final data = json.decode(jsonString);

    return Comic(
      id: data['num'],
      title: data['title'],
      safeTitle: data['safe_title'],
      imageUrl: data['img'],
      alt: data['alt'],
      published: DateTime(
        int.parse(data['year']),
        int.parse(data['month']),
        int.parse(data['day'])
      ),
      link: data['link'],
      news: data['news'],
      transcript: data['transcript']
    );
  }

  /// Uses the xkcd api to fetch comic data with the given id.
  static Future<Comic> fromId(int id) async {
    return await _fromUrl('http://xkcd.com/$id/info.0.json');
  }

  /// Uses the xkcd api to fetch the latest comic.
  static Future<Comic> latest() async {
    return await _fromUrl('http://xkcd.com/info.0.json');
  }

  /// Loads the image provider.
  Comic loadImageProvider() {
    return this.copyWith(
      image: Image.network(imageUrl).image
    );
  }


  // TODO: ---------- make this testing code useful. ----------

  void doSomething(Comic comic) {
    Image.network(comic.imageUrl).image
      .resolve(ImageConfiguration())
      .addListener((imageInfo, synchronousCall) async {
        final ui.Image image = imageInfo.image;
        final ByteData imageData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final Iterable<Color> pixels = _getImagePixels(imageData, image.width, image.height);
      });
  }

  Iterable<Color> _getImagePixels(ByteData pixels, int width, int height) sync* {
    final int rowStride = width * 4;
    int rowStart = 0;
    int rowEnd = height;
    int colStart = 0;
    int colEnd = width;
    int byteCount = 0;

    for (int row = rowStart; row < rowEnd; ++row) {
      for (int col = colStart; col < colEnd; ++col) {
        final int position = row * rowStride + col * 4;
        // Convert from RGBA to ARGB.
        final int pixel = pixels.getUint32(position);
        final Color color = Color((pixel << 24) | (pixel >> 8));
        byteCount += 4;
        yield color;
      }
    }
    assert(byteCount == ((rowEnd - rowStart) * (colEnd - colStart) * 4));
  }

  // TODO: ---------- end of testing code ----------

  /// Finds focuses for the comic.
  Future<Comic> findFocuses() async {
    return await Future.delayed(Duration(seconds: 2), () {
      return this.copyWith(
        focuses: [
          Rect.fromLTWH(0.0, -5.0, 250.0, 390.0),
          Rect.fromLTWH(270.0, -5.0, 220.0, 390.0),
          Rect.fromLTWH(500.0, -5.0, 220.0, 390.0),
        ]
      );
    });
  }


  Comic copyWith({
    String id,
    String title,
    String safeTitle,
    String imageUrl,
    DateTime published,
    String alt = '',
    String link = '',
    String news = '',
    String transcript = '',
    ImageProvider image,
    ImageProvider inversedImage,
    bool isMonochromatic,
    List<Rect> focuses
  }) => Comic(
    id: id ?? this.id,
    title: title ?? this.title,
    safeTitle: safeTitle ?? this.safeTitle,
    imageUrl: imageUrl ?? this.imageUrl,
    published: published ?? this.published,
    alt: alt ?? this.alt,
    link: link ?? this.link,
    news: news ?? this.news,
    transcript: transcript ?? this.transcript,
    image: image ?? this.image,
    inversedImage: inversedImage ?? this.inversedImage,
    isMonochromatic: isMonochromatic ?? this.isMonochromatic,
    focuses: focuses ?? this.focuses
  );

  String toString() => 'Comic #$id: "$safeTitle". Focuses: $focuses';
}
