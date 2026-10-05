import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/models/vessel_registry.dart';
import 'vessel_registry_firestore_mapper.dart';

typedef VesselRegistryCollectionReader =
    Future<List<VesselRegistryDocument>> Function();

typedef VesselRegistryDocumentWriter =
    Future<void> Function({
      required String documentId,
      required Map<String, dynamic> data,
    });

typedef VesselRegistryPhotoWriter =
    Future<void> Function({
      required String documentId,
      required String thumbnailPath,
      required String fullPath,
      required int version,
      required String updatedBy,
    });

final class VesselRegistryDocument {
  const VesselRegistryDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

final class VesselRegistryFirestoreGateway {
  const VesselRegistryFirestoreGateway({
    required VesselRegistryCollectionReader lineReader,
    required VesselRegistryCollectionReader vesselReader,
    required VesselRegistryDocumentWriter lineWriter,
    required VesselRegistryDocumentWriter vesselWriter,
    required VesselRegistryPhotoWriter vesselPhotoWriter,
  }) : _readLines = lineReader,
       _readVessels = vesselReader,
       _writeLine = lineWriter,
       _writeVessel = vesselWriter,
       _writeVesselPhoto = vesselPhotoWriter;

  factory VesselRegistryFirestoreGateway.firebase({
    FirebaseFirestore? firestore,
  }) {
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;

    final moduleDocument = resolvedFirestore
        .collection('spaces')
        .doc('vesselCalls');

    final lineCollection = moduleDocument.collection('lineRegistry');

    final vesselCollection = moduleDocument.collection('vesselRegistry');

    return VesselRegistryFirestoreGateway(
      lineReader: () async {
        final snapshot = await lineCollection.get();

        return snapshot.docs
            .map(
              (document) => VesselRegistryDocument(
                id: document.id,
                data: document.data(),
              ),
            )
            .toList(growable: false);
      },
      vesselReader: () async {
        final snapshot = await vesselCollection.get();

        return snapshot.docs
            .map(
              (document) => VesselRegistryDocument(
                id: document.id,
                data: document.data(),
              ),
            )
            .toList(growable: false);
      },
      lineWriter:
          ({required String documentId, required Map<String, dynamic> data}) {
            return lineCollection.doc(documentId).set(<String, dynamic>{
              ...data,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          },
      vesselWriter:
          ({required String documentId, required Map<String, dynamic> data}) {
            return vesselCollection.doc(documentId).set(<String, dynamic>{
              ...data,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          },
      vesselPhotoWriter:
          ({
            required String documentId,
            required String thumbnailPath,
            required String fullPath,
            required int version,
            required String updatedBy,
          }) {
            return vesselCollection.doc(documentId).update(<String, dynamic>{
              // Legacy alias. Старые версии клиента смогут
              // использовать thumbnail как одиночное фото.
              'photoPath': thumbnailPath,

              'photoThumbPath': thumbnailPath,
              'photoFullPath': fullPath,
              'photoVersion': version,

              'updatedBy': updatedBy,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          },
    );
  }

  final VesselRegistryCollectionReader _readLines;
  final VesselRegistryCollectionReader _readVessels;

  final VesselRegistryDocumentWriter _writeLine;
  final VesselRegistryDocumentWriter _writeVessel;
  final VesselRegistryPhotoWriter _writeVesselPhoto;

  Future<List<VesselLineRegistryEntry>> loadLines() async {
    final documents = await _readLines();

    final result = <VesselLineRegistryEntry>[];

    for (final document in documents) {
      final line = VesselRegistryFirestoreMapper.lineFromMap(
        lineId: document.id,
        data: document.data,
      );

      if (line != null) {
        result.add(line);
      }
    }

    return List.unmodifiable(result);
  }

  Future<List<VesselRegistryEntry>> loadVessels() async {
    final documents = await _readVessels();

    final result = <VesselRegistryEntry>[];

    for (final document in documents) {
      final vessel = VesselRegistryFirestoreMapper.vesselFromMap(
        vesselUid: document.id,
        data: document.data,
      );

      if (vessel != null) {
        result.add(vessel);
      }
    }

    return List.unmodifiable(result);
  }

  Future<void> saveLine({
    required VesselLineRegistryEntry line,
    required String updatedBy,
  }) {
    return _writeLine(
      documentId: line.lineId.trim(),
      data: VesselRegistryFirestoreMapper.lineToMap(
        line: line,
        updatedBy: updatedBy,
      ),
    );
  }

  Future<void> saveVessel({
    required VesselRegistryEntry vessel,
    required String updatedBy,
  }) {
    return _writeVessel(
      documentId: vessel.vesselUid.trim(),
      data: VesselRegistryFirestoreMapper.vesselToMap(
        vessel: vessel,
        updatedBy: updatedBy,
      ),
    );
  }

  Future<void> saveVesselPhoto({
    required String vesselUid,
    required String thumbnailPath,
    required String fullPath,
    required int version,
    required String updatedBy,
  }) {
    final normalizedVesselUid = vesselUid.trim();
    final normalizedThumbnailPath = thumbnailPath.trim();
    final normalizedFullPath = fullPath.trim();
    final normalizedUpdatedBy = updatedBy.trim();

    if (normalizedVesselUid.isEmpty || normalizedVesselUid.contains('/')) {
      throw ArgumentError.value(
        vesselUid,
        'vesselUid',
        'vesselUid must be a valid document ID.',
      );
    }

    if (normalizedThumbnailPath.isEmpty) {
      throw ArgumentError.value(
        thumbnailPath,
        'thumbnailPath',
        'thumbnailPath must not be empty.',
      );
    }

    if (normalizedFullPath.isEmpty) {
      throw ArgumentError.value(
        fullPath,
        'fullPath',
        'fullPath must not be empty.',
      );
    }

    if (version <= 0) {
      throw ArgumentError.value(
        version,
        'version',
        'version must be positive.',
      );
    }

    if (normalizedUpdatedBy.isEmpty || normalizedUpdatedBy.contains('/')) {
      throw ArgumentError.value(
        updatedBy,
        'updatedBy',
        'updatedBy must be a valid user ID.',
      );
    }

    return _writeVesselPhoto(
      documentId: normalizedVesselUid,
      thumbnailPath: normalizedThumbnailPath,
      fullPath: normalizedFullPath,
      version: version,
      updatedBy: normalizedUpdatedBy,
    );
  }
}
