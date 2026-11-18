import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'data/store_base.dart';
import 'services/updates.dart';

const ink = Color(0xffe6e6e8);
const accent = Color(0xff2680ff);
const panel = Color(0xff27282d);
const paper = Color(0xff1e1e1e);
const muted = Color(0xff9a9a9f);
const line = Color(0xff39393f);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AzikApp());
}

class AzikApp extends StatelessWidget {
  final LibraryStore? store;
  const AzikApp({super.key, this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Azık — Bilgi yanında.',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: Color(0xff254a80),
      ),
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        brightness: Brightness.dark,
        surface: paper,
      ),
      fontFamily: 'Arial',
      visualDensity: VisualDensity.compact,
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
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
  final LibraryStore? store;
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
      if (await store.version() == 0) {
        await store.install(
          await rootBundle.loadString('assets/content/temel.json'),
        );
      }
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
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Kütüphane açılamadı. Depolama alanını kontrol edip yeniden dene.';
        });
      }
    }
  }

  Future<void> toggle(String key, String id) async {
    final current = key == 'saved' ? saved : checked;
    final next = {...current};
    next.contains(id) ? next.remove(id) : next.add(id);
    try {
      if (!await prefs!.setStringList(key, next.toList())) {
        throw StateError('save');
      }
      if (mounted) {
        setState(() {
          if (key == 'saved') {
            saved = next;
          } else {
            checked = next;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Değişiklik kaydedilemedi. Yeniden dene.'),
          ),
        );
      }
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
      if (mounted) {
        setState(() {
          available = result;
          updateMessage = result == null
              ? 'İndirilebilir daha yeni bir içerik paketi yok.'
              : 'Temel kütüphane v${result.version} hazır. ${(result.size / 1024).ceil()} KB indirilecek.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          updateMessage = e is UpdateFailure
              ? e.message
              : 'Kontrol tamamlanamadı. Bağlantını kontrol edip yeniden dene.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
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
      if (mounted) {
        setState(() {
          guides = list;
          version = v;
          available = null;
          category = 'Tümü';
          updateMessage =
              'Kütüphane güncellendi. İçerikler çevrimdışı kullanıma hazır.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          updateMessage = e is UpdateFailure
              ? e.message
              : 'Güncelleme tamamlanamadı. Mevcut kütüphane korundu.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
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
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error.isNotEmpty) {
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
    }
    final wide = MediaQuery.sizeOf(context).width >= 760;
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
                      padding: EdgeInsets.fromLTRB(
                        wide ? 40 : 20,
                        26,
                        wide ? 40 : 20,
                        30,
                      ),
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

  Widget brand() => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.menu_book_rounded, size: 21, color: accent),
      SizedBox(width: 9),
      Text(
        'Azık',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
      ),
    ],
  );

  Widget sidebar() => Container(
    width: 230,
    margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
    decoration: BoxDecoration(
      color: const Color(0xff25272e),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: line),
    ),
    padding: const EdgeInsets.fromLTRB(10, 20, 10, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: brand(),
        ),
        const SizedBox(height: 24),
        navItem(0, Icons.menu_book_outlined, 'Kütüphane'),
        navItem(2, Icons.bookmark_border, 'Kaydedilenler'),
        navItem(1, Icons.checklist_rounded, 'Hazırlığım'),
        const Spacer(),
        navItem(3, Icons.tune_rounded, 'Paketler ve güncellemeler'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 8, 4),
          child: Row(
            children: [
              const Icon(Icons.offline_pin_outlined, size: 16, color: accent),
              const SizedBox(width: 10),
              const SizedBox(width: 0),
              Expanded(
                child: Text(
                  kIsWeb ? 'Web önizlemesi' : 'Çevrimdışı hazır',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget navItem(int i, IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Material(
      color: page == i ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () => setState(() {
          page = i;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 19, color: page == i ? Colors.white : accent),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: page == i ? Colors.white : ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget header(bool wide) => SizedBox(
    height: 48,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 26 : 20),
      child: Row(
        children: [
          if (!wide)
            brand()
          else ...[
            const Icon(Icons.folder_open_outlined, size: 16, color: muted),
            const SizedBox(width: 9),
            const Text('Azık', style: TextStyle(color: muted, fontSize: 12)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('/', style: TextStyle(color: line)),
            ),
            Text(switch (page) {
              1 => 'Hazırlığım',
              2 => 'Kaydedilenler',
              3 => 'Paketler',
              _ => 'Kütüphane',
            }, style: const TextStyle(fontSize: 12, color: muted)),
          ],
          const Spacer(),
          const Icon(Icons.check_circle_outline, size: 14, color: muted),
          const SizedBox(width: 7),
          Text(
            '${guides.length} rehber cihazında',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
    ),
  );

  Widget heading(String eyebrow, String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ink,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 15, height: 1.5, color: muted),
      ),
      const SizedBox(height: 22),
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
    final grouped = query.trim().isEmpty && category == 'Tümü' && !savedOnly;
    final primary = filtered
        .where((g) => g.category != 'Dijital hazırlık')
        .toList();
    final digital = filtered
        .where((g) => g.category == 'Dijital hazırlık')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          '',
          savedOnly ? 'Kaydedilenler' : 'Kütüphane',
          savedOnly
              ? 'Daha sonra okumak için ayırdığın rehberler.'
              : 'Hazırlık, iletişim ve günlük yaşam için Türkçe rehberler.',
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: TextField(
            controller: search,
            onChanged: (v) => setState(() {
              query = v;
            }),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: muted, size: 22),
              hintText: 'Kütüphanede ara',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 19,
              ),
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
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
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
                selectedColor: const Color(0xff263e5d),
                backgroundColor: paper,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: category == c ? const Color(0xff80b7ff) : muted,
                ),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: category == c ? const Color(0xff3b608b) : line,
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Rehber bulunamadı. Aramayı veya kategori filtresini değiştirebilirsin.',
              style: TextStyle(color: muted),
            ),
          ),
        if (grouped) ...[
          sectionTitle(
            'Başlangıç rehberleri',
            'Planını oluştur, ihtiyaçlarını gözden geçir.',
            primary.length,
          ),
          guideGrid(primary),
          const SizedBox(height: 32),
          sectionTitle(
            'Dijital hazırlık',
            'Belgelerin ve bilgilerin bağlantı olmadan da yanında olsun.',
            digital.length,
          ),
          guideGrid(digital),
        ] else if (filtered.isNotEmpty) ...[
          sectionTitle(
            savedOnly ? 'Kaydettiğin rehberler' : 'Arama sonuçları',
            '',
            filtered.length,
          ),
          guideGrid(filtered),
        ],
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          'Temel kütüphane · Genel hazırlık notları · Uzman incelemesi bekliyor',
          style: TextStyle(fontSize: 11, color: muted),
        ),
      ],
    );
  }

  Widget sectionTitle(String title, String subtitle, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$count rehber',
          style: const TextStyle(color: accent, fontSize: 12),
        ),
      ],
    ),
  );

  Widget guideGrid(List<Guide> items) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? 4
          : constraints.maxWidth >= 690
          ? 3
          : constraints.maxWidth >= 460
          ? 2
          : 1;
      return Wrap(
        spacing: 16,
        runSpacing: 22,
        children: [
          for (final g in items)
            SizedBox(
              width: (constraints.maxWidth - (columns - 1) * 16) / columns,
              child: guideCard(g),
            ),
        ],
      );
    },
  );

  IconData categoryIcon(String c) => switch (c) {
    'İletişim' => Icons.forum_outlined,
    'Enerji' => Icons.battery_charging_full,
    'Dijital hazırlık' => Icons.folder_copy_outlined,
    _ => Icons.backpack_outlined,
  };

  Widget guideCard(Guide g) {
    final color = switch (g.category) {
      'İletişim' => const Color(0xff364f69),
      'Enerji' => const Color(0xff695436),
      'Dijital hazırlık' => const Color(0xff414866),
      _ => const Color(0xff466152),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => showGuide(g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.85,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, const Color(0xff252a33)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      bottom: -18,
                      child: Icon(
                        categoryIcon(g.category),
                        size: 135,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Positioned(
                      left: 17,
                      top: 18,
                      child: Icon(
                        categoryIcon(g.category),
                        size: 33,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    Positioned(
                      right: 3,
                      top: 3,
                      child: IconButton(
                        tooltip: saved.contains(g.id)
                            ? 'Kaydedilenlerden çıkar'
                            : 'Rehberi kaydet',
                        onPressed: () => toggle('saved', g.id),
                        icon: Icon(
                          saved.contains(g.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 12,
                      child: Text(
                        g.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.article_outlined,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(g.body.split(RegExp(r'\s+')).length / 180).ceil()} dk',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
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
            const SizedBox(height: 10),
            Text(
              g.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              g.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

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
          color: panel,
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
          color: panel,
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
