import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class UserPositionData extends Equatable {
  final LatLng position;
  final DateTime timestamp;
  final bool alreadySent;

  const UserPositionData({required this.position, required this.timestamp, required this.alreadySent});

  @override
  List<Object> get props => [position, timestamp, alreadySent];
}
