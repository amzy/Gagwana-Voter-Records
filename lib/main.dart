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
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1769FF), brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF080D14) : const Color(0xFFF4F7FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF111923) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A2635) : const Color(0xFFF2F5FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );
  }
}

enum Status { active, flagged, deleted }

class Voter {
  const Voter(this.id, this.serial, this.ward, this.name, this.relative, this.age, this.status,
      {this.pdf = 'Ward_05_Voter_List.pdf', this.page = 5});
  final String id, ward, name, relative, pdf;
  final int serial, age, page;
  final Status status;
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
      );
    }).toList();
    if (!mounted) return;
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
    final pattern = RegExp('(?:$labelPattern)\\s*[:：-]\\s*(.*?)(?=\\s*(?:$nextLabels)\\s*[:：-]|\\n|$)', multiLine: true, dotAll: true);
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
          child: tab == 0 ? searchScreen() : importScreen()))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'Import PDFs'),
        ]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(
        onPressed: pickPdf, icon: const Icon(Icons.upload_file), label: const Text('Upload PDFs')) : null,
    );
  }

  Widget searchScreen() => ListView(padding: const EdgeInsets.fromLTRB(16,12,16,90), children: [
    Text('Search voter records', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Search by voter name, relative name, voter ID, or serial number. Voter data remains in Hindi.'),
    const SizedBox(height: 16),
    TextField(controller: search, onChanged: (_) => setState(() {}),
      decoration: InputDecoration(hintText: 'Search name, relative, voter ID, or serial…', prefixIcon: const Icon(Icons.search),
        suffixIcon: search.text.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() {}); }, icon: const Icon(Icons.close)))),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: DropdownButtonFormField<String>(initialValue: ward, decoration: const InputDecoration(labelText: 'Ward'),
        items: ['All wards', ...List.generate(13,(i)=>(i+1).toString().padLeft(2,'0'))]
          .map((s)=>DropdownMenuItem(value:s,child:Text(s=='All wards'?s:'Ward $s'))).toList(),
        onChanged:(v)=>setState(()=>ward=v??'All wards'))),
      const SizedBox(width: 10),
      Expanded(child: DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Record status'),
        items: ['All records','Active only','Flagged only','Deleted only']
          .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
        onChanged:(v)=>setState(()=>status=v??'All records'))),
    ]),
    const SizedBox(height: 16),
    Row(children: [Text('Results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const Spacer(), Text('${filtered.length} records')]),
    const SizedBox(height: 8),
    if (filtered.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No records found')))),
    ...filtered.map(recordCard),
  ]);

  Widget recordCard(Voter v) => Card(margin: const EdgeInsets.only(bottom:10), child: InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (_) => detailSheet(v)),
    child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
      CircleAvatar(radius: 25, backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.onPrimaryContainer)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize:16))),
          badge(v.status)]),
        const SizedBox(height: 4), Text('Relative: ${v.relative}'),
        const SizedBox(height: 5), Text('ID: ${v.id}', style: Theme.of(context).textTheme.bodySmall),
        Text('Ward ${v.ward} • Serial ${v.serial} • Age ${v.age}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      const Icon(Icons.chevron_right),
    ])),
  ));

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
