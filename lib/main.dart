import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@JS('window.open')
external JSAny? _openExternalUrl(JSString url, JSString target);

@JS('gagwanaSqlite.init')
external JSPromise<JSString> _sqliteInit();

@JS('gagwanaSqlite.stats')
external JSPromise<JSString> _sqliteStats();

@JS('gagwanaSqlite.listVoters')
external JSPromise<JSString> _sqliteListVoters();

@JS('gagwanaSqlite.getPhotoBlob')
external JSPromise<JSString> _sqliteGetPhotoBlob(JSString voterId);

@JS('gagwanaSqlite.getOriginalPhotoBlob')
external JSPromise<JSString> _sqliteGetOriginalPhotoBlob(JSString voterId);

@JS('gagwanaSqlite.saveParsedVoters')
external JSPromise<JSString> _sqliteSaveParsedVoters(JSString recordsJson);

@JS('gagwanaSqlite.exportDb')
external JSPromise<JSBoolean> _sqliteExportDb();

@JS('gagwanaSqlite.shareDb')
external JSPromise<JSString> _sqliteShareDb();

@JS('gagwanaSqlite.importDb')
external JSPromise<JSString> _sqliteImportDb(JSString base64);

@JS('gagwanaSqlite.syncPublishedDb')
external JSPromise<JSString> _sqliteSyncPublishedDb();

@JS('gagwanaPdfImages.extractImages')
external JSPromise<JSString> _extractPdfImages(JSString base64, JSString filename);

void main() => runApp(const GagwanaApp());

class GagwanaApp extends StatefulWidget {
  const GagwanaApp({super.key});
  @override
  State<GagwanaApp> createState() => _GagwanaAppState();
}

