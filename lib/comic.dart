import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    this.tiles
  }) : assert(id != null);
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
  final File image;
  bool get imageLoaded => image != null;

  /// The tiles of the comic.
  final List<Rect> tiles;


  /// Uses either the cache or the xkcd api to get the comic's metadata.
  /// May throw.
  Future<Comic> getMetadata() async {
    if (title != null) return this;

    final String cachePath = (await getTemporaryDirectory()).path;
    final File cache = File('$cachePath/metadata$id.txt');
    String jsonString;

    if (await cache.exists()) {
      print('Getting comic $id\'s metadata from cache.');
      jsonString = await cache.readAsString();
    } else {
      print('Fetching comic $id\'s metadata from the web.');
      final url = 'http://xkcd.com/$id/info.0.json';
      final response = await http.get(url);

      if (response.statusCode != 200)
        throw UnsupportedError('Request to $url failed with status code ${response.statusCode}.');

      jsonString = response.body;
      cache.writeAsString(jsonString);
    }

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


  /// Downloads the image to the cache, if it's not already in there.
  Future<Comic> downloadImage() async {
    if (this.image != null) return this;

    final cachePath = (await getTemporaryDirectory()).path;
    final File cache = File(
      '$cachePath/comic$id.${imageUrl.substring(imageUrl.lastIndexOf('.') + 1)}'
    );

    if (await cache.exists()) {
      print('Getting comic $id from cache.');
    } else {
      print('Downloading comic $id from the internet.');
      final response = await http.get(imageUrl);

      if (response.statusCode != 200)
        throw UnsupportedError('Request to $imageUrl failed with status code ${response.statusCode}.');

      final bytes = response.bodyBytes;
      await cache.writeAsBytes(bytes);
    }
    
    return this.copyWith(image: cache);
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

    final String cachePath = (await getTemporaryDirectory()).path;
    final File cache = File('$cachePath/tiles$id.txt');
    String tileData;

    if (await cache.exists()) {
      print('Getting comic $id\'s tiles from cache.');
      tileData = await cache.readAsString();
    } else {
      print('Fetching comic $id\'s tiles from the web.');
      
      String comicWithLeadingZeroes = '$id';
      while (comicWithLeadingZeroes.length < 4)
        comicWithLeadingZeroes = '0$comicWithLeadingZeroes';

      final url = 'https://github.com/marcelgarus/xkcd/blob/master/lab/tiles/$comicWithLeadingZeroes.txt?raw=true';
      final response = await http.get(url);

      if (response.statusCode != 200)
        throw UnsupportedError('Request to $url failed with status code ${response.statusCode}.');

      tileData = response.body;
      cache.writeAsString(tileData);
    }

    final lines = tileData.split('\n');
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
    File image,
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
      && image.path == other.image.path
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
      image.path,
      tiles
    );
  }

  String toString() => 'Comic #$id: ${safeTitle == null ? '<no title yet>' : '"$safeTitle"'}. Image: $image Tiles: $tiles';
}
