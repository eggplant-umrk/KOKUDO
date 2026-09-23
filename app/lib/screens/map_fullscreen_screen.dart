import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../widgets/japan_map_panel.dart';
import '../widgets/map_legend.dart';

/// 走破・地図コレクションの地図を画面いっぱいに表示する画面。
///
/// パネルの地図をタップ（または右上の全画面ボタン）で開く。地方の選択は
/// この画面内でも変えられ、変更は [onSelectRegion] で元の画面へ即時に伝える
/// （閉じたときに戻り値で返す方式だと、端末の戻る操作で選択が失われるため）。
class MapFullscreenScreen extends StatefulWidget {
  final List<NationalRoute> routes;
  final RegionKey? initialRegion;
  final ValueChanged<RegionKey?> onSelectRegion;
  final RouteStatus Function(String routeId) statusOf;

  const MapFullscreenScreen({
    super.key,
    required this.routes,
    required this.initialRegion,
    required this.onSelectRegion,
    required this.statusOf,
  });

  @override
  State<MapFullscreenScreen> createState() => _MapFullscreenScreenState();
}

class _MapFullscreenScreenState extends State<MapFullscreenScreen> {
  RegionKey? _region;

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion;
  }

  void _selectRegion(RegionKey? region) {
    setState(() => _region = region);
    widget.onSelectRegion(region);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Text(
                    '走破・地図',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (_region != null)
                    GestureDetector(
                      onTap: () => _selectRegion(null),
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    tooltip: '閉じる',
                  ),
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
