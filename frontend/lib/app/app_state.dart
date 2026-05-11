import 'package:flutter/material.dart';

class MyAppState extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  // Persist the PageController here
  final PageController pageController;

  MyAppState() : pageController = PageController(initialPage: 0);

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
