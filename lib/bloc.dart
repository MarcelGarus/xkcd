import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:rxdart/subjects.dart';
import 'package:xkcd/comic.dart';

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

  final comicLibrary = ComicLibrary();
  int currentId = 1234;

  final _previousSubject = BehaviorSubject<Comic>();
  final _currentSubject = BehaviorSubject<Comic>();
  final _nextSubject = BehaviorSubject<Comic>();

  Stream<Comic> get previous => _previousSubject.stream;
  Stream<Comic> get current => _currentSubject.stream;
  Stream<Comic> get next => _nextSubject.stream;

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

  BehaviorSubject _getSubjectForComic(Comic comic) {
    if (comic.id == currentId - 1) return _previousSubject;
    if (comic.id == currentId) return _currentSubject;
    if (comic.id == currentId + 1) return _nextSubject;
    return null;
  }
  void _comicUpdated(Comic comic) => _getSubjectForComic(comic)?.add(comic);

  void _updateComics() {
    //_updateComic(_previousSubject, currentId - 1).catchError(print);
    comicLibrary.loadComic(currentId, _comicUpdated).catchError(print);
    //_updateComic(_nextSubject, currentId + 1).catchError(print);
  }

  void goToNext() {
    currentId++;
    _updateComics();
  }

  void goToPrevious() {
    currentId--;
    _updateComics();
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



/// Callback if the comic got updated.
typedef ComicUpdatedCallback(Comic comic);

/// Manages all the comics from id.
class ComicLibrary {
  final comics = Map<int, Comic>();

  /// Loads the [Comic] with the given [id]. If the [id] is [null], the latest
  /// comic is loaded. Loading a comic includes:
  /// * Loading the comic data from cache, if available. Otherwise, load it
  ///   over network from the api.
  /// * Loading the focuses.
  Future<void> loadComic(int id, ComicUpdatedCallback callback) async {
    Comic comic;
    
    comic = comics[id] ?? await (id == null ? Comic.latest() : Comic.fromId(id)).catchError(print);
    _updateComic(comic, callback);

    comic = await comic.loadImage();
    _updateComic(comic, callback);

    comic = await comic.findFocuses().catchError(print);
    _updateComic(comic, callback);
  }

  /// Saves the comic in the cache and calls callback.
  void _updateComic(Comic comic, ComicUpdatedCallback callback) {
    comics[comic.id] = comic;
    callback(comic);
  }
}
