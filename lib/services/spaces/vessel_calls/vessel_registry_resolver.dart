import '../../../domain/models/vessel_registry.dart';

enum VesselClassificationSource { vessel, line, unknown }

final class VesselRegistryResolution {
  const VesselRegistryResolution({
    required this.workType,
    required this.source,
    this.vessel,
    this.line,
  });

  final VesselWorkType workType;
  final VesselClassificationSource source;

  final VesselRegistryEntry? vessel;
  final VesselLineRegistryEntry? line;

  bool get hasKnownWorkType => workType != VesselWorkType.unknown;
}

final class VesselRegistryResolver {
  const VesselRegistryResolver();

  VesselRegistryResolution resolve({
    required String shipName,
    required String lineName,
    required Iterable<VesselRegistryEntry> vessels,
    required Iterable<VesselLineRegistryEntry> lines,
  }) {
    final normalizedShipName = normalizeVesselRegistryText(shipName);
    final normalizedLineName = normalizeVesselRegistryText(lineName);

    final line = _findLine(
      normalizedLineName: normalizedLineName,
      lines: lines,
    );

    final vessel = _findVessel(
      normalizedShipName: normalizedShipName,
      lineId: line?.lineId,
      vessels: vessels,
    );

    if (vessel != null && vessel.workType != VesselWorkType.unknown) {
      return VesselRegistryResolution(
        workType: vessel.workType,
        source: VesselClassificationSource.vessel,
        vessel: vessel,
        line: line,
      );
    }

    if (line != null && line.defaultWorkType != VesselWorkType.unknown) {
      return VesselRegistryResolution(
        workType: line.defaultWorkType,
        source: VesselClassificationSource.line,
        vessel: vessel,
        line: line,
      );
    }

    return VesselRegistryResolution(
      workType: VesselWorkType.unknown,
      source: VesselClassificationSource.unknown,
      vessel: vessel,
      line: line,
    );
  }

  VesselLineRegistryEntry? _findLine({
    required String normalizedLineName,
    required Iterable<VesselLineRegistryEntry> lines,
  }) {
    if (normalizedLineName.isEmpty) {
      return null;
    }

    for (final line in lines) {
      if (line.normalizedName == normalizedLineName) {
        return line;
      }
    }

    return null;
  }

  VesselRegistryEntry? _findVessel({
    required String normalizedShipName,
    required String? lineId,
    required Iterable<VesselRegistryEntry> vessels,
  }) {
    if (normalizedShipName.isEmpty) {
      return null;
    }

    VesselRegistryEntry? nameMatch;

    for (final vessel in vessels) {
      if (vessel.normalizedName != normalizedShipName) {
        continue;
      }

      nameMatch ??= vessel;

      if (lineId != null && vessel.lineId == lineId) {
        return vessel;
      }
    }

    return nameMatch;
  }
}
