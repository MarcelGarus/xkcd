import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:rxdart/subjects.dart';
import 'package:xkcd/comic_data.dart';

class Bloc {
  Bloc() {
    _initialize().catchError((e) {
      print('An error occurred when initializing the BloC: $e');
    });
  }

  /// Using this method, any widget in the tree below a BlocProvider can get
  /// access to the bloc.
  static Bloc of(BuildContext context) {
    final BlocProvider inherited = context
        .ancestorWidgetOfExactType(BlocProvider);
    return inherited?.bloc;
  }

  //Stream<Localizer> get localizer => localeBloc.localizerSubject.stream.distinct();
  //Stream<AccountState> get account => accountBloc.accountSubject.stream;

  final _previousSubject = BehaviorSubject<ComicData>();
  final _currentSubject = BehaviorSubject<ComicData>();
  final _nextSubject = BehaviorSubject<ComicData>();

  int currentId = 123;
  final comics = Map<int, ComicData>();

  Stream<ComicData> get previous => _previousSubject.stream;
  Stream<ComicData> get current => _currentSubject.stream;
  Stream<ComicData> get next => _nextSubject.stream;

  Future<void> _initialize() async {
    print('Initializing the BLoC.');
    previous.listen((data) => print('Previous comic is $data'));
    current.listen((data) => print('Current comic is $data'));
    next.listen((data) => print('Next comic is $data'));
    _updateComics();
  }

  void dispose() {
    _previousSubject.close();
    _currentSubject.close();
    _nextSubject.close();
  }


  Future<void> _updateComic(BehaviorSubject subject, int id) async {
    final cachedComic = comics[id];
    subject.add(cachedComic);

    if (cachedComic == null) {
      final comic = await ComicData.fromId(id);
      comics[id] = comic;
      subject.add(comic);
    }
  }

  void _updateComics() {
    _updateComic(_previousSubject, currentId - 1).catchError(print);
    _updateComic(_currentSubject, currentId).catchError(print);
    _updateComic(_nextSubject, currentId + 1).catchError(print);
  }

  void goToNext() {
    currentId++;
    _updateComics();
  }

  void goToPrevious() {
    currentId--;
    _updateComics();
  }

  void doSomething(ComicData comic) {
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
}

class BlocProvider extends StatelessWidget {
  BlocProvider({ @required this.bloc, @required this.child }) :
      assert(bloc != null),
      assert(child != null);
  
  final Widget child;
  final Bloc bloc;

  @override
  Widget build(BuildContext context) => child;
}
