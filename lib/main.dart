import 'package:flutter/material.dart';
import 'package:xkcd/bloc.dart';
import 'package:xkcd/comics_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      child: MaterialApp(
        title: 'xkcd',
        theme: ThemeData(
          primarySwatch: Colors.teal,
        ),
        home: MyHomePage(),
      )
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ComicsScreen(),
    );
  }
}

