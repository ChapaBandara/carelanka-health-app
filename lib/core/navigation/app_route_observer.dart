import 'package:flutter/material.dart';

/// Observes route visibility so auth screens can re-check session on back navigation.
final RouteObserver<ModalRoute<void>> authRouteObserver = RouteObserver<ModalRoute<void>>();
