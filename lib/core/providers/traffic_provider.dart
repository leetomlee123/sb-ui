import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/traffic_data.dart';
import 'core_provider.dart';

class TrafficState {
  final int currentUp; // B/s
  final int currentDown; // B/s
  final int totalUp; // B
  final int totalDown; // B
  final List<TrafficPoint> history; // last 90 points

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
  Timer? _totalsSyncTimer;
  final ListQueue<TrafficPoint> _historyQueue = ListQueue<TrafficPoint>(90);

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
    _totalsSyncTimer?.cancel();
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;

    // Immediately fetch ground-truth totals from kernel
    _syncTotals();

    // Periodically sync authoritative totals from core /connections API
    _totalsSyncTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _syncTotals();
    });

    _sub = client.trafficStream().listen((point) {
      if (_historyQueue.length >= 90) {
        _historyQueue.removeFirst();
      }
      _historyQueue.addLast(point);

      state = state.copyWith(
        currentUp: point.up,
        currentDown: point.down,
        history: _historyQueue.toList(growable: false),
      );
    });
  }

  Future<void> _syncTotals() async {
    final client = _ref.read(clashApiClientProvider);
    if (client == null) return;
    try {
      final data = await client.getConnectionsData();
      state = state.copyWith(
        totalDown: data.downloadTotal,
        totalUp: data.uploadTotal,
      );
    } catch (_) {}
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    _totalsSyncTimer?.cancel();
    _totalsSyncTimer = null;
    state = state.copyWith(currentUp: 0, currentDown: 0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _totalsSyncTimer?.cancel();
    super.dispose();
  }
}

final trafficProvider = StateNotifierProvider<TrafficNotifier, TrafficState>((ref) {
  return TrafficNotifier(ref);
});
