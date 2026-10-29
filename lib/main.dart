import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(backgroundColor: Color(0xFFFF626B), child: Icon(Icons.groups_rounded, color: Colors.white)),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gagwana', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Voter Records', style: TextStyle(fontSize: 12)),
          ]),
        ]),
        actions: [IconButton(
          tooltip: dark ? 'Light mode' : 'Dark mode',
          onPressed: () => widget.onTheme(!dark),
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded)),
          const SizedBox(width: 8)],
      ),
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
            children: [searchScreen(), importScreen()],
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
    final activeFilters = (ward != 'All wards' ? 1 : 0) + (status != 'All records' ? 1 : 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text('Find a voter', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.7)),
        const SizedBox(height: 6),
        Text('Search names, voter IDs and serial numbers', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 22),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Name, voter ID or serial number',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: search.text.isEmpty ? null : IconButton(
              tooltip: 'Clear search',
              onPressed: () { search.clear(); setState(() {}); },
              icon: const Icon(Icons.close_rounded)),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _showFilters,
          icon: const Icon(Icons.tune_rounded),
          label: Text(activeFilters == 0 ? 'Filters' : 'Filters · $activeFilters active'),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Search results', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(activeFilters == 0 ? 'All wards · All statuses' : '${ward == 'All wards' ? 'All wards' : 'Ward $ward'} · $status',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(30)),
            child: Text('${filtered.length}', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSecondaryContainer)),
          ),
        ]),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(children: [
                Icon(Icons.person_search_rounded, size: 42, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('No voters found', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Try another name or adjust your filters.', textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ...filtered.map(recordCard),
      ],
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

  Widget detailSheet(Voter v) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(20,8,20,MediaQuery.viewInsetsOf(context).bottom+24),
    child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children: [
      Text('Voter details', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:16),
      const Center(child: CircleAvatar(radius:42, child: Icon(Icons.person,size:48))),
      const SizedBox(height:10),
      Center(child: Text(v.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),
      const SizedBox(height:14),
      detailRow('Voter ID',v.id), detailRow('Serial number','${v.serial}'), detailRow('Ward',v.ward),
      detailRow('Name',v.name), detailRow('Relative name',v.relative), detailRow('Age','${v.age}'),
      detailRow('Status',v.status == Status.active ? 'Active' : v.status == Status.flagged ? 'Flagged — review required' : 'Deleted — explicit PDF mark'),
      detailRow('Source','${v.pdf}, page ${v.page}'),
    ])),
  ));

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
