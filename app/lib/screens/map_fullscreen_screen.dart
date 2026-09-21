import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../widgets/japan_map_panel.dart';
import '../widgets/map_legend.dart';
import '../widgets/route_search_field.dart';

/// 走破・地図コレクションの地図を画面いっぱいに表示する画面。
///
/// パネルの地図をタップ（または右上の全画面ボタン）で開く。地方の選択と
/// 検索語はこの画面内でも変えられ、変更は [onSelectRegion] / [onQueryChanged]
/// で元の画面へ即時に伝える（閉じたときに戻り値で返す方式だと、端末の
/// 戻る操作で選択が失われるため）。
///
/// 検索欄は元の画面(地図パネルの上)にもあり、どちらで入力しても同じ検索語を共有する。
class MapFullscreenScreen extends StatefulWidget {
  final List<NationalRoute> routes;
  final RegionKey? initialRegion;
  final ValueChanged<RegionKey?> onSelectRegion;
  final RouteStatus Function(String routeId) statusOf;
  final String initialQuery;
  final ValueChanged<String> onQueryChanged;

  const MapFullscreenScreen({
    super.key,
    required this.routes,
    required this.initialRegion,
    required this.onSelectRegion,
    required this.statusOf,
    this.initialQuery = '',
    required this.onQueryChanged,
  });

  @override
  State<MapFullscreenScreen> createState() => _MapFullscreenScreenState();
}

class _MapFullscreenScreenState extends State<MapFullscreenScreen> {
  RegionKey? _region;
  late final TextEditingController _queryController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion;
    _query = widget.initialQuery;
    _queryController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _selectRegion(RegionKey? region) {
    setState(() => _region = region);
    widget.onSelectRegion(region);
  }

  void _changeQuery(String query) {
    setState(() => _query = query);
    widget.onQueryChanged(query);
  }

  int get _matchCount => widget.routes.where((r) => routeMatchesQuery(r, _query)).length;

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  const Text(
                    '走破・地図',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (_region != null && !searching)
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _selectRegion(null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurfaceRaised,
                            borderRadius: BorderRadius.circular(AppColors.radiusFull),
                          ),
                          child: Text(
                            '${regionLabel[_region]}のみ表示 ×',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.routeSignBlue),
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    tooltip: '閉じる',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: RouteSearchField(
                      controller: _queryController,
                      onChanged: _changeQuery,
                    ),
                  ),
                  if (searching) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$_matchCount路線',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                  child: JapanMapPanel(
                    height: null,
                    routes: widget.routes,
                    activeRegion: _region,
                    onSelectRegion: _selectRegion,
                    statusOf: widget.statusOf,
                    searchQuery: _query,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: MapLegend(),
            ),
          ],
        ),
      ),
    );
  }
}
