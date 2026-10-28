import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
    title: 'गागवाना • मतदाता सूची',
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
  String ward = 'सभी वार्ड', status = 'सभी रिकॉर्ड';
  String? pdfName;

  List<Voter> get filtered => records.where((v) {
    final q = search.text.trim().toLowerCase();
    final textMatch = q.isEmpty || v.id.toLowerCase().contains(q) ||
      v.name.toLowerCase().contains(q) || v.relative.toLowerCase().contains(q) ||
      '${v.serial}'.contains(q);
    final wardMatch = ward == 'सभी वार्ड' || v.ward == ward;
    final statusMatch = status == 'सभी रिकॉर्ड' ||
      (status == 'केवल सक्रिय' && v.status == Status.active) ||
      (status == 'केवल Flagged' && v.status == Status.flagged) ||
      (status == 'केवल Deleted' && v.status == Status.deleted);
    return textMatch && wardMatch && statusMatch;
  }).toList();

  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.isEmpty) return;
    setState(() { pdfName = result.files.single.name; tab = 1; });
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
            Text('गागवाना', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('मतदाता सूची', style: TextStyle(fontSize: 12)),
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
            NavigationRailDestination(icon: Icon(Icons.search), label: Text('खोजें')),
            NavigationRailDestination(icon: Icon(Icons.picture_as_pdf), label: Text('PDF / OCR')),
          ]),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: tab == 0 ? searchScreen() : importScreen()))),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'खोजें'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf), label: 'PDF / OCR'),
        ]),
      floatingActionButton: tab == 0 ? FloatingActionButton.extended(
        onPressed: pickPdf, icon: const Icon(Icons.upload_file), label: const Text('PDF अपलोड')) : null,
    );
  }

  Widget searchScreen() => ListView(padding: const EdgeInsets.fromLTRB(16,12,16,90), children: [
    Text('मतदाता खोजें', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('नाम, पिता/पति का नाम, वोटर ID या क्रम संख्या खोजें'),
    const SizedBox(height: 16),
    TextField(controller: search, onChanged: (_) => setState(() {}),
      decoration: InputDecoration(hintText: 'नाम या वोटर ID खोजें…', prefixIcon: const Icon(Icons.search),
        suffixIcon: search.text.isEmpty ? null : IconButton(onPressed: () { search.clear(); setState(() {}); }, icon: const Icon(Icons.close)))),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: DropdownButtonFormField<String>(initialValue: ward, decoration: const InputDecoration(labelText: 'वार्ड'),
        items: ['सभी वार्ड', ...List.generate(13,(i)=>(i+1).toString().padLeft(2,'0'))]
          .map((s)=>DropdownMenuItem(value:s,child:Text(s=='सभी वार्ड'?s:'वार्ड $s'))).toList(),
        onChanged:(v)=>setState(()=>ward=v??'सभी वार्ड'))),
      const SizedBox(width: 10),
      Expanded(child: DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'स्थिति'),
        items: ['सभी रिकॉर्ड','केवल सक्रिय','केवल Flagged','केवल Deleted']
          .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
        onChanged:(v)=>setState(()=>status=v??'सभी रिकॉर्ड'))),
    ]),
    const SizedBox(height: 16),
    Row(children: [Text('परिणाम', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const Spacer(), Text('${filtered.length} रिकॉर्ड')]),
    const SizedBox(height: 8),
    if (filtered.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('कोई रिकॉर्ड नहीं मिला')))),
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
        const SizedBox(height: 4), Text('पिता/पति: ${v.relative}'),
        const SizedBox(height: 5), Text('ID: ${v.id}', style: Theme.of(context).textTheme.bodySmall),
        Text('वार्ड ${v.ward} • क्रम संख्या ${v.serial} • आयु ${v.age}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      const Icon(Icons.chevron_right),
    ])),
  ));

  Widget badge(Status s) {
    final c = s == Status.active ? const Color(0xFF16A765) : s == Status.flagged ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final label = s == Status.active ? 'सक्रिय' : s == Status.flagged ? 'Flagged' : 'Deleted';
    return Container(padding: const EdgeInsets.symmetric(horizontal:9,vertical:5),
      decoration: BoxDecoration(color:c.withValues(alpha:.14),borderRadius:BorderRadius.circular(30)),
      child: Text(label, style: TextStyle(color:c,fontWeight:FontWeight.w700,fontSize:11)));
  }

  Widget detailSheet(Voter v) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(20,8,20,MediaQuery.viewInsetsOf(context).bottom+24),
    child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children: [
      Text('मतदाता विवरण', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:16),
      const Center(child: CircleAvatar(radius:42, child: Icon(Icons.person,size:48))),
      const SizedBox(height:10),
      Center(child: Text(v.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))),
      const SizedBox(height:14),
      detailRow('वोटर ID',v.id), detailRow('क्रम संख्या','${v.serial}'), detailRow('वार्ड',v.ward),
      detailRow('नाम',v.name), detailRow('पिता/पति का नाम',v.relative), detailRow('आयु','${v.age}'),
      detailRow('स्थिति',v.status == Status.active ? 'सक्रिय' : v.status == Status.flagged ? 'Flagged — सत्यापन आवश्यक' : 'Deleted — PDF mark'),
      detailRow('स्रोत','${v.pdf}, पृष्ठ ${v.page}'),
    ])),
  ));

  Widget detailRow(String label,String value) => Padding(padding: const EdgeInsets.symmetric(vertical:8),
    child: Row(children: [SizedBox(width:135, child: Text(label, style: TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight:FontWeight.w600)))]));

  Widget importScreen() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('PDF अपलोड / रिकॉर्ड अपडेट', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),
    const SizedBox(height:8),
    const Text('PDF चुनें, OCR परिणामों की समीक्षा करें, और पुष्टि के बाद ही मास्टर सूची अपडेट करें।'),
    const SizedBox(height:18),
    Card(child: InkWell(onTap:pickPdf, borderRadius:BorderRadius.circular(20), child: Padding(
      padding: const EdgeInsets.all(28), child: Column(children: [
        Icon(Icons.cloud_upload_rounded,size:52,color:Theme.of(context).colorScheme.primary),
        const SizedBox(height:12),
        Text(pdfName ?? 'वोटर सूची PDF चुनें',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:6), const Text('यहाँ टैप करके PDF चुनें'),
      ])))),
    const SizedBox(height:16),
    Card(child: Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('OCR सेटिंग',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.bold)),
      const ListTile(leading:Icon(Icons.translate),title:Text('हिंदी — Devanagari / Mangal Unicode')),
      const SwitchListTile(value:true,onChanged:null,title:Text('PDF से वोटर फोटो निकालें')),
      const SwitchListTile(value:true,onChanged:null,title:Text('स्पष्ट DELETED mark पहचानें')),
      const SwitchListTile(value:true,onChanged:null,title:Text('अनिश्चित OCR को Flag करें')),
    ]))),
    const SizedBox(height:14),
    FilledButton.icon(onPressed:pdfName == null ? null : () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content:Text('PDF चुनी गई है। वास्तविक OCR और Google Sheets API जोड़ना बाकी है।'))),
      icon:const Icon(Icons.document_scanner),label:const Text('OCR और समीक्षा शुरू करें')),
    const SizedBox(height:10),
    const Card(child:Padding(padding:EdgeInsets.all(14),child:Text(
      'यह starter UI PDF चुन सकता है, लेकिन OCR, फोटो extraction, Google Sheets sync और सुरक्षित import preview के लिए backend/API integration आवश्यक है.'))),
  ]);
}
