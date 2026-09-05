import 'package:flutter/material.dart';

import '../data/mock_data.dart' as mock;
import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../widgets/japan_map_panel.dart';
import '../widgets/route_card.dart';
import '../widgets/stat_tile.dart';

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

  Future<void> _load() async {
    final routes = await _repo.getRoutes();
    final progressByRoute = <String, UserRouteProgress>{};
    final statusByRoute = <String, RouteStatus>{};
    for (final route in routes) {
      final progress = await _repo.getProgress(route.routeId);
      if (progress != null) progressByRoute[route.routeId] = progress;
      statusByRoute[route.routeId] = await _repo.routeStatusOf(route.routeId);
    }
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

  List<NationalRoute> get _filteredRoutes {
    return _routes.where((r) {
      final regionOk = _region == null || r.region == _region;
      final statusOk = _status == null || _statusOf(r.routeId) == _status;
      return regionOk && statusOk;
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
      child: SafeArea(
        top: false,
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
                  if (_region != null)
                    GestureDetector(
                      onTap: () => setState(() => _region = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurfaceRaised,
                          borderRadius: BorderRadius.circular(AppColors.radiusFull),
                        ),
                        child: Text(
                          '${regionLabel[_region]}のみ表示 ×',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.routeSignBlue),
                        ),
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
                    child: StatTile(
                      label: '制覇路線数',
                      value: '$_completedCount / ${mock.nationalRouteCount}',
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
              child: _buildMapPanel(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: _buildStatusTabs(),
            ),
            Expanded(child: _buildRouteList(filtered)),
          ],
        ),
      ),
    );
  }

  /// 実際の地図（簡易日本地図）で地方ごとの位置・状況を確認できるパネル。
  /// 海に見立てた水色グラデーションの上に、地方ごとの島を配置する（Googleマップ風）。
  Widget _buildMapPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusLg),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.5, -1),
            end: Alignment(0.5, 1),
            colors: [AppColors.mapWaterTop, AppColors.mapWaterMid, AppColors.mapWaterBottom],
          ),
          border: Border.all(color: AppColors.mapWaterBorder),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                JapanMapPanel(
                  routes: _routes,
                  activeRegion: _region,
                  onSelectRegion: (region) => setState(() => _region = region),
                  statusOf: _statusOf,
                ),
                // Googleマップ風の装飾チロム（ズームボタン／縮尺）。実際の拡大縮小機能は持たない。
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: _buildZoomControls(),
                ),
                Positioned(
                  left: 4,
                  bottom: 6,
                  child: _buildScaleBar(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomControls() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Color(0x47142838), blurRadius: 6)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _zoomBtn('+', showBorder: true),
            _zoomBtn('−', showBorder: false),
          ],
        ),
      ),
    );
  }

  Widget _zoomBtn(String label, {required bool showBorder}) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: showBorder ? const Border(bottom: BorderSide(color: Color(0xFFE4E4E4))) : null,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF444444))),
    );
  }

  Widget _buildScaleBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 20, height: 2, color: AppColors.mapLabel),
        const SizedBox(width: 4),
        const Text('100km', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.mapLabel)),
      ],
    );
  }

  Widget _buildLegend() {
    Widget dot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      children: [
        dot(AppColors.routeInactive, '未走破'),
        dot(AppColors.routeSignBlue, '挑戦中'),
        dot(AppColors.accentGold, '完走'),
      ],
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

  Widget _buildRouteList(List<NationalRoute> filtered) {
    if (filtered.isEmpty) {
      return const Center(
        child: Text('該当する路線がありません', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final r = filtered[index];
        return RouteCard(route: r, progress: _progressByRoute[r.routeId]);
      },
    );
  }
}
