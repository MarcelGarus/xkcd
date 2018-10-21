import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:rxdart/subjects.dart';
import 'package:xkcd/comic.dart';

/// The current status of zooming.
/// 
/// If [enabled] is [false], there is no zoom and the comic is centered. In
/// this case, the [tile] property is ignored.
/// If [enabled] is [true], the zoom mode is active. If [tile] is [null], the
/// user zoomed to some ambiguous location. Otherwise, [tile] is the index of
/// the current tile.
@immutable
class ZoomStatus {
  const ZoomStatus(this.enabled, this.tile) : assert(enabled != null);
  static final seed = ZoomStatus(false, null);

  final bool enabled;
  final int tile;

  bool operator ==(Object status) {
    return status is ZoomStatus
      && enabled == status.enabled
      && tile == status.tile;
  }

  String toString() => (!enabled) ? '<disabled>' : '<enabled: $tile>';
}



/// BLoC.
class Bloc {
  /// Using this method, any widget in the tree below a BlocHolder can get
  /// access to the bloc.
  static Bloc of(BuildContext context) {
    final BlocHolder inherited = context.ancestorWidgetOfExactType(BlocHolder);
    return inherited?.bloc;
  }

  /// A library that takes care of doing work on the comics. It provides us
  /// with everything we need.
  ComicLibrary _comicLibrary;

  /// The ID of the current comic. Setting it updates the comic interests in
  /// the comic library.
  int _current;
  int get _previous => _current - 1;
  int get _next => _current + 1;

  /// Whether the zoom mode is active as well as the currently zoomed-on tile.
  bool _zoomEnabled = false;
  int _zoomTile;

  // The streams for communicating with the UI.
  final _previousSubject = BehaviorSubject<Comic>();
  final _currentSubject = BehaviorSubject<Comic>();
  final _nextSubject = BehaviorSubject<Comic>();
  final _zoomModeSubject = BehaviorSubject<ZoomStatus>(
    seedValue: ZoomStatus.seed
  );
  Stream<Comic> get previous => _previousSubject.stream.distinct();
  Stream<Comic> get current => _currentSubject.stream.distinct();
  Stream<Comic> get next => _nextSubject.stream.distinct();
  Stream<ZoomStatus> get zoomStatus => _zoomModeSubject.stream; // TODO make distinct


  /// Initializes the BLoC.
  void _initialize() {
    print('Initializing the BLoC.');
    _comicLibrary = ComicLibrary((Comic comic) {
      (comic.id == _previous ? _previousSubject :
       comic.id == _current ? _currentSubject :
       comic.id == _next ? _nextSubject : null
      )?.add(comic);
    });

    setComicState(() {
      _current = 6;
    });
  }

  /// Disposes all the streams.
  void dispose() {
    _previousSubject.close();
    _currentSubject.close();
    _nextSubject.close();
    _zoomModeSubject.close();
  }

  /// Calls the given function, then updates the comic library's interests to
  /// match the current comic.
  void setComicState(Function function) {
    function();
    print('Setting comic library interests around $_current');
    _comicLibrary.setInterest(_previous, 0.5);
    _comicLibrary.setInterest(_current, 1.0);
    _comicLibrary.setInterest(_next, 0.5);
    _comicLibrary.flush();
  }

  /// Calls the given function, then adds the new zoom mode to the stream.
  void setZoomState(Function function) {
    function();
    _zoomModeSubject.add(ZoomStatus(_zoomEnabled, _zoomTile));
  }

  // Go the next and previous comic.
  void goToNextComic() => setComicState(() => _current++);
  void goToPreviousComic() => setComicState(() => _current--);

  // Enter and exit zoom.
  void enterZoom({ bool focusOnFirstTile = false }) => setZoomState(() {
    _zoomEnabled = true;
    _zoomTile = focusOnFirstTile ? 0 : null;
  });
  void exitZoom() => setZoomState(() {
    _zoomEnabled = false;
    _zoomTile = null;
  });

  // Zoom in on a comic tile.
  void zoomToNextTile() => setZoomState(() => _zoomTile++);
  void zoomToPreviousTile() => setZoomState(() => _zoomTile--);
  void zoomToTile(int i) => setZoomState(() => _zoomTile = i);
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
    bloc._initialize();
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
    Timer.periodic(Duration(seconds: 10), (Timer t) => _work());
    Future(_work);
  }

  final comics = Map<int, Comic>();
  final interests = Map<int, double>();
  ComicUpdatedCallback callback;

  void setInterest(int id, double interest) {
    interests[id] = interest;
    if (!comics.containsKey(id)) {
      comics[id] = Comic.create(id);
      callback(comics[id]);
    }
  }

  void flush() {
    for (final comic in comics.values)
      callback(comic);
  }

  Future<void> _work() async {
    print('Worker running.');

    for (final entry in interests.entries.toList()) {
      await loadComic(entry.key, (comic) {
        assert(comic != null);
        comics[comic.id] = comic;
        callback(comic);
      });
    }
  }

  /// Loads the [Comic] with the given [id]. If the [id] is [null], the latest
  /// comic is loaded. Loading a comic includes:
  /// * Load the comic from cache, if possible. Otherwise, create a new one.
  /// * Load metadata over network from the json api.
  /// * Load the image.
  /// * Load the focuses.
  Future<void> loadComic(int id, ComicUpdatedCallback callback) async {
    assert(id != null);

    if (interests[id] == 0.0) return;
    Comic comic = comics[id] ?? Comic.create(id);
    callback(comic);

    if (interests[id] < 0.2) return;
    comic = await comic.getMetadata().catchError(print);
    callback(comic);

    if (interests[id] < 0.5) return;
    comic = await comic.downloadImage().catchError(print);
    callback(comic);

    comic = await comic.detectTiles().catchError(print);
    callback(comic);
  }
}
