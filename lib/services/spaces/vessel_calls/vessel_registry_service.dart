import '../../../domain/models/vessel_registry.dart';
import 'vessel_registry_firestore_gateway.dart';
import 'vessel_registry_resolver.dart';
import 'vessel_registry_seed.dart';

final class VesselRegistrySnapshot {
  const VesselRegistrySnapshot({required this.lines, required this.vessels});

  final List<VesselLineRegistryEntry> lines;
  final List<VesselRegistryEntry> vessels;

  VesselRegistryResolution resolve({
    required String shipName,
    required String lineName,
  }) {
    const resolver = VesselRegistryResolver();

    return resolver.resolve(
      shipName: shipName,
      lineName: lineName,
      vessels: vessels,
      lines: lines,
    );
  }
}

final class VesselRegistryService {
  VesselRegistryService({required this.gateway});

  factory VesselRegistryService.firebase() {
    return VesselRegistryService(
      gateway: VesselRegistryFirestoreGateway.firebase(),
    );
  }

  final VesselRegistryFirestoreGateway gateway;

  Future<VesselRegistrySnapshot> load() async {
    try {
      final results = await Future.wait([
        gateway.loadLines(),
        gateway.loadVessels(),
      ]);

      final remoteLines = results[0] as List<VesselLineRegistryEntry>;

      final remoteVessels = results[1] as List<VesselRegistryEntry>;

      final linesById = <String, VesselLineRegistryEntry>{
        for (final line in vesselLineRegistrySeed) line.lineId: line,
      };

      for (final line in remoteLines) {
        linesById[line.lineId] = line;
      }

      return VesselRegistrySnapshot(
        lines: List.unmodifiable(linesById.values),
        vessels: List.unmodifiable(remoteVessels),
      );
    } catch (_) {
      return VesselRegistrySnapshot(
        lines: List.unmodifiable(vesselLineRegistrySeed),
        vessels: const <VesselRegistryEntry>[],
      );
    }
  }
}
