import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/traffic_data.dart';
import 'core_provider.dart';

class TrafficState {
  final int currentUp; // B/s
  final int currentDown; // B/s
  final int totalUp; // B
  final int totalDown; // B
  final List<TrafficPoint> history; // last 30 points

  TrafficState({
    this.currentUp = 0,
    this.currentDown = 0,
    this.totalUp = 0,
    this.totalDown = 0,
    this.history = const [],
  });

  TrafficState copyWith({
    int? currentUp,
    int? currentDown,
    int? totalUp,
    int? totalDown,
    List<TrafficPoint>? history,
  }) {
    return TrafficState(
      currentUp: currentUp ?? this.currentUp,
      currentDown: currentDown ?? this.currentDown,
      totalUp: totalUp ?? this.totalUp,
      totalDown: totalDown ?? this.totalDown,
      history: history ?? this.history,
    );
  }
}

class TrafficNotifier extends StateNotifier<TrafficState> {
  final Ref _ref;
  StreamSubscription<TrafficPoint>? _sub;

  TrafficNotifier(this._ref) : super(TrafficState()) {
    _ref.listen<CoreState>(coreProvider, (previous, next) {
      if (next.isRunning && (previous == null || !previous.isRunning)) {
        _startListening();
      } else if (!next.isRunning) {
        _stopListening();
      }
    });
  }

  void _startListening() {
    _sub?.cancel();
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    _sub = client.trafficStream().listen((point) {
      final updatedHistory = [...state.history, point];
      if (updatedHistory.length > 90) {
        updatedHistory.removeAt(0);
      }

      state = state.copyWith(
        currentUp: point.up,
        currentDown: point.down,
        totalUp: state.totalUp + point.up,
        totalDown: state.totalDown + point.down,
        history: updatedHistory,
      );
    });
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(currentUp: 0, currentDown: 0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final trafficProvider = StateNotifierProvider<TrafficNotifier, TrafficState>((ref) {
  return TrafficNotifier(ref);
});
