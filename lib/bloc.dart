import 'dart:async';
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


  Future<ComicData> _getComic(int id) async {
    final comic = comics[id] ?? await ComicData.fromId(id);
    comics[id] = comic;
    return comic;
  }

  void _updateComics() {
    _getComic(currentId - 1).then(_previousSubject.add).catchError(print);
    _getComic(currentId).then(_currentSubject.add).catchError(print);
    _getComic(currentId + 1).then(_nextSubject.add).catchError(print);
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
