import 'package:flutter/material.dart';

import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../widgets/japan_map_panel.dart';
import '../widgets/map_legend.dart';
import '../widgets/route_card.dart';
import '../widgets/route_search_field.dart';
import '../widgets/stat_tile.dart';
import 'map_fullscreen_screen.dart';

class MapCollectionScreen extends StatefulWidget {
  const MapCollectionScreen({super.key});

  @override
  State<MapCollectionScreen> createState() => _MapCollectionScreenState();
}

const List<({RouteStatus? key, String label})> _statusTabs = [
  (key: null, label: 'すべて'),
  (key: RouteStatus.inProgress, label: '挑戦中'),
  (key: RouteStatus.completed, label: '走破済み'),
  (key: RouteStatus.notStarted, label: '未挑戦'),
];

class _MapCollectionScreenState extends State<MapCollectionScreen> {
  final RouteRepository _repo = RouteRepository.instance;

  RegionKey? _region;
  RouteStatus? _status;

  /// 路線の検索語。地図パネルの上の検索欄で入力する。全画面地図
  /// ([MapFullscreenScreen])にも検索欄があり、どちらで変えてももう一方に反映する。
  String _query = '';
  final TextEditingController _queryController = TextEditingController();

  bool _loading = true;
  List<NationalRoute> _routes = const [];
  Map<String, UserRouteProgress> _progressByRoute = const {};
  Map<String, RouteStatus> _statusByRoute = const {};
  int _completedCount = 0;
  double _cumulativeKm = 0;
  double _coverage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// 検索語を変える。全画面地図から変えられたときは検索欄の文字も揃える。
  void _setQuery(String query, {bool updateField = false}) {
    setState(() => _query = query);
    if (updateField && _queryController.text != query) {
      // text= だけだとカーソル位置が消えるので、末尾に置き直す。
      _queryController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }
  }

  Future<void> _load() async {
    final routes = await _repo.getRoutes();
    // 459路線ぶんを1路線ずつ問い合わせると起動が遅くなるため、進捗はまとめて取る。
    final progressByRoute = await _repo.getProgressByRoute();
    final statusByRoute = {
      for (final route in routes)
        route.routeId: RouteRepository.statusOfProgress(progressByRoute[route.routeId]),
    };
    final completedCount = await _repo.completedRouteCount();
    final cumulativeKm = await _repo.cumulativeDistanceKm();
    final coverage = await _repo.coverageRatio();

    if (!mounted) return;
    setState(() {
      _routes = routes;
      _progressByRoute = progressByRoute;
      _statusByRoute = statusByRoute;
      _completedCount = completedCount;
      _cumulativeKm = cumulativeKm;
      _coverage = coverage;
      _loading = false;
    });
  }

  RouteStatus _statusOf(String routeId) => _statusByRoute[routeId] ?? RouteStatus.notStarted;

  bool get _searching => _query.trim().isNotEmpty;

  /// 一覧に出す路線。検索中は地図と同じく地方の絞り込みは効かせない
  /// (「神奈川」で探しているのに関東以外が消える、という混乱を避ける)。
  /// ステータスのタブは検索中も効く。
  List<NationalRoute> get _filteredRoutes {
    return _routes.where((r) {
      final regionOk = _searching || _region == null || r.region == _region;
      final statusOk = _status == null || _statusOf(r.routeId) == _status;
      return regionOk && statusOk && routeMatchesQuery(r, _query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppColors.bgSurface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue)),
      );
    }

    final filtered = _filteredRoutes;

    return Container(
      color: AppColors.bgSurface,
      // 注: ノッチ／ステータスバーの回避は常に画面最上部にあるdev-navが
      // 既に確保しているため、ここではボトムのみ対応する。
      //
      // 画面全体を1つのスクロールにしている(見出し・統計・検索欄・地図・タブも
      // 一覧と一緒にスクロールする)。検索欄でキーボードが出ると縦が足りなく
      // なるが、スクロールできれば検索欄と地図を並べて見られるため。
      // 地図の上でのドラッグは地図側が受け取る(JapanMapPanel 参照)ので、
      // スクロールは地図以外の場所で行う。
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        const Text(
                          '走破・地図コレクション',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                        ),
                        const Spacer(),
                        // 検索中は地方の絞り込みを効かせないので、チップも出さない。
                        // 幅の狭い端末で見出しと並べてもはみ出さないよう Flexible に。
                        if (_region != null && !_searching)
                          Flexible(
                            child: _buildChip('${regionLabel[_region]}のみ表示 ×', onTap: () => setState(() => _region = null)),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            label: '制覇路線数',
                            value: '$_completedCount / ${_routes.length}',
                            valueFontSize: 17,
                            centered: true,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatTile(
                            label: '累計走行距離',
                            value: '${_cumulativeKm.toStringAsFixed(1)}km',
                            valueFontSize: 17,
                            centered: true,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatTile(
                            label: 'カバー率',
                            value: '${(_coverage * 100).toStringAsFixed(2)}%',
                            valueFontSize: 17,
                            centered: true,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: RouteSearchField(
                            controller: _queryController,
                            onChanged: _setQuery,
                          ),
                        ),
                        if (_searching) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${filtered.length}路線',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _buildMapPanel(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: _buildStatusTabs(),
                  ),
                ],
              ),
            ),
            _buildRouteList(filtered),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceRaised,
          borderRadius: BorderRadius.circular(AppColors.radiusFull),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.routeSignBlue),
        ),
      ),
    );
  }

  /// 地図を画面いっぱいに表示する。地方の選択と検索語は全画面側で変えても
  /// この画面に即時に反映される（[MapFullscreenScreen.onSelectRegion] /
  /// [MapFullscreenScreen.onQueryChanged]）。
  void _openFullscreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapFullscreenScreen(
          routes: _routes,
          initialRegion: _region,
          onSelectRegion: (region) => setState(() => _region = region),
          statusOf: _statusOf,
          initialQuery: _query,
          onQueryChanged: (query) => _setQuery(query, updateField: true),
        ),
      ),
    );
  }

  /// MapLibre GLによる実地図で地方ごとの位置・状況を確認できるパネル。
  Widget _buildMapPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: AppColors.mapWaterBorder)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
                child: JapanMapPanel(
                  routes: _routes,
                  activeRegion: _region,
                  onSelectRegion: (region) => setState(() => _region = region),
                  statusOf: _statusOf,
                  onRequestFullscreen: _openFullscreenMap,
                  searchQuery: _query,
                ),
              ),
              const SizedBox(height: 8),
              const MapLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Row(
        children: _statusTabs.map((tab) {
          final active = _status == tab.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _status = tab.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.routeSignGradient : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 一覧部分(スライバー)。[CustomScrollView] の中で見出しや地図と一緒にスクロールする。
  Widget _buildRouteList(List<NationalRoute> filtered) {
    if (filtered.isEmpty) {
      return const SliverPadding(
        padding: EdgeInsets.symmetric(vertical: 40),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: Text('該当する路線がありません', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      sliver: SliverList.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final r = filtered[index];
          return RouteCard(route: r, progress: _progressByRoute[r.routeId]);
        },
      ),
    );
  }
}
