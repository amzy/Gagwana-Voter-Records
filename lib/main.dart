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
    setState(() { uploading = true; importStatus = 'Downloading the latest voter database…'; });
    try {
      final result = jsonDecode((await _sqliteCall('syncPublishedDb')).toString()) as Map<String, dynamic>;
      final stats = jsonDecode((await _sqliteCall('stats')).toString()) as Map<String, dynamic>;
      await _reloadVotersFromDatabase();
      if (!mounted) return;
      setState(() {
        localRecordCount = (stats['records'] as num?)?.toInt() ?? (result['records'] as num?)?.toInt() ?? 0;
        importStatus = 'Sync complete. $localRecordCount voter records are now up to date.';
      });
    } catch (error) {
      if (mounted) setState(() => importStatus = 'Sync failed. Your current local database was kept. $error');
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
            NavigationRailDestination(icon: Icon(Icons.search), label: Text('Search')),
            NavigationRailDestination(icon: Icon(Icons.picture_as_pdf), label: Text('Import PDFs')),
          ]),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: IndexedStack(
            index: tab,
            children: [
              RefreshIndicator(
                onRefresh: syncPublishedDatabase,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
                displacement: 54,
                edgeOffset: 8,
                child: searchScreen(),
              ),
              importScreen(),
            ],
          ),
        ))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'Import PDFs'),
        ]),
    );
  }

  Future<void> _showFilters() async {
    var draftWard = ward;
    var draftStatus = status;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Filter records', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Text('Ward', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  'All wards', ...List.generate(13, (i) => (i + 1).toString().padLeft(2, '0'))
                ].map((v) => ChoiceChip(
                  label: Text(v == 'All wards' ? v : 'Ward $v'),
                  selected: draftWard == v,
                  onSelected: (_) => setSheetState(() => draftWard = v),
                )).toList()),
                const SizedBox(height: 20),
                Text('Record status', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  'All records', 'Active only', 'Flagged only', 'Deleted only'
                ].map((v) => ChoiceChip(
                  label: Text(v),
                  selected: draftStatus == v,
                  onSelected: (_) => setSheetState(() => draftStatus = v),
                )).toList()),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => setSheetState(() { draftWard = 'All wards'; draftStatus = 'All records'; }),
                    child: const Text('Reset'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(
                    onPressed: () {
                      setState(() { ward = draftWard; status = draftStatus; });
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Show results'))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget searchScreen() {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final total = databaseVoters.length;
    final activeCount = databaseVoters.where((v) => v.status == Status.active).length;
    final flaggedCount = databaseVoters.where((v) => v.status == Status.flagged).length;
    final deletedCount = databaseVoters.where((v) => v.status == Status.deleted).length;
    final wardCounts = List<int>.generate(13, (i) => databaseVoters.where((v) {
      final n = int.tryParse(v.ward.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return n == i + 1;
    }).length);
    final showingResults = search.text.trim().isNotEmpty || ward != 'All wards' || status != 'All records';
    final shown = filtered;
    return RefreshIndicator(
      onRefresh: syncPublishedDatabase,
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      displacement: 48,
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: const Color(0xFFFF626B), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'गगवाना',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'About us',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => _openExternalUrl(
                'https://amzy.github.io/portfolio/'.toJS,
                '_blank'.toJS,
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 25),
            ),
          ),
          IconButton.filledTonal(
            tooltip: dark ? 'Light mode' : 'Dark mode',
            onPressed: () => widget.onTheme(!dark),
            icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ]),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: dark ? const [Color(0xFF173B58), Color(0xFF172A43), Color(0xFF253B55)] : const [Color(0xFFE2F4E2), Color(0xFFD9EDFF), Color(0xFFF7EEDB)],
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('अपनी मतदाता सूची खोजें', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: dark ? Colors.white : const Color(0xFF173D36))),
            const SizedBox(height: 5),
            Text('Search voters by name, voter ID or serial number', style: theme.textTheme.bodySmall?.copyWith(color: dark ? Colors.white70 : const Color(0xFF405B62))),
            const SizedBox(height: 16),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'नाम, पिता/पति का नाम या Voter ID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: search.text.isEmpty ? null : IconButton(
                  onPressed: () { search.clear(); setState(() {}); },
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: dark ? const Color(0xFF0C1B2B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _homeStat('कुल रिकॉर्ड', total.toString(), Icons.people_alt_rounded, const Color(0xFF3978E8), dark)),
          const SizedBox(width: 9),
          Expanded(child: _homeStat('सक्रिय', activeCount.toString(), Icons.check_circle_rounded, const Color(0xFF16A765), dark)),
          const SizedBox(width: 9),
          Expanded(child: _homeStat('जाँच बाकी', flaggedCount.toString(), Icons.flag_rounded, const Color(0xFFF0A12A), dark)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _homeStat('हटाए गए', deletedCount.toString(), Icons.person_off_rounded, const Color(0xFFE35A61), dark)),
          const SizedBox(width: 9),
          Expanded(child: _homeStat('वार्ड', '13', Icons.location_on_rounded, const Color(0xFF8B63D9), dark)),
          const SizedBox(width: 9),
          Expanded(child: _homeStat('डेटाबेस', databaseReady ? 'तैयार' : 'लोड…', Icons.storage_rounded, const Color(0xFF269A9A), dark)),
        ]),
        const SizedBox(height: 25),
        Row(children: [
          Expanded(child: Text('वार्ड के अनुसार खोजें', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          TextButton(onPressed: () => setState(() { ward = 'All wards'; status = 'All records'; }), child: const Text('सभी वार्ड')),
        ]),
        const SizedBox(height: 3),
        Text('हर वार्ड की अपनी पहचान और रंग', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 13,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.82,
          ),
          itemBuilder: (context, index) {
            final number = index + 1;
            final label = number.toString().padLeft(2, '0');
            final selected = ward == label || ward == number.toString();
            return InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () => setState(() { ward = selected ? 'All wards' : label; }),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: selected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: .35), width: selected ? 2 : 1),
                ),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(
                    'assets/ward_themes/ward_${label}.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Container(color: (dark ? Colors.black : Colors.white).withValues(alpha: .18)),
                  Positioned(left: 10, bottom: 8, right: 8, child: Row(children: [
                    Expanded(child: Text('वार्ड $label', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF173D36), shadows: [Shadow(color: Colors.white, blurRadius: 7)]))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(20)),
                      child: Text('${wardCounts[index]} रिकॉर्ड', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF173D36))),
                    ),
                  ])),
                  if (selected) const Positioned(right: 8, top: 8, child: Icon(Icons.check_circle, color: Color(0xFF0878F9), size: 22)),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: Text(showingResults ? 'खोज परिणाम' : 'हाल के रिकॉर्ड', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
          Text('${shown.length}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _quickStatusChip('सभी', 'All records', total),
            const SizedBox(width: 7),
            _quickStatusChip('सक्रिय', 'Active only', activeCount),
            const SizedBox(width: 7),
            _quickStatusChip('जाँच बाकी', 'Flagged only', flaggedCount),
            const SizedBox(width: 7),
            _quickStatusChip('हटाए गए', 'Deleted only', deletedCount),
          ]),
        ),
        const SizedBox(height: 13),
        if (shown.isEmpty)
          Card(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(children: [
              Icon(Icons.person_search_rounded, size: 42, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text('कोई रिकॉर्ड नहीं मिला', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('अपनी खोज या वार्ड फ़िल्टर बदलकर देखें', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ]),
          ))
        else
          ...shown.take(showingResults || showAllHomeRecords ? shown.length : 12).map(recordCard),
        if (!showingResults && shown.length > 12)
          Center(child: TextButton.icon(
            onPressed: () => setState(() => showAllHomeRecords = !showAllHomeRecords),
            icon: Icon(showAllHomeRecords ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(showAllHomeRecords ? 'कम रिकॉर्ड दिखाएँ' : 'और ${shown.length - 12} रिकॉर्ड देखें'),
          )),
      ],
      ),
    );
  }

  Widget _homeStat(String label, String value, IconData icon, Color color, bool dark) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101F31) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 7),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Widget _quickStatusChip(String label, String value, int count) {
    final selected = status == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => status = value),
      label: Text('$label $count'),
      avatar: selected ? const Icon(Icons.check_rounded, size: 15) : null,
    );
  }

  Widget recordCard(Voter v) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final initial = v.name.trim().isEmpty ? '•' : v.name.trim().substring(0, 1);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (_) => detailSheet(v),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 54,
                  height: 60,
                  child: v.hasPhoto
                      ? FutureBuilder<Uint8List?>(
                          future: _photoFutures.putIfAbsent(v.id, () => _loadVoterPhoto(v.id)),
                          builder: (context, snapshot) {
                            final bytes = snapshot.data;
                            if (bytes != null && bytes.isNotEmpty) {
                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => _photoPlaceholder(initial, theme, dark),
                              );
                            }
                            return _photoPlaceholder(initial, theme, dark);
                          },
                        )
                      : _photoPlaceholder(initial, theme, dark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            v.name.trim().isEmpty ? 'Name unavailable' : v.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        badge(v.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Voter ID  ·  ${v.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.relative.trim().isEmpty ? 'Relative name unavailable' : v.relative,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _recordMeta(Icons.location_on_outlined, 'Ward ${v.ward}'),
                        _recordMeta(Icons.numbers_rounded, 'Serial ${v.serial}'),
                        _recordMeta(Icons.cake_outlined, v.age > 0 ? 'Age ${v.age}' : 'Age —'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
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
    final wardNumber = int.tryParse(v.ward.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final wardIndex = wardNumber.clamp(1, 13);
    final themePath = "assets/ward_themes/ward_${wardIndex.toString().padLeft(2, '0')}.png";
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
                    _voterHeroCard(v, themePath, sheetContext),
                    const SizedBox(height: 14),
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

  Widget _voterHeroCard(Voter v, String themePath, BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final initial = v.name.trim().isEmpty ? '•' : v.name.trim().substring(0, 1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 224,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset(
            themePath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.image_not_supported_outlined, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Container(color: (dark ? Colors.black : Colors.white).withValues(alpha: .06)),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 22, bottom: 22),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 104,
                  height: 124,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    border: Border.all(color: Colors.white, width: 4),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: v.hasPhoto
                    ? FutureBuilder<Uint8List?>(
                        future: _photoFutures.putIfAbsent(v.id, () => _loadVoterPhoto(v.id)),
                        builder: (context, snapshot) {
                          final bytes = snapshot.data;
                          if (bytes != null && bytes.isNotEmpty) return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
                          return Center(child: Text(initial, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)));
                        },
                      )
                    : Center(child: Text(initial, style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: theme.colorScheme.primary))),
                ),
              ),
            ),
          ),
          Positioned(left: 134, right: 12, top: 66, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.name.isEmpty ? 'नाम उपलब्ध नहीं' : v.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF153C2E), shadows: [Shadow(color: Colors.white70, blurRadius: 8)])),
            const SizedBox(height: 4),
            const Text('पिता / पति का नाम', style: TextStyle(fontSize: 12, color: Color(0xFF344B5B), fontWeight: FontWeight.w600)),
            Text(v.relative.isEmpty ? 'उपलब्ध नहीं' : v.relative, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: Color(0xFF172D25), fontWeight: FontWeight.w800)),
          ])),
          Positioned(left: 132, right: 10, bottom: 12, child: Wrap(spacing: 5, runSpacing: 5, children: [
            _heroPill(Icons.home_rounded, 'वार्ड ${wardLabel(v.ward)}'),
            _heroPill(Icons.tag_rounded, '${v.serial}'),
            if (v.age > 0) _heroPill(Icons.cake_rounded, '${v.age} वर्ष'),
          ])),
        ]),
      ),
    );
  }

  String wardLabel(String value) {
    final number = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    return number == null ? value : number.toString().padLeft(2, '0');
  }

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
    _detailDataRow(Icons.location_on_outlined, 'वार्ड', wardLabel(v.ward)),
    _detailDataRow(Icons.numbers_rounded, 'क्रम संख्या', '${v.serial}'),
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

  Widget _detailDataRow(IconData icon, String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary)),
      const SizedBox(width: 10),
      SizedBox(width: 112, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      if (copy) IconButton(visualDensity: VisualDensity.compact, onPressed: () => Clipboard.setData(ClipboardData(text: value)), icon: const Icon(Icons.copy_rounded, size: 17)),
    ]),
  );

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
              label: const Text('Sync latest database')),
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
