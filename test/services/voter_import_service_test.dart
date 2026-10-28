import 'package:flutter_test/flutter_test.dart';
import 'package:gagwana_voter_records/services/voter_import_service.dart';

void main() {
  const service = VoterImportService();

  VoterImportRecord record({
    String id = 'RJ/15/001/123456',
    String name = 'पुराना नाम',
    String? photo,
    String relative = 'पिता का नाम',
    bool deleted = false,
  }) => VoterImportRecord(
    voterId: id,
    serialNumber: '12',
    ward: '01',
    name: name,
    relativeName: relative,
    age: 40,
    photoPath: photo,
    deletedMarkDetected: deleted,
  );

  test('normalizes voter IDs and avoids importing duplicate PDFs as new rows', () {
    final result = service.merge(
      existing: [record(photo: 'photos/123.jpg')],
      incoming: [
        record(id: 'rj 15 001 123456', name: 'नया नाम'),
        record(id: 'RJ/15/001/123456', name: 'नया नाम सही'),
      ],
    );

    expect(result.records, hasLength(1));
    expect(result.addedCount, 0);
    expect(result.updatedCount, 2);
    expect(result.duplicateCount, 1);
    expect(result.records.single.name, 'नया नाम सही');
  });

  test('preserves existing photo when newer PDF has no photo', () {
    final result = service.merge(
      existing: [record(photo: 'photos/123.jpg')],
      incoming: [record(name: 'अपडेट नाम')],
    );

    expect(result.records.single.photoPath, 'photos/123.jpg');
    expect(result.records.single.name, 'अपडेट नाम');
  });

  test('fills a missing photo when a later import contains one', () {
    final result = service.merge(
      existing: [record()],
      incoming: [record(photo: 'photos/new.jpg')],
    );

    expect(result.records.single.photoPath, 'photos/new.jpg');
  });

  test('does not mark a record deleted unless an explicit mark is detected', () {
    final existing = record(deleted: false);
    final unchanged = service.merge(
      existing: [existing],
      incoming: [record(name: 'अपडेट नाम')],
    );
    final explicitlyDeleted = service.merge(
      existing: [existing],
      incoming: [record(deleted: true)],
    );

    expect(unchanged.records.single.deletedMarkDetected, isFalse);
    expect(explicitlyDeleted.records.single.deletedMarkDetected, isTrue);
  });

  test('keeps rows without voter IDs separate and flags them for review', () {
    final result = service.merge(
      existing: [],
      incoming: [record(id: '', name: 'संदिग्ध रिकॉर्ड')],
    );

    expect(result.records, hasLength(1));
    expect(result.records.single.flaggedForReview, isTrue);
  });
}