class _GagwanaAppState extends State<GagwanaApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Gagwana Voter Records',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    home: HomePage(dark: mode == ThemeMode.dark,
      onTheme: (v) => setState(() => mode = v ? ThemeMode.dark : ThemeMode.light)),
  );

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const brand = Color(0xFF0866FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      surface: dark ? const Color(0xFF101B2A) : Colors.white,
    );
    final radius = BorderRadius.circular(18);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF07111F) : const Color(0xFFF3F7FD),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF0B1727) : const Color(0xFFF8FAFF),
        foregroundColor: dark ? const Color(0xFFF4F7FC) : const Color(0xFF151D2B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF0B1727) : Colors.white,
        indicatorColor: dark ? const Color(0xFF123B72) : const Color(0xFFDCE9FF),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
        )),
      ),
      cardTheme: CardThemeData(
        elevation: dark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: .045),
        color: dark ? const Color(0xFF101B2A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: dark ? const Color(0xFF203047) : const Color(0xFFE8EEF7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF132238) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: dark ? const Color(0xFF9AAAC0) : const Color(0xFF8491A5)),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: dark ? const Color(0xFF263950) : const Color(0xFFDCE5F1))),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: dark ? const Color(0xFF263950) : const Color(0xFFDCE5F1))),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: brand, width: 1.5)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xFF132238) : const Color(0xFFF5F8FD),
        selectedColor: dark ? const Color(0xFF244A82) : const Color(0xFFDCE9FF),
        checkmarkColor: dark ? const Color(0xFFEAF2FF) : const Color(0xFF0849B8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide(color: dark ? const Color(0xFF2A3C54) : const Color(0xFFDCE5F1)),
        labelStyle: TextStyle(color: dark ? const Color(0xFFF0F5FF) : const Color(0xFF17253A), fontWeight: FontWeight.w600, fontSize: 12),
        secondaryLabelStyle: TextStyle(color: dark ? const Color(0xFFF0F5FF) : const Color(0xFF17253A), fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

enum Status { active, flagged, deleted }

class Voter {
  const Voter(this.id, this.serial, this.ward, this.name, this.relative, this.age, this.status,
      {this.pdf = 'Ward_05_Voter_List.pdf', this.page = 5, this.hasPhoto = false});
  final String id, ward, name, relative, pdf;
  final int serial, age, page;
  final Status status;
  final bool hasPhoto;
}

const records = <Voter>[
  Voter('RJ/15/123/456789',123,'05','राजेश कुमार शर्मा','मोहन लाल शर्मा',42,Status.active),
  Voter('RJ/15/987/654321',124,'05','सीमा देवी','सुरेश कुमार',36,Status.flagged),
  Voter('RJ/15/222/333444',125,'05','जयप्रकाश मीणा','किशन लाल मीणा',58,Status.deleted),
  Voter('RJ/15/555/666777',126,'02','गीता देवी','रामलाल',33,Status.active),
  Voter('RJ/15/888/999000',127,'08','पवन कुमार','हनुमान प्रसाद',48,Status.flagged),
];

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const String portfolioUrl = 'https://amzy.github.io/portfolio/';

  void _openPortfolio() {
    _openExternalUrl(portfolioUrl.toJS, '_blank'.toJS);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('About us', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFFF626B),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color(0xFFFF626B).withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.groups_rounded, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 18),
          Text('गगवाना', textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Gagwana Voter Records', textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('About us', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(
                  'Gagwana Voter Records helps users browse and search voter records by name, voter ID, serial number and ward. It includes ward-wise browsing, record details and a locally stored database that can be synchronised with the published database.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _openPortfolio,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Visit portfolio'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text('Portfolio: $portfolioUrl', textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (dark) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.dark, required this.onTheme});
  final bool dark;
  final ValueChanged<bool> onTheme;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  int tab = 0;
  bool showAllHomeRecords = false;
  String ward = 'All wards', status = 'All records';
  final List<PlatformFile> selectedPdfs = [];
  bool uploading = false;
  bool databaseReady = false;
  int localRecordCount = 0;
  String importStatus = '';
  final List<Map<String, dynamic>> scannedBatches = [];
  List<Voter> databaseVoters = [];
  final Map<String, Future<Uint8List?>> _photoFutures = {};

  @override
  void initState() {
    super.initState();
    _autoConnectDatabase();
  }

  Future<void> _autoConnectDatabase() async {
    try {
      await _sqliteCall('init');
      await _reloadVotersFromDatabase();
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Local database connection failed: $error');
    }
  }

  Future<void> _reloadVotersFromDatabase() async {
    final rows = jsonDecode((await _sqliteListVoters().toDart).toDart) as List<dynamic>;
    final loaded = rows.whereType<Map<String, dynamic>>().map((row) {
      final deleted = row['is_deleted'] == true;
      final review = row['review_required'] == true;
      final serialText = (row['serial_number'] ?? '').toString().replaceFirst(RegExp(r'^[Ee]'), '');
      final serial = int.tryParse(serialText) ?? 0;
      final age = (row['age'] as num?)?.toInt() ?? 0;
      return Voter(
        (row['voter_id'] ?? '').toString(), serial, (row['ward'] ?? '').toString(),
        (row['name'] ?? '').toString(), (row['relative_name'] ?? '').toString(), age,
        deleted ? Status.deleted : (review ? Status.flagged : Status.active),
        pdf: (row['source_pdf'] ?? '').toString(),
        page: (row['source_page'] as num?)?.toInt() ?? 0,
        hasPhoto: row['photo_available'] == true,
      );
    }).toList();
    if (!mounted) return;
    _photoFutures.clear();
    setState(() {
      databaseVoters = loaded;
      databaseReady = true;
      localRecordCount = loaded.length;
    });
  }

  List<Voter> get filtered => databaseVoters.where((v) {
    final q = search.text.trim().toLowerCase();
    final textMatch = q.isEmpty || v.id.toLowerCase().contains(q) ||
      v.name.toLowerCase().contains(q) || v.relative.toLowerCase().contains(q) ||
      '${v.serial}'.contains(q);
    final wardMatch = ward == 'All wards' || v.ward == ward;
    final statusMatch = status == 'All records' ||
      (status == 'Active only' && v.status == Status.active) ||
      (status == 'Flagged only' && v.status == Status.flagged) ||
      (status == 'Deleted only' && v.status == Status.deleted);
    return textMatch && wardMatch && statusMatch;
  }).toList();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      final knownNames = selectedPdfs.map((file) => file.name).toSet();
      for (final file in result.files) {
        if (knownNames.add(file.name)) selectedPdfs.add(file);
      }
      tab = 1;
    });
  }

  void removePdf(PlatformFile file) {
    setState(() => selectedPdfs.removeWhere((item) => item.name == file.name));
  }

  Future<dynamic> _sqliteCall(String method, [List<dynamic> args = const []]) async {
    try {
      switch (method) {
        case 'init':
          return (await _sqliteInit().toDart).toDart;
        case 'stats':
          return (await _sqliteStats().toDart).toDart;
        case 'exportDb':
          return (await _sqliteExportDb().toDart).toDart;
        case 'syncPublishedDb':
          return (await _sqliteSyncPublishedDb().toDart).toDart;
        case 'importDb':
          if (args.isEmpty || args.first is! String) {
            throw ArgumentError('A base64 SQLite database is required.');
          }
          return (await _sqliteImportDb((args.first as String).toJS).toDart).toDart;
        default:
          throw ArgumentError('Unsupported SQLite operation: $method');
      }
    } catch (error) {
      rethrow;
    }
  }

  Future<void> initializeLocalDatabase() async {
    setState(() { uploading = true; importStatus = 'Opening local SQLite database…'; });
    try {
      await _sqliteCall('init');
      final stats = jsonDecode((await _sqliteCall('stats')).toString()) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        databaseReady = true;
        localRecordCount = (stats['records'] as num?)?.toInt() ?? 0;
        importStatus = 'Local SQLite is ready. $localRecordCount voter record(s) stored in this browser.';
      });
      await _reloadVotersFromDatabase();
    } catch (error) {
      if (!mounted) return;
      setState(() => importStatus = 'Could not open local SQLite: $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> exportLocalDatabase() async {
    try {
      await _sqliteCall('exportDb');
      if (mounted) setState(() => importStatus = 'SQLite backup exported as voter_records.db.');
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Could not export SQLite backup: $error');
    }
  }

  Future<void> shareLocalDatabase() async {
    setState(() { uploading = true; importStatus = 'Preparing database for sharing…'; });
    try {
      await _sqliteCall('init');
      final result = jsonDecode((await _sqliteShareDb().toDart).toDart) as Map<String, dynamic>;
      if (!mounted) return;
      if (result['cancelled'] == true) {
        setState(() => importStatus = 'Database sharing cancelled.');
      } else if (result['method'] == 'share') {
        setState(() => importStatus = 'Share sheet opened. Choose WhatsApp and select the recipient.');
      } else {
        setState(() => importStatus = 'Database downloaded. WhatsApp opened with sharing instructions. Attach gagwana_voter_records.db to the chat; the recipient can use Import .db backup.');
      }
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Could not share database: $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> syncPublishedDatabase() async {
    if (uploading) return;
    setState(() { uploading = true; importStatus = 'Downloading the latest compressed voter database (.gz)…'; });
    try {
      final result = jsonDecode((await _sqliteCall('syncPublishedDb')).toString()) as Map<String, dynamic>;
      final stats = jsonDecode((await _sqliteCall('stats')).toString()) as Map<String, dynamic>;
      await _reloadVotersFromDatabase();
      if (!mounted) return;
      setState(() {
        localRecordCount = (stats['records'] as num?)?.toInt() ?? (result['records'] as num?)?.toInt() ?? 0;
        importStatus = 'Sync from .gz complete. $localRecordCount voter records are now up to date.';
      });
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Sync from .gz failed. Your current local database was kept. $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> importLocalDatabase() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      allowMultiple: false, withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => importStatus = 'Could not read the selected database file. Please select it again.');
      return;
    }
    setState(() { uploading = true; importStatus = 'Importing SQLite backup…'; });
    try {
      await _sqliteCall('importDb', [base64Encode(bytes)]);
      final stats = jsonDecode((await _sqliteCall('stats')).toString()) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        databaseReady = true;
        localRecordCount = (stats['records'] as num?)?.toInt() ?? 0;
        importStatus = 'Imported SQLite backup. $localRecordCount voter record(s) are available in this browser.';
      });
      await _reloadVotersFromDatabase();
      if (mounted) setState(() { importStatus = 'Imported SQLite backup. $localRecordCount voter record(s) are available in this browser.';
      });
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Could not import SQLite backup: $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  String _fieldValue(String text, List<String> labels) {
    final labelPattern = labels.map(RegExp.escape).join('|');
    final nextLabels = r'(?:नाम|पिता का नाम|पति का नाम|लिंग|आयु|मकान संख्या|घर संख्या)';
    final pattern = RegExp('(?:$labelPattern)\\s*[:：-]\\s*(.*?)(?=\\s*(?:$nextLabels)\\s*[:：-]|\\n|\$)', multiLine: true, dotAll: true);
    final match = pattern.firstMatch(text);
    return match?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  List<Map<String, dynamic>> _recordsFromScannedBatches() {
    final output = <Map<String, dynamic>>[];
    for (final batch in scannedBatches) {
      final filename = (batch['filename'] ?? '').toString();
      final wardMatch = RegExp(r'ward\s*(?:no[.-]?)?\s*0*(\d+)', caseSensitive: false).firstMatch(filename);
      final ward = wardMatch?.group(1)?.padLeft(2, '0') ?? '';
      for (final pageValue in (batch['pages'] as List? ?? const [])) {
        if (pageValue is! Map) continue;
        final page = pageValue;
        final pageNo = (page['page'] as num?)?.toInt() ?? 0;
        for (final chunkValue in (page['chunks'] as List? ?? const [])) {
          if (chunkValue is! Map || chunkValue['valid_voter_candidate'] != true) continue;
          final chunk = chunkValue;
          final id = (chunk['voter_id_candidate'] ?? '').toString().trim();
          final rawText = (chunk['raw_text'] ?? chunk['text'] ?? '').toString();
          if (id.isEmpty) continue;
          final serialMatch = RegExp(r'(?:^|\s)(E?\s*\d{1,4})(?:\s|$)', multiLine: true).firstMatch(rawText);
          final father = _fieldValue(rawText, ['पिता का नाम']);
          final husband = _fieldValue(rawText, ['पति का नाम']);
          final gender = _fieldValue(rawText, ['लिंग']);
          final ageText = _fieldValue(rawText, ['आयु', 'उम्र']);
          final ageMatch = RegExp(r'\d{1,3}').firstMatch(ageText);
          output.add({
            'voter_id': id,
            'serial_number': serialMatch?.group(1)?.replaceAll(RegExp(r'\s+'), '') ?? '',
            'ward': ward,
            'name': _fieldValue(rawText, ['नाम']),
            'relative_name': father.isNotEmpty ? father : husband,
            'relation_type': father.isNotEmpty ? 'father' : (husband.isNotEmpty ? 'husband' : ''),
            'house_no': _fieldValue(rawText, ['मकान संख्या', 'घर संख्या']),
            'age': ageMatch == null ? null : int.tryParse(ageMatch.group(0)!),
            'gender': gender,
            'is_deleted': false,
            'deleted_evidence': '',
            'source_pdf': filename,
            'source_page': pageNo,
            'review_required': true,
            'raw_text': rawText,
          });
        }
      }
    }
    return output;
  }

  Future<void> scanSelectedPdfs() async {
    if (selectedPdfs.isEmpty || uploading) return;
    setState(() {
      uploading = true;
      scannedBatches.clear();
      importStatus = 'Loading Hindi OCR and reading PDF pages…';
    });
    try {
      for (final file in selectedPdfs) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('Could not read ${file.name}. Please select it again.');
        }
        final raw = await _extractPdfImages(
          base64Encode(bytes).toJS,
          file.name.toJS,
        ).toDart;
        final batch = jsonDecode(raw.toDart) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => scannedBatches.add(batch));
      }
      if (!mounted) return;
      final pages = scannedBatches.fold<int>(
        0, (sum, batch) => sum + ((batch['page_count'] as num?)?.toInt() ?? 0));
      final images = scannedBatches.fold<int>(
        0, (sum, batch) => sum + ((batch['image_count'] as num?)?.toInt() ?? 0));
      final chunks = scannedBatches.fold<int>(
        0, (sum, batch) => sum + ((batch['chunk_count'] as num?)?.toInt() ?? 0));
      final validChunks = scannedBatches.fold<int>(
        0, (sum, batch) => sum + ((batch['valid_voter_chunk_count'] as num?)?.toInt() ?? 0));
      final reviewPages = scannedBatches.fold<int>(0, (sum, batch) =>
        sum + ((batch['pages'] as List? ?? const []).where((page) =>
          page is Map && page['grid_detection_failed'] == true).length));
      if (!databaseReady) {
        await _sqliteCall('init');
        databaseReady = true;
      }
      final parsedRecords = _recordsFromScannedBatches();
      final saveResult = jsonDecode(
        (await _sqliteSaveParsedVoters(jsonEncode(parsedRecords).toJS).toDart).toDart
      ) as Map<String, dynamic>;
      final saved = (saveResult['saved'] as num?)?.toInt() ?? 0;
      final total = (saveResult['total'] as num?)?.toInt() ?? 0;
      await _reloadVotersFromDatabase();
      setState(() {
        localRecordCount = total;
        importStatus =
          'Parallel Hindi OCR complete: $pages page(s), $chunks grid chunks, $validChunks valid voter candidates. '
          '$images embedded photo(s) extracted. Saved $saved candidate record(s) to local SQLite; all imported candidates are marked for review. '
          '$reviewPages page(s) used full-page OCR because the grid was not confidently detected. Verify names, relationship fields and DELETED marks before treating records as final.';
      });
    } catch (error) {
      if (mounted) setState(() => importStatus = 'PDF image extraction failed: $error');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Row(children: [
        if (wide) NavigationRail(
          selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.home_rounded), label: Text('Home')),
            NavigationRailDestination(icon: Icon(Icons.cloud_sync_rounded), label: Text('Sync')),
          ]),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: IndexedStack(
            index: tab,
            children: [
              searchScreen(),
              importScreen(),
            ],
          ),
        ))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.cloud_sync_rounded), label: 'Sync'),
        ]),
    );
  }

  Future<void> _showFilters() async {
    var draftWard = ward;
    var draftStatus = status;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: false, backgroundColor: theme.colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: .58),
      constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * .78),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final t = Theme.of(context);
          return SafeArea(top: false, child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: t.colorScheme.onSurfaceVariant.withValues(alpha: .35), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(children: [Expanded(child: Text('फ़िल्टर', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))), TextButton(onPressed: () => setSheetState(() { draftWard = 'All wards'; draftStatus = 'All records'; }), child: const Text('रीसेट करें'))]),
              const SizedBox(height: 18),
              Text('वार्ड संख्या', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 9, children: ['All wards', ...List.generate(13, (i) => (i + 1).toString().padLeft(2, '0'))].map((value) {
                final selected = draftWard == value;
                return ChoiceChip(label: Text(value == 'All wards' ? 'सभी' : value), selected: selected, showCheckmark: false, onSelected: (_) => setSheetState(() => draftWard = value), selectedColor: t.colorScheme.primary, backgroundColor: t.colorScheme.surfaceContainerHighest, labelStyle: TextStyle(color: selected ? t.colorScheme.onPrimary : t.colorScheme.onSurface, fontWeight: FontWeight.w800), shape: StadiumBorder(side: BorderSide(color: t.colorScheme.outlineVariant.withValues(alpha: .55))));
              }).toList()),
              const SizedBox(height: 22),
              Text('रिकॉर्ड की स्थिति', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [('All records', 'सभी'), ('Active only', 'सक्रिय'), ('Flagged only', 'जाँच बाकी'), ('Deleted only', 'हटाए गए')].map((entry) => ChoiceChip(label: Text(entry.$2), selected: draftStatus == entry.$1, showCheckmark: false, onSelected: (_) => setSheetState(() => draftStatus = entry.$1))).toList()),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () { setState(() { ward = draftWard; status = draftStatus; showAllHomeRecords = true; }); Navigator.pop(sheetContext); }, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('फ़िल्टर लागू करें', style: TextStyle(fontWeight: FontWeight.w800)))),
            ]),
          ));
        },
      ),
    );
  }
  Widget searchScreen() {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final shown = filtered;
    final showingResults = search.text.trim().isNotEmpty || ward != 'All wards' || status != 'All records';
    final activeFilters = (ward != 'All wards' ? 1 : 0) + (status != 'All records' ? 1 : 0);
    return RefreshIndicator(
      onRefresh: syncPublishedDatabase, color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface, displacement: 42,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0879D5), Color(0xFF06468E)]), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.groups_rounded, color: Colors.white, size: 26)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('गगवाना मतदाता', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 3),
              Text('VOTER RECORDS • AJMER', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
            ])),
            IconButton(tooltip: 'About us', onPressed: () => _openExternalUrl('https://amzy.github.io/portfolio/'.toJS, '_blank'.toJS), icon: const Icon(Icons.info_outline_rounded)),
            IconButton.filledTonal(tooltip: dark ? 'Light mode' : 'Dark mode', onPressed: () => widget.onTheme(!dark), icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          ]),
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: dark ? const [Color(0xFF073D78), Color(0xFF092C50), Color(0xFF0C2037)] : const [Color(0xFFE2F1FF), Color(0xFFF2F8FF), Color(0xFFE8F3FF)]), border: Border.all(color: dark ? const Color(0xFF1764A8) : const Color(0xFFD3E6F8))),
            child: Column(children: [
              TextField(controller: search, onChanged: (_) => setState(() => showAllHomeRecords = true), textInputAction: TextInputAction.search, decoration: InputDecoration(hintText: 'नाम, पिता / पति का नाम या मतदाता ID खोजें…', prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF1685DF), size: 25), suffixIcon: search.text.isEmpty ? null : IconButton(tooltip: 'खोज साफ़ करें', onPressed: () { search.clear(); setState(() => showAllHomeRecords = false); }, icon: const Icon(Icons.close_rounded)), filled: true, fillColor: dark ? const Color(0xFFF5F8FC) : Colors.white, hintStyle: const TextStyle(color: Color(0xFF7588A2), fontSize: 13), contentPadding: const EdgeInsets.symmetric(vertical: 17), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)), style: const TextStyle(color: Color(0xFF152A42), fontWeight: FontWeight.w600)),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _showFilters, icon: const Icon(Icons.location_on_rounded, size: 18), label: Text(ward == 'All wards' ? 'सभी वार्ड' : 'वार्ड $ward', maxLines: 1, overflow: TextOverflow.ellipsis), style: OutlinedButton.styleFrom(foregroundColor: dark ? Colors.white : const Color(0xFF174A85), side: BorderSide(color: dark ? const Color(0xFF47749D) : const Color(0xFFB8D4F0)), minimumSize: const Size(0, 44), shape: const StadiumBorder()))),
                const SizedBox(width: 9),
                Expanded(child: OutlinedButton.icon(onPressed: _showFilters, icon: const Icon(Icons.tune_rounded, size: 18), label: Text(activeFilters == 0 ? 'फ़िल्टर' : 'फ़िल्टर ($activeFilters)'), style: OutlinedButton.styleFrom(foregroundColor: dark ? Colors.white : const Color(0xFF174A85), side: BorderSide(color: dark ? const Color(0xFF47749D) : const Color(0xFFB8D4F0)), minimumSize: const Size(0, 44), shape: const StadiumBorder()))),
              ]),
            ]),
          ),
          const SizedBox(height: 19),
          Row(children: [Expanded(child: Text(showingResults ? 'खोज परिणाम (${shown.length})' : 'मतदाता सूची (${shown.length})', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), if (showingResults) TextButton(onPressed: () => setState(() { search.clear(); ward = 'All wards'; status = 'All records'; showAllHomeRecords = false; }), child: const Text('साफ़ करें'))]),
          const SizedBox(height: 9),
          if (shown.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20), child: Column(children: [Icon(Icons.person_search_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant), const SizedBox(height: 12), Text('कोई मतदाता नहीं मिला', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('नाम, मतदाता ID या वार्ड फ़िल्टर बदलकर फिर कोशिश करें', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))]))
          else ...shown.take(showingResults || showAllHomeRecords ? shown.length : 30).map(recordCard),
          if (!showingResults && shown.length > 30) Center(child: TextButton.icon(onPressed: () => setState(() => showAllHomeRecords = !showAllHomeRecords), icon: Icon(showAllHomeRecords ? Icons.expand_less_rounded : Icons.expand_more_rounded), label: Text(showAllHomeRecords ? 'कम रिकॉर्ड दिखाएँ' : 'और रिकॉर्ड देखें'))),
          if (uploading) const Padding(padding: EdgeInsets.only(top: 10), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget recordCard(Voter v) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final initial = v.name.trim().isEmpty ? '•' : v.name.trim().substring(0, 1);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101F30) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? const Color(0xFF1C3852) : const Color(0xFFDCE7F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context, isScrollControlled: true, showDragHandle: true,
          useSafeArea: true, builder: (_) => detailSheet(v),
        ),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 66, height: 76,
                child: v.hasPhoto
                    ? FutureBuilder<Uint8List?>(
                        future: _photoFutures.putIfAbsent(v.id, () => _loadVoterPhoto(v.id)),
                        builder: (context, snapshot) {
                          final bytes = snapshot.data;
                          if (bytes != null && bytes.isNotEmpty) {
                            return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => _photoPlaceholder(initial, theme, dark));
                          }
                          return _photoPlaceholder(initial, theme, dark);
                        },
                      )
                    : _photoPlaceholder(initial, theme, dark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(v.name.trim().isEmpty ? 'नाम उपलब्ध नहीं' : v.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  const SizedBox(width: 5),
                  badge(v.status),
                ]),
                const SizedBox(height: 4),
                Text(v.relative.trim().isEmpty ? 'पिता / पति: उपलब्ध नहीं' : 'पिता / पति: ${v.relative}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 7, runSpacing: 6, children: [
                  _recordMeta(Icons.person_outline_rounded, v.age > 0 ? '${v.age} वर्ष' : 'आयु —'),
                  _recordMeta(Icons.location_on_rounded, 'वार्ड ${wardLabel(v.ward)}'),
                ]),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: dark ? .22 : .09),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.numbers_rounded, size: 15, color: theme.colorScheme.primary),
                      const SizedBox(width: 5),
                      Text('क्र. संख्या', style: theme.textTheme.labelSmall?.copyWith(
                        color: muted, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 5),
                      Text(v.serial > 0 ? '${v.serial}' : '—',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: muted, size: 24),
          ]),
        ),
      ),
    );
  }
  Future<Uint8List?> _loadVoterPhoto(String voterId) async {
    try {
      final encoded = (await _sqliteGetPhotoBlob(voterId.toJS).toDart).toDart;
      if (encoded.isEmpty) return null;
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  Widget _photoPlaceholder(String initial, ThemeData theme, bool dark) => Container(
    color: dark ? const Color(0xFF18304D) : const Color(0xFFEAF2FF),
    alignment: Alignment.center,
    child: Text(initial, style: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.primary,
    )),
  );

  Widget _recordMeta(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF17263A)
          : const Color(0xFFF3F6FB),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    ]),
  );

  Widget badge(Status s) {
    final c = s == Status.active ? const Color(0xFF16A765) : s == Status.flagged ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final label = s == Status.active ? 'Active' : s == Status.flagged ? 'Flagged' : 'Deleted';
    return Container(padding: const EdgeInsets.symmetric(horizontal:9,vertical:5),
      decoration: BoxDecoration(color:c.withValues(alpha:.14),borderRadius:BorderRadius.circular(30)),
      child: Text(label, style: TextStyle(color:c,fontWeight:FontWeight.w700,fontSize:11)));
  }

  Widget detailSheet(Voter v) {
    var selectedSection = 0;
    final sections = const ['विवरण', 'पता', 'दस्तावेज', 'नोट्स'];
    return StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(children: [
                  Expanded(child: Text('मतदाता विवरण', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [
                    _voterHeroCard(v, sheetContext),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext).brightness == Brightness.dark ? const Color(0xFF142235) : const Color(0xFFEAF1FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(children: List.generate(sections.length, (index) => Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setSheetState(() => selectedSection = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                            decoration: BoxDecoration(
                              color: selectedSection == index ? Theme.of(sheetContext).colorScheme.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: selectedSection == index ? [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 8, offset: const Offset(0, 2))] : [],
                            ),
                            child: Text(sections[index], textAlign: TextAlign.center, style: TextStyle(
                              fontSize: 12, fontWeight: selectedSection == index ? FontWeight.w800 : FontWeight.w600,
                              color: selectedSection == index ? Theme.of(sheetContext).colorScheme.primary : Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                            )),
                          ),
                        ),
                      ))),
                    ),
                    const SizedBox(height: 12),
                    if (selectedSection == 0) _detailInfoPanel(v, sheetContext),
                    if (selectedSection == 1) _detailAddressPanel(v, sheetContext),
                    if (selectedSection == 2) _detailDocumentsPanel(v, sheetContext),
                    if (selectedSection == 3) _detailNotesPanel(v, sheetContext),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _voterHeroCard(Voter v, BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final initial = v.name.trim().isEmpty ? '•' : v.name.trim().substring(0, 1);
    final foreground = dark ? const Color(0xFFF4F7FC) : const Color(0xFF142B4A);
    final muted = dark ? const Color(0xFFB8C8DC) : const Color(0xFF536985);
    final surface = dark ? const Color(0xFF0D1B2B) : const Color(0xFFF7FAFF);
    final border = dark ? const Color(0xFF17609A) : const Color(0xFFD7E3F3);

    Widget metric(IconData icon, String label, String value, Color accent) =>
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? .13 : .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: .22)),
            ),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 19),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(value.isEmpty ? '—' : value, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? .24 : .08),
            blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 13, 13),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF06468E), Color(0xFF0879D5), Color(0xFF1198E8)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 25),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('गगवाना मतदाता', maxLines: 1,
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('VOTER PROFILE', style: TextStyle(
                        color: Color(0xFFD8EAFE), fontSize: 9,
                        letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                badge(v.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 106, height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF2788D8), width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: v.hasPhoto
                          ? FutureBuilder<Uint8List?>(
                              future: _photoFutures.putIfAbsent(v.id, () => _loadVoterPhoto(v.id)),
                              builder: (context, snapshot) {
                                final bytes = snapshot.data;
                                if (bytes != null && bytes.isNotEmpty) {
                                  return Image.memory(bytes, fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => _avatarInitial(initial, theme));
                                }
                                return _avatarInitial(initial, theme);
                              },
                            )
                          : _avatarInitial(initial, theme),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name.isEmpty ? 'नाम उपलब्ध नहीं' : v.name,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: foreground, fontSize: 21,
                              height: 1.15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 13),
                          Text('पिता / पति का नाम',
                            style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(v.relative.trim().isEmpty ? 'उपलब्ध नहीं' : v.relative,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: foreground, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 13),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0879D5).withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.cake_rounded, color: Color(0xFF2798FF), size: 17),
                              const SizedBox(width: 6),
                              Text(v.age > 0 ? '${v.age} वर्ष' : 'आयु —',
                                style: TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 12)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    metric(Icons.numbers_rounded, 'क्र. संख्या', '${v.serial}', const Color(0xFF3B9BFF)),
                    const SizedBox(width: 7),
                    metric(Icons.location_on_rounded, 'वार्ड संख्या', wardLabel(v.ward), const Color(0xFF10BFA0)),
                    const SizedBox(width: 7),
                    metric(Icons.badge_rounded, 'मतदाता ID', v.id, const Color(0xFF7C9EFF)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _corporateMeta(
    IconData icon,
    String label,
    String value,
    Color valueColor,
    Color labelColor,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: const Color(0xFF287AC4)),
      const SizedBox(width: 4),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 8, color: labelColor, fontWeight: FontWeight.w700)),
            Text(value.isEmpty ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: valueColor, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    ],
  );

  String wardLabel(String value) {
    final number = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    return number == null ? value : number.toString().padLeft(2, '0');
  }

  Widget _avatarInitial(String initial, ThemeData theme) => Container(
    color: theme.brightness == Brightness.dark
        ? const Color(0xFF24364D)
        : const Color(0xFFE4ECF7),
    alignment: Alignment.center,
    child: Text(
      initial,
      style: TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w900,
        color: theme.colorScheme.primary,
      ),
    ),
  );

  Widget _heroPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .88), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF174A40)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF173C35))),
    ]),
  );

  Widget _detailInfoPanel(Voter v, BuildContext context) => _detailPanel(context, [
    _detailDataRow(Icons.badge_outlined, 'मतदाता ID', v.id, copy: true),
    _detailDataRow(Icons.person_outline, 'नाम', v.name),
    _detailDataRow(Icons.groups_2_outlined, 'पिता / पति का नाम', v.relative),
    _detailDataRow(Icons.cake_outlined, 'आयु', v.age > 0 ? '${v.age} वर्ष' : '—'),
    _detailDataRow(Icons.numbers_rounded, 'क्र. संख्या', '${v.serial}'),
    _detailDataRow(Icons.location_on_outlined, 'वार्ड संख्या', wardLabel(v.ward)),
    _detailDataRow(Icons.verified_outlined, 'स्थिति', v.status == Status.active ? 'सक्रिय' : v.status == Status.flagged ? 'सत्यापन आवश्यक' : 'हटाया गया'),
  ]);

  Widget _detailAddressPanel(Voter v, BuildContext context) => _detailPanel(context, [
    _detailDataRow(Icons.home_outlined, 'पता', 'गगवाना, वार्ड ${wardLabel(v.ward)}'),
    _detailDataRow(Icons.location_city_outlined, 'शहर / जिला', 'अजमेर'),
    _detailDataRow(Icons.map_outlined, 'राज्य', 'राजस्थान'),
  ]);

  Widget _detailDocumentsPanel(Voter v, BuildContext context) => _detailPanel(context, [
    _detailDataRow(Icons.picture_as_pdf_outlined, 'मूल दस्तावेज', v.pdf),
    _detailDataRow(Icons.description_outlined, 'PDF पृष्ठ', '${v.page}'),
    _detailDataRow(Icons.image_outlined, 'फोटो', v.hasPhoto ? 'उपलब्ध' : 'उपलब्ध नहीं'),
  ]);

  Widget _detailNotesPanel(Voter v, BuildContext context) => _detailPanel(context, [
    _detailDataRow(Icons.flag_outlined, 'समीक्षा स्थिति', v.status == Status.flagged ? 'इस रिकॉर्ड की जाँच आवश्यक है' : 'कोई अतिरिक्त नोट नहीं'),
  ]);

  Widget _detailPanel(BuildContext context, List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .35)),
    ),
    child: Column(children: rows),
  );

  Widget _detailDataRow(IconData icon, String label, String value, {bool copy = false}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: dark ? .22 : .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: dark ? const Color(0xFFB8C6D9) : const Color(0xFF536277),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.3,
                color: dark ? const Color(0xFFF4F7FC) : const Color(0xFF17253A),
              ),
            ),
          ),
          if (copy)
            IconButton(
              tooltip: 'Copy voter ID',
              visualDensity: VisualDensity.compact,
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              icon: Icon(Icons.copy_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _detailPhotoPlaceholder(Voter v) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final name = v.name.trim();
    final initial = name.isEmpty ? '•' : name.substring(0, 1);
    return _photoPlaceholder(initial, theme, dark);
  }

  Widget detailRow(String label,String value) => Padding(padding: const EdgeInsets.symmetric(vertical:8),
    child: Row(children: [SizedBox(width:135, child: Text(label, style: TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight:FontWeight.w600)))]));

  Widget importScreen() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Import voter-list PDFs', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
    const SizedBox(height:8),
    const Text('Select multiple PDFs. Review OCR results, resolve duplicates, and confirm changes before updating the master records.'),
    const SizedBox(height:18),
    Card(child: InkWell(onTap:pickPdf, borderRadius:BorderRadius.circular(20), child: Padding(
      padding: const EdgeInsets.all(28), child: Column(children: [
        Icon(Icons.cloud_upload_rounded,size:52,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:12),
        Text(selectedPdfs.isEmpty ? 'Select voter-list PDFs' : '${selectedPdfs.length} PDF file(s) selected',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:6), const Text('Tap to select one or multiple PDF files'),
      ])))),
    const SizedBox(height:16),
    Card(child: Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Import settings',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
      const ListTile(leading:Icon(Icons.translate),title:Text('OCR language: Hindi (Devanagari)')),
      const SwitchListTile(value:true,onChanged:null,title:Text('Extract voter photos from PDFs')),
      const SwitchListTile(value:true,onChanged:null,title:Text('Detect explicit DELETED marks only')),
      const SwitchListTile(value:true,onChanged:null,title:Text('Flag uncertain OCR fields for review')),
    ]))),
    const SizedBox(height:14),
    if (selectedPdfs.isNotEmpty) ...[
      const SizedBox(height: 8),
      ...selectedPdfs.map((file) => Card(child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_rounded),
        title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(file.size > 0 ? '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB' : 'PDF selected'),
        trailing: IconButton(tooltip: 'Remove file', onPressed: () => removePdf(file), icon: const Icon(Icons.close)),
      ))),
    ],
    const SizedBox(height: 14),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Local SQLite database', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('No Python server is required. The database is stored in this browser using IndexedDB and can be exported as a SQLite .db file for backup or transfer. Each browser/device has its own local copy.'),
          const SizedBox(height: 10),
          Row(children: [
            Icon(databaseReady ? Icons.check_circle : Icons.storage, color: databaseReady ? Colors.green : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(databaseReady ? 'Database ready • $localRecordCount voter records' : 'Database not opened yet')),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: uploading ? null : initializeLocalDatabase,
              icon: const Icon(Icons.storage), label: const Text('Open local database')),
            OutlinedButton.icon(
              onPressed: uploading ? null : exportLocalDatabase,
              icon: const Icon(Icons.download), label: const Text('Export .db backup')),
            OutlinedButton.icon(
              onPressed: uploading ? null : shareLocalDatabase,
              icon: const Icon(Icons.share), label: const Text('Share via WhatsApp')),
            OutlinedButton.icon(
              onPressed: uploading ? null : importLocalDatabase,
              icon: const Icon(Icons.upload_file), label: const Text('Import .db backup')),
            FilledButton.icon(
              onPressed: uploading ? null : syncPublishedDatabase,
              icon: uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
              label: const Text('Sync from .gz')),
          ]),
        ]),
      ),
    ),
    const SizedBox(height: 14),
    FilledButton.icon(
      onPressed: selectedPdfs.isEmpty || uploading ? null : scanSelectedPdfs,
      icon: uploading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.document_scanner),
      label: Text(uploading ? 'Reading PDF pages…' : 'Run Hindi OCR'),
    ),
    const SizedBox(height: 10),
    if (importStatus.isNotEmpty) ...[
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(importStatus),
        ),
      ),
    ],
    if (scannedBatches.isNotEmpty) ...[
      const SizedBox(height: 12),
      Text('Scanned PDF results', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ...scannedBatches.map((batch) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.fact_check_outlined),
          title: Text(batch['filename']?.toString() ?? 'PDF'),
          subtitle: Text('${batch['page_count'] ?? 0} pages • ${batch['image_count'] ?? 0} embedded images'),
          children: [
            ...(batch['pages'] as List? ?? const []).expand<Widget>((pageValue) {
              final page = pageValue as Map<String, dynamic>;
              final images = page['images'] as List? ?? const [];
              return [
                ListTile(
                  dense: true,
                  title: Text('Page ${page['page']}'),
                  subtitle: Text((page['text'] ?? '').toString().isEmpty
                      ? 'No readable OCR text on this page'
                      : (page['text'] ?? '').toString(),
                      maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
                if ((page['deleted_stamp_candidates'] as List? ?? const []).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Possible DELETED stamp detected on page ${page['page']}. '
                        'Review the stamp against each voter card; this page-level signal '
                        'does not automatically mark all voters as deleted.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                if (page['ocr_error'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text('Hindi OCR unavailable: ${page['ocr_error']}'),
                  ),
                if (images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Wrap(
                      spacing: 10, runSpacing: 10,
                      children: images.map<Widget>((imageValue) {
                        final image = imageValue as Map<String, dynamic>;
                        final dataUrl = (image['data_url'] ?? '').toString();
                        final comma = dataUrl.indexOf(',');
                        final Uint8List bytes = comma >= 0
                            ? base64Decode(dataUrl.substring(comma + 1))
                            : Uint8List(0);
                        return SizedBox(
                          width: 112, height: 132,
                          child: Column(children: [
                            Expanded(child: Image.memory(bytes, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                            Text('Image ${image['index']}', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
              ];
            }),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                (batch['pages'] as List? ?? const [])
                    .map((page) => 'Page ${page['page']}: ${page['text']}')
                    .join('\\n\\n'),
              ),
            ),
          ],
        ),
      )),
    ],
    const SizedBox(height: 10),
    const Text('Hindi OCR reads the original page images to avoid broken PDF font mappings. Photo extraction is paused in this fast scan to prevent embedded-image stalls; voter-row parsing and photo matching are not saved automatically.'),

  ]);
}
