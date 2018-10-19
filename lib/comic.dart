import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// This class holds information about a single comic and is used as a means of
/// communication between the [Bloc] and the UI.
/// 
/// Over time, new information about a comic become available, i.e. through:
/// * The xkcd api returned some json.
/// * The comic image loaded.
/// * An analysis of the comic's color spectrum finished.
/// * The inverse image was calculated.
/// * AI detected comic tiles.
/// * ...
/// As this [Comic] is immutable, new [Comic]s may be created for the same
/// logical comic.
@immutable
class Comic {
  Comic._({
    @required this.id,
    this.title,
    this.safeTitle,
    this.imageUrl,
    this.published,
    this.alt = '',
    this.link = '',
    this.news = '',
    this.transcript = '',
    this.image,
    this.inversedImage,
    this.isMonochromatic,
    this.tiles
  });
  factory Comic.create(int id) => Comic._(id: id);

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
  final ui.Image image, inversedImage;
  bool get imageLoaded => image != null;

  /// Whether the image is monochromatic.
  final bool isMonochromatic;

  /// The tiles of the comic.
  final List<Rect> tiles;


  /// Fetches comic from the given url.
  Future<Comic> _fromUrl(String url) async {
    if (title != null) return this;

    final jsonString = (await http.get(url)).body;
    final data = json.decode(jsonString);

    return this.copyWith(
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

  /// Uses the xkcd api to fetch the comic with the correct [id], or the latest
  /// comic if [id] is [null],
  Future<Comic> fetchMetadata() async {
    return await _fromUrl((id == null)
      ? 'http://xkcd.com/info.0.json'
      : 'http://xkcd.com/$id/info.0.json'
    );
  }

  /// Loads the image provider. Instead of using [createLocalImageConfiguration],
  /// as is the usual procedure, for now, a dummy image configuration is used,
  /// without taking into account device pixel ratio and stuff like that.
  Future<Comic> loadImage() async {
    if (this.image != null) return this;

    ui.Image image;

    // TODO: Should we provide an asset bundle for caching? Do we need to be
    // careful about flushing of images?
    final config = ImageConfiguration(
      bundle: null,//DefaultAssetBundle.of(context),
      devicePixelRatio: 1.0,
      locale: null,
      textDirection: TextDirection.ltr,
      size: Size(100.0, 100.0),
      platform: TargetPlatform.android,
    );
    final ImageStream _imageStream = Image.network(imageUrl).image.resolve(config);
    final Function listener = (ImageInfo info, bool synchronousCall) {
      image = info.image;
      return this.copyWith(image: info.image);
    };

    // Exponentially back out.
    _imageStream.addListener(listener);
    int ticker = 1;
    while (image == null) {
      await Future.delayed(Duration(milliseconds: ticker), () {});
      ticker = min(ticker * 2, 500);
    }
    _imageStream.removeListener(listener);

    return this.copyWith(image: image);
  }


  // TODO: ---------- make this testing code useful. ----------

  void doSomething(Comic comic) {
    Image.network(comic.imageUrl).image
      .resolve(ImageConfiguration())
      .addListener((imageInfo, synchronousCall) async {
        final ui.Image image = imageInfo.image;
        final ByteData imageData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final Iterable<Color> pixels = _getImagePixels(imageData, image.width, image.height);
        print(pixels);
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

  /// Detects tiles in the comic.
  Future<Comic> detectTiles() async {
    if (this.tiles != null) return this;

    String comicWithLeadingZeroes = '$id';
    while (comicWithLeadingZeroes.length < 4)
      comicWithLeadingZeroes = '0$comicWithLeadingZeroes';

    final url = 'https://github.com/marcelgarus/xkcd/blob/master/lab/tiles/$comicWithLeadingZeroes.txt?raw=true';
    final response = await http.get(url);
    if (response.statusCode != 200) {
      return this.copyWith(tiles: []);
    }
   
    final lines = response.body.split('\n');
    final tiles = <Rect>[];

    for (final line in lines) {
      if (line.length == 0)
        continue;

      try {
        final values = line.split(' ');
        tiles.add(Rect.fromLTRB(
          int.parse(values[0]).toDouble(),
          int.parse(values[1]).toDouble(),
          int.parse(values[2]).toDouble(),
          int.parse(values[3]).toDouble()
        ));
      } catch (e) {
        print('Warning: Comic $id has a corrupt tile: $line');
        print(e);
        return this;
      }
    }

    return (tiles.length > 1) ? this.copyWith(tiles: tiles) : this;
  }


  Comic copyWith({
    int id,
    String title,
    String safeTitle,
    String imageUrl,
    DateTime published,
    String alt = '',
    String link = '',
    String news = '',
    String transcript = '',
    ui.Image image,
    ui.Image inversedImage,
    bool isMonochromatic,
    List<Rect> tiles
  }) => Comic._(
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
    tiles: tiles ?? this.tiles
  );

  @override
  bool operator== (Object other) {
    return other is Comic
      && id == other.id
      && title == other.title
      && safeTitle == other.safeTitle
      && imageUrl == other.imageUrl
      && published == other.published
      && alt == other.alt
      && link == other.link
      && news == other.news
      && transcript == other.transcript
      && (image == null) == (other.image == null)
      && (inversedImage == null) == (other.inversedImage == null)
      && isMonochromatic == other.isMonochromatic
      && tiles == other.tiles;
  }

  @override
  int get hashCode {
    return hashValues(
      id,
      title,
      safeTitle,
      imageUrl,
      published,
      alt,
      link,
      news,
      transcript,
      (image == null),
      (inversedImage == null),
      isMonochromatic,
      tiles
    );
  }

  String toString() => 'Comic #$id: ${safeTitle == null ? '<no title yet>' : '"$safeTitle"'}. Image: $image Tiles: $tiles';
}
