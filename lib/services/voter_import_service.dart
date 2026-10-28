/// Merge layer for OCR/import results. This is deliberately independent of PDF/OCR
/// so the parser can feed records from any number of uploaded voter-list PDFs.
class VoterImportRecord {
  const VoterImportRecord({
    required this.voterId,
    required this.serialNumber,
    required this.ward,
    required this.name,
    required this.relativeName,
    required this.age,
    this.photoPath,
    this.sourcePdf = '',
    this.sourcePage,
    this.deletedMarkDetected = false,
    this.flaggedForReview = false,
  });

  final String voterId;
  final String serialNumber;
  final String ward;
  final String name;
  final String relativeName;
  final int? age;
  final String? photoPath;
  final String sourcePdf;
  final int? sourcePage;
  /// True only when OCR/visual review detects an explicit DELETED mark.
  final bool deletedMarkDetected;
  final bool flaggedForReview;

  String get normalizedId => normalizeVoterId(voterId);

  VoterImportRecord copyWith({
    String? voterId,
    String? serialNumber,
    String? ward,
    String? name,
    String? relativeName,
    int? age,
    String? photoPath,
    String? sourcePdf,
    int? sourcePage,
    bool? deletedMarkDetected,
    bool? flaggedForReview,
  }) => VoterImportRecord(
    voterId: voterId ?? this.voterId,
    serialNumber: serialNumber ?? this.serialNumber,
    ward: ward ?? this.ward,
    name: name ?? this.name,
    relativeName: relativeName ?? this.relativeName,
    age: age ?? this.age,
    // A missing photo in a new PDF must never erase an existing photo.
    photoPath: _nonBlank(photoPath) ? photoPath : this.photoPath,
    sourcePdf: _nonBlank(sourcePdf) ? sourcePdf! : this.sourcePdf,
    sourcePage: sourcePage ?? this.sourcePage,
    deletedMarkDetected: deletedMarkDetected ?? this.deletedMarkDetected,
    flaggedForReview: flaggedForReview ?? this.flaggedForReview,
  );
}

class VoterImportMergeResult {
  const VoterImportMergeResult({
    required this.records,
    required this.addedCount,
    required this.updatedCount,
    required this.duplicateCount,
  });

  final List<VoterImportRecord> records;
  final int addedCount;
  final int updatedCount;
  /// Number of duplicate IDs found within the incoming batch.
  final int duplicateCount;
}

/// Normalize case, whitespace, and separators for robust voter-ID matching.
String normalizeVoterId(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool _nonBlank(String? value) => value != null && value.trim().isNotEmpty;

class VoterImportService {
  const VoterImportService();

  /// Deduplicates incoming records and merges them into existing master records.
  ///
  /// Voter ID is the stable key. Records without a usable voter ID are flagged
  /// for manual review and kept separately rather than risking a false merge.
  /// Non-empty incoming fields replace old fields; blank OCR output never
  /// erases known values. Photo paths are preserved unless a new photo exists.
  VoterImportMergeResult merge({
    required List<VoterImportRecord> existing,
    required List<VoterImportRecord> incoming,
  }) {
    final merged = <VoterImportRecord>[...existing];
    final indexById = <String, int>{};
    for (var i = 0; i < merged.length; i++) {
      final key = merged[i].normalizedId;
      if (key.isNotEmpty) indexById.putIfAbsent(key, () => i);
    }

    var added = 0;
    var updated = 0;
    var duplicates = 0;
    final seenIncoming = <String>{};

    for (final raw in incoming) {
      final key = raw.normalizedId;
      if (key.isEmpty) {
        // No stable identity: do not silently merge or discard this row.
        merged.add(raw.copyWith(flaggedForReview: true));
        added++;
        continue;
      }

      if (!seenIncoming.add(key)) duplicates++;
      final existingIndex = indexById[key];
      if (existingIndex == null) {
        merged.add(raw);
        indexById[key] = merged.length - 1;
        added++;
      } else {
        final previous = merged[existingIndex];
        merged[existingIndex] = _mergeRecord(previous, raw);
        updated++;
      }
    }

    return VoterImportMergeResult(
      records: List.unmodifiable(merged),
      addedCount: added,
      updatedCount: updated,
      duplicateCount: duplicates,
    );
  }

  VoterImportRecord _mergeRecord(
    VoterImportRecord oldRecord,
    VoterImportRecord newRecord,
  ) {
    return VoterImportRecord(
      voterId: _choose(newRecord.voterId, oldRecord.voterId),
      serialNumber: _choose(newRecord.serialNumber, oldRecord.serialNumber),
      ward: _choose(newRecord.ward, oldRecord.ward),
      name: _choose(newRecord.name, oldRecord.name),
      relativeName: _choose(newRecord.relativeName, oldRecord.relativeName),
      age: newRecord.age ?? oldRecord.age,
      photoPath: _nonBlank(newRecord.photoPath)
          ? newRecord.photoPath
          : oldRecord.photoPath,
      sourcePdf: _choose(newRecord.sourcePdf, oldRecord.sourcePdf),
      sourcePage: newRecord.sourcePage ?? oldRecord.sourcePage,
      // Never infer deletion from a missing row or missing mark.
      deletedMarkDetected:
          oldRecord.deletedMarkDetected || newRecord.deletedMarkDetected,
      flaggedForReview:
          oldRecord.flaggedForReview || newRecord.flaggedForReview,
    );
  }

  String _choose(String newer, String older) =>
      _nonBlank(newer) ? newer : older;
}
