import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:rxdart/subjects.dart';
import 'package:xkcd/comic.dart';

/// BLoC.
class Bloc {
  /// Using this method, any widget in the tree below a BlocHolder can get
  /// access to the bloc.
  static Bloc of(BuildContext context) {
    final BlocHolder inherited = context
        .ancestorWidgetOfExactType(BlocHolder);
    return inherited?.bloc;
  }

  ComicLibrary comicLibrary;
  int currentId = 1234;
  int get previousId => currentId - 1;
  int get nextId => currentId + 1;

  final _previousSubject = BehaviorSubject<Comic>();
  final _currentSubject = BehaviorSubject<Comic>();
  final _nextSubject = BehaviorSubject<Comic>();
  Stream<Comic> get previous => _previousSubject.stream;
  Stream<Comic> get current => _currentSubject.stream;
  Stream<Comic> get next => _nextSubject.stream;


  Future<void> _initialize() async {
    print('Initializing the BLoC.');
    comicLibrary = ComicLibrary(_onComicUpdated);
    _onCurrentComicChanged();
  }

  void dispose() {
    _previousSubject.close();
    _currentSubject.close();
    _nextSubject.close();
  }

  void _onComicUpdated(Comic comic) {
    final BehaviorSubject subject =
      comic.id == previousId ? _previousSubject :
      comic.id == currentId ? _currentSubject :
      comic.id == nextId ? _nextSubject : null;
    subject?.add(comic);
  }

  void _onCurrentComicChanged() {
    comicLibrary.setInterest(previousId, 0.5);
    comicLibrary.setInterest(currentId, 1.0);
    comicLibrary.setInterest(previousId, 0.5);
    comicLibrary.flush();
  }

  void goToNext() {
    currentId++;
    _onCurrentComicChanged();
  }

  void goToPrevious() {
    currentId--;
    _onCurrentComicChanged();
  }
}

class BlocProvider extends StatefulWidget {
  BlocProvider({ @required this.child });
  
  final Widget child;

  _BlocProviderState createState() => _BlocProviderState();
}

class _BlocProviderState extends State<BlocProvider> {
  final Bloc bloc = Bloc();

  void initState() {
    super.initState();
    bloc._initialize().catchError((e) {
      print('An error occurred when initializing the BloC: $e');
    });
  }

  @override
  void dispose() {
    bloc.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) => BlocHolder(bloc, widget.child);
}

class BlocHolder extends StatelessWidget {
  BlocHolder(this.bloc, this.child);
  
  final Bloc bloc;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}






/// Callback if the comic got updated.
typedef ComicUpdatedCallback(Comic comic);

/// Manages all the comics from id.
class ComicLibrary {
  ComicLibrary(this.callback) {
    Future(_work);
  }

  final comics = Map<int, Comic>();
  final interests = Map<int, double>();
  ComicUpdatedCallback callback;

  void setInterest(int id, double interest) {
    interests[id] = interest;
    if (!comics.containsKey(id))
      comics[id] = Comic.create(id);
  }

  void flush() {
    for (final comic in comics.values)
      callback(comic);
  }

  Future<void> _work() async {
    print('Worker running.');

    for (final entry in interests.entries) {
      if (entry.value > 0.5)
        await loadComic(entry.key, (comic) {
          assert(comic != null);
          comics[comic.id] = comic;
          callback(comic);
        });
    }

    Future.delayed(Duration(seconds: 2), _work);
  }

  /// Loads the [Comic] with the given [id]. If the [id] is [null], the latest
  /// comic is loaded. Loading a comic includes:
  /// * Load the comic from cache, if possible. Otherwise, create a new one.
  /// * Load metadata over network from the json api.
  /// * Load the image.
  /// * Load the focuses.
  Future<void> loadComic(int id, ComicUpdatedCallback callback) async {
    assert(id != null);

    Comic comic = comics[id] ?? Comic.create(id);
    callback(comic);

    comic = await comic.fetchMetadata().catchError(print);
    callback(comic);

    comic = await comic.loadImage().catchError(print);
    callback(comic);

    comic = await comic.findFocuses().catchError(print);
    callback(comic);
  }
}
