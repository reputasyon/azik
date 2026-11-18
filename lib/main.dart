import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'services/updates.dart';

const ink = Color(0xff203b30);
const paper = Color(0xfff7f5ee);
const muted = Color(0xff687369);
const line = Color(0xffdedfd4);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AzikApp());
}

class AzikApp extends StatelessWidget {
  final ContentStore? store;
  const AzikApp({super.key, this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Azık — Bilgi yanında.',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      fontFamily: 'Arial',
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
      ),
    ),
    home: LibraryScreen(store: store),
  );
}

class LibraryScreen extends StatefulWidget {
  final ContentStore? store;
  const LibraryScreen({super.key, this.store});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final store = widget.store ?? ContentStore();
  final updates = UpdateService();
  final search = TextEditingController();
  SharedPreferences? prefs;
  List<Guide> guides = [];
  Set<String> saved = {}, checked = {};
  int page = 0, version = 0;
  String category = 'Tümü', query = '', updateMessage = '', error = '';
  bool loading = true, busy = false;
  PackUpdate? available;
  static const tasks = [
    (
      'plan',
      'Aile iletişim planını yaz',
      'Buluşma noktası ve ulaşılabilecek kişileri birlikte belirle.',
    ),
    (
      'contacts',
      'Önemli numaraları kâğıda geçir',
      'Telefonun çalışmadığı bir durum için basılı kopya hazırla.',
    ),
    (
      'bag',
      'Hazırlık çantanı gözden geçir',
      'Kişisel ihtiyaçları, tarihleri ve eksikleri düzenli kontrol et.',
    ),
    (
      'library',
      'Rehberleri çevrimdışı açmayı dene',
      'İnterneti kapatıp ihtiyaç duyduğun bilgilere ulaşabildiğini kontrol et.',
    ),
    (
      'power',
      'Şarj ekipmanını kontrol et',
      'Taşınabilir şarj cihazı ve uyumlu kabloların yerini belirle.',
    ),
    (
      'review',
      'Bir sonraki kontrol tarihini belirle',
      'Planını evdeki herkesin bildiğinden emin ol.',
    ),
  ];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    updates.close();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      await store.open();
      if (await store.version() == 0)
        await store.install(
          await rootBundle.loadString('assets/content/temel.json'),
        );
      final p = await SharedPreferences.getInstance();
      final list = await store.guides();
      final v = await store.version();
      if (!mounted) return;
      setState(() {
        prefs = p;
        guides = list;
        version = v;
        saved = (p.getStringList('saved') ?? []).toSet();
        checked = (p.getStringList('checked') ?? []).toSet();
        loading = false;
        error = '';
      });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'Kütüphane açılamadı. Depolama alanını kontrol edip yeniden dene.';
        });
    }
  }

  Future<void> toggle(String key, String id) async {
    final current = key == 'saved' ? saved : checked;
    final next = {...current};
    next.contains(id) ? next.remove(id) : next.add(id);
    try {
      if (!await prefs!.setStringList(key, next.toList()))
        throw StateError('save');
      if (mounted)
        setState(() {
          if (key == 'saved') {
            saved = next;
          } else {
            checked = next;
          }
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değişiklik kaydedilemedi. Yeniden dene.'),
          ),
        );
    }
  }

  Future<void> checkUpdates() async {
    setState(() {
      busy = true;
      available = null;
      updateMessage = 'GitHub yayın kanalı kontrol ediliyor…';
    });
    try {
      final result = await updates.check(version);
      if (mounted)
        setState(() {
          available = result;
          updateMessage = result == null
              ? 'İndirilebilir daha yeni bir içerik paketi yok.'
              : 'Temel kütüphane v${result.version} hazır. ${(result.size / 1024).ceil()} KB indirilecek.';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          updateMessage = e is UpdateFailure
              ? e.message
              : 'Kontrol tamamlanamadı. Bağlantını kontrol edip yeniden dene.';
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  Future<void> installUpdate() async {
    final update = available;
    if (update == null) return;
    setState(() {
      busy = true;
      updateMessage = 'Paket indiriliyor ve doğrulanıyor…';
    });
    try {
      await store.install(await updates.download(update));
      final list = await store.guides();
      final v = await store.version();
      if (mounted)
        setState(() {
          guides = list;
          version = v;
          available = null;
          category = 'Tümü';
          updateMessage =
              'Kütüphane güncellendi. İçerikler çevrimdışı kullanıma hazır.';
        });
    } catch (e) {
      if (mounted)
        setState(() {
          updateMessage = e is UpdateFailure
              ? e.message
              : 'Güncelleme tamamlanamadı. Mevcut kütüphane korundu.';
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  void showGuide(Guide g) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: paper,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        g.category.toUpperCase(),
                        style: const TextStyle(
                          color: muted,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Kapat',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        g.summary,
                        style: const TextStyle(
                          fontSize: 17,
                          color: muted,
                          height: 1.5,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(),
                      ),
                      SelectableText(
                        g.body,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.8,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Kaynak: ${g.source}\nLisans: ${g.license}\nGüncelleme: ${g.updated}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error.isNotEmpty)
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error),
              TextButton(onPressed: load, child: const Text('Yeniden dene')),
            ],
          ),
        ),
      );
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide) sidebar(),
            Expanded(
              child: Column(
                children: [
                  header(wide),
                  Expanded(
                    child: SingleChildScrollView(
                      key: ValueKey(page),
                      padding: EdgeInsets.all(wide ? 40 : 20),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: switch (page) {
                            1 => checklist(),
                            2 => library(savedOnly: true),
                            3 => updatePage(),
                            _ => library(),
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (i) => setState(() {
                page = i;
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: 'Kütüphane',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_rounded),
                  label: 'Hazırlığım',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  label: 'Kaydedilen',
                ),
                NavigationDestination(
                  icon: Icon(Icons.downloading_outlined),
                  label: 'Paketler',
                ),
              ],
            ),
    );
  }

  Widget brand() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.spa_outlined,
          color: Color(0xffe4eab9),
          size: 25,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'azık',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
          color: ink,
        ),
      ),
    ],
  );
  Widget sidebar() => Container(
    width: 238,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        brand(),
        const SizedBox(height: 7),
        const Text(
          'BİLGİ YANINDA.',
          style: TextStyle(fontSize: 10, letterSpacing: 3, color: muted),
        ),
        const SizedBox(height: 52),
        for (final (i, icon, label) in [
          (0, Icons.menu_book_outlined, 'Kütüphane'),
          (1, Icons.checklist_rounded, 'Hazırlığım'),
          (2, Icons.bookmark_border, 'Kaydedilenler'),
          (3, Icons.downloading_outlined, 'Paketler & güncelleme'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: page == i ? const Color(0xffe6e9dc) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(icon, color: ink, size: 21),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: ink,
                    fontWeight: page == i ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                onTap: () => setState(() {
                  page = i;
                }),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xffeeeee2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.offline_pin_outlined, size: 23, color: ink),
              const SizedBox(height: 10),
              const Text(
                'İnternetsiz de yanında.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                kIsWeb
                    ? 'Web önizlemesi. Kalıcı çevrimdışı kullanım için cihaz uygulaması.'
                    : 'İndirdiğin rehberler bu cihazda saklanır.',
                style: const TextStyle(fontSize: 12, height: 1.5, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'AÇIK KAYNAK  /  v0.1.0',
          style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted),
        ),
      ],
    ),
  );
  Widget header(bool wide) => Container(
    padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 20, vertical: 17),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!wide)
          brand()
        else
          const Text(
            'AZIK  /  TÜRKÇE YAŞAM KÜTÜPHANESİ',
            style: TextStyle(fontSize: 11, letterSpacing: 1.7, color: muted),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xffe8eddf),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: ink),
              const SizedBox(width: 6),
              Text(
                '${guides.length} rehber cihazında',
                style: const TextStyle(fontSize: 11, color: ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget heading(String eyebrow, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          color: muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          fontSize: 35,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.3,
          color: ink,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 15, height: 1.6, color: muted),
      ),
      const SizedBox(height: 26),
    ],
  );
  Widget library({bool savedOnly = false}) {
    final filtered = guides
        .where(
          (g) =>
              (!savedOnly || saved.contains(g.id)) &&
              (category == 'Tümü' || g.category == category) &&
              g.matches(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!savedOnly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                const Positioned(
                  right: -5,
                  bottom: -15,
                  child: Icon(
                    Icons.landscape_outlined,
                    color: Color(0xff385244),
                    size: 160,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BUGÜNDEN HAZIRLAN.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xffd4dfa3),
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Bağlantı kesilir.\nBilgi yanında kalır.',
                      style: TextStyle(
                        fontSize: 36,
                        color: paper,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Hazırlanmak, küçük bir adımla başlar.\nTürkçe rehberlerini keşfet, kendi planını oluştur.',
                      style: TextStyle(
                        color: Color(0xffc2cec1),
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffdce6ae),
                        foregroundColor: ink,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 17,
                        ),
                      ),
                      onPressed: () => setState(() {
                        page = 1;
                      }),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Hazırlık listeme git'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        heading(
          savedOnly ? 'KİŞİSEL KÜTÜPHANEN' : 'KEŞFET & ÖĞREN',
          savedOnly ? 'Elinin altında.' : 'Bir bilgi, bir adım.',
          savedOnly
              ? 'Kaydettiğin rehberlere buradan ulaş.'
              : 'Temel hazırlık rehberleri. Okumak için bağlantı gerekmez.',
        ),
        TextField(
          controller: search,
          onChanged: (v) => setState(() {
            query = v;
          }),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Rehberlerde ara…',
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Aramayı temizle',
                    onPressed: () {
                      search.clear();
                      setState(() {
                        query = '';
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ['Tümü', ...guides.map((g) => g.category).toSet()])
              ChoiceChip(
                label: Text(c),
                selected: category == c,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  category = c;
                }),
                selectedColor: const Color(0xffe3e9d3),
                labelStyle: const TextStyle(fontSize: 12, color: ink),
                side: const BorderSide(color: line),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '${filtered.length} REHBER',
          style: const TextStyle(fontSize: 10, letterSpacing: 2, color: muted),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 35),
            child: Text(
              'Burada henüz bir rehber yok. Aramayı veya kategori filtresini değiştirebilirsin.',
              style: TextStyle(color: muted),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 680 ? 2 : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final g in filtered)
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 16) / columns,
                    child: guideCard(g),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        const Text(
          'İlk sürüm · Bu kütüphane genel hazırlık içerikleriyle başlıyor. Harita, video ve yerel yapay zekâ sonraki aşamalarda.',
          style: TextStyle(fontSize: 12, height: 1.6, color: muted),
        ),
      ],
    );
  }

  IconData categoryIcon(String c) => switch (c) {
    'İletişim' => Icons.forum_outlined,
    'Enerji' => Icons.battery_charging_full,
    'Dijital hazırlık' => Icons.offline_bolt_outlined,
    _ => Icons.backpack_outlined,
  };
  Widget guideCard(Guide g) => Material(
    color: const Color(0xfffffef9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: line),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => showGuide(g),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffedf0e1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryIcon(g.category), color: ink, size: 24),
                ),
                const Spacer(),
                IconButton(
                  tooltip: saved.contains(g.id)
                      ? 'Kaydedilenlerden çıkar'
                      : 'Rehberi kaydet',
                  onPressed: () => toggle('saved', g.id),
                  icon: Icon(
                    saved.contains(g.id)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              g.category.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: muted,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              g.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              g.summary,
              style: const TextStyle(fontSize: 13, color: muted, height: 1.65),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.offline_pin_outlined, size: 14, color: muted),
                SizedBox(width: 6),
                Text('Cihazında', style: TextStyle(fontSize: 11, color: muted)),
                Spacer(),
                Icon(Icons.arrow_forward, size: 19, color: ink),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  Widget checklist() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'KÜÇÜK ADIMLAR, DAHA İYİ HAZIRLIK',
        'Bugün ne yapabilirim?',
        'Kendi hızında ilerle. İşaretlediğin adımlar yalnızca bu cihazda saklanır.',
      ),
      Text(
        '${checked.intersection(tasks.map((t) => t.$1).toSet()).length} / ${tasks.length} adım tamamlandı',
        style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value:
            checked.intersection(tasks.map((t) => t.$1).toSet()).length /
            tasks.length,
        minHeight: 8,
        borderRadius: BorderRadius.circular(5),
        backgroundColor: line,
      ),
      const SizedBox(height: 24),
      for (final t in tasks)
        Card(
          elevation: 0,
          color: const Color(0xfffffef9),
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: line),
          ),
          child: CheckboxListTile(
            value: checked.contains(t.$1),
            onChanged: (_) => toggle('checked', t.$1),
            title: Text(
              t.$2,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                t.$3,
                style: const TextStyle(fontSize: 13, color: muted, height: 1.5),
              ),
            ),
            contentPadding: const EdgeInsets.all(14),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
    ],
  );
  Widget updatePage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'BİR KEZ İNDİR, YANINDA TAŞI',
        'Kütüphaneni güncel tut.',
        'İçerik paketleri GitHub üzerinden dağıtılır. Mevcut rehberlerin bağlantı olmasa da açılır.',
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: ink),
                SizedBox(width: 12),
                Text(
                  'Temel kütüphane',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Sürüm $version · ${guides.length} Türkçe rehber · Bu cihazda',
              style: const TextStyle(color: muted),
            ),
            const SizedBox(height: 22),
            if (!updates.configured)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: Text(
                  'Önizleme sürümü: GitHub yayın kanalı henüz bağlı değil. Yerel kütüphaneyi kullanabilirsin.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
              ),
            FilledButton.icon(
              onPressed: busy ? null : checkUpdates,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(busy ? 'İşleniyor…' : 'Güncellemeleri kontrol et'),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: LinearProgressIndicator(),
              ),
            if (updateMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  updateMessage,
                  style: const TextStyle(color: ink, height: 1.5),
                ),
              ),
            if (available != null && kIsWeb)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Paket indirme yerel uygulamada kullanılabilir. Web sürümü arayüz önizlemesidir.',
                ),
              ),
            if (available != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: busy || kIsWeb ? null : installUpdate,
                  icon: const Icon(Icons.download),
                  label: const Text('Paketi indir ve yükle'),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'SIRADA NE VAR?',
        style: TextStyle(fontSize: 11, letterSpacing: 2, color: muted),
      ),
      const SizedBox(height: 12),
      for (final item in [
        ('Bölge haritaları', 'İndirilebilir Türkiye haritaları'),
        ('Video kütüphanesi', 'Konu bazında seçilebilir video paketleri'),
        ('Yerel yapay zekâ', 'Cihazında çalışan, kaynak gösteren yardımcı'),
      ])
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.hourglass_empty, color: muted),
          title: Text(item.$1),
          subtitle: Text(item.$2),
          trailing: const Text(
            'Planlandı',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      const SizedBox(height: 24),
      const Text(
        'Gizlilik: Hesap, reklam ve analitik yok. Güncelleme kontrolü yalnızca düğmeye bastığında GitHub’a bağlanır. Web önizlemesi tarayıcı depolamasını kullanır; yerel uygulama kütüphaneyi SQLite içinde tutar.',
        style: TextStyle(color: muted, fontSize: 12, height: 1.7),
      ),
    ],
  );
}
