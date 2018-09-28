import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ComicData {
  ComicData({
    @required this.id,
    @required this.title,
    @required this.safeTitle,
    @required this.imageUrl,
    this.published,
    this.alt = '',
    this.link = '',
    this.news = '',
    this.transcript = '',
  });

  final int id;
  final String title, safeTitle;
  final String imageUrl;
  final String alt;
  final DateTime published;
  final String link;
  final String news;
  final String transcript;


  /// Loads comic data from the given json string.
  static ComicData _fromJson(String jsonString) {
    final data = json.decode(jsonString);

    return ComicData(
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

  /// Fetches comic data from the given url.
  static Future<ComicData> _fromUrl(String url) async {
    final jsonString = (await http.get(url)).body;
    return ComicData._fromJson(jsonString);
  }

  /// Uses the xkcd api to fetch comic data with the given id.
  static Future<ComicData> fromId(int id) async {
    return await _fromUrl('http://xkcd.com/$id/info.0.json');
  }

  /// Uses the xkcd api to fetch the latest comic.
  static Future<ComicData> latest() async {
    return await _fromUrl('http://xkcd.com/info.0.json');
  }

  String toString() {
    return 'Comic #$id';
  }
}
