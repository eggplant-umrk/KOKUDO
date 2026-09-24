import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/prefecture_shapes.dart';
import '../data/route_catalog.dart';
import '../data/route_geometry.dart';
import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';
import '../widgets/share_card.dart';

/// 完走画像のプレビューを開く。
///
/// 呼び出し元が先にダイアログを閉じることがあるため、[BuildContext] ではなく
/// [NavigatorState] を受け取る(閉じた後の context は使えないため)。
Future<void> pushShareCompletion(NavigatorState navigator, NationalRoute route) {
  return navigator.push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ShareCompletionScreen(route: route),
    ),
  );
}

/// 完走をSNSに投稿するための画像を作って共有する画面。
///
/// 画像はその場で組み立てて PNG にするだけで、どこにも保存しない。
/// 共有先の選択はOSの共有シートに任せる(Instagram/X/Facebookを
/// 個別に呼び分けない)。
class ShareCompletionScreen extends StatefulWidget {
  final NationalRoute route;

  const ShareCompletionScreen({super.key, required this.route});

  @override
  State<ShareCompletionScreen> createState() => _ShareCompletionScreenState();
}

class _ShareCompletionScreenState extends State<ShareCompletionScreen> {
  final GlobalKey _cardKey = GlobalKey();

  ShareCardFormat _format = ShareCardFormat.story;
  bool _showCharacter = false;
  bool _sharing = false;
  ShareCardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final route = widget.route;
    await RouteCatalog.load();
    await PrefectureShapes.load();
    final lines = await RouteGeometry.load(route.geojsonPath);
    final progress = await RouteRepository.instance.getProgress(route.routeId);

    // 完走日が入っていない古いデータもあるので、その場合は今日にする。
    final completedAt = progress?.completedAt ?? DateTime.now();
    final startedAt = progress?.startedAt;
    // 初日を1日目として数える。開始日が無ければ1日にしておく。
    final days = startedAt == null
        ? 1
        : _dateOnly(completedAt).difference(_dateOnly(startedAt)).inDays + 1;

    if (!mounted) return;
    setState(() {
      _data = ShareCardData(
        routeNumber: route.routeNumber,
        routeName: route.name,
        segmentLabel: _segmentLabel(route),
        totalDistanceKm: route.totalDistanceKm,
        days: days < 1 ? 1 : days,
        completedAt: completedAt,
        routeLines: lines,
        prefectureRings: PrefectureShapes.ringsOf(RouteCatalog.prefecturesOf(route.routeId)),
        // GeoJSONの線は複数本に分かれていて順番もばらばらなので、
        // 起点・終点はカタログの座標から取る。線の端から推測すると
        // 路線によって起点とゴールが入れ替わる。
        startPoint: Offset(route.startPoint.lng, route.startPoint.lat),
        goalPoint: Offset(route.endPoint.lng, route.endPoint.lat),
      );
    });
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  static String _segmentLabel(NationalRoute route) {
    final start = route.startPoint.label;
    final end = route.endPoint.label;
    if (start == null || end == null || start.isEmpty || end.isEmpty) return route.name;
    return '$start 〜 $end';
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 変形中のフレームを拾わないよう、描き終わってから画像にする。
      await WidgetsBinding.instance.endOfFrame;
      final Uint8List? bytes = await captureShareCard(_cardKey);
      if (bytes == null) throw StateError('画像を作れませんでした');
      final name = 'kokudo_route${widget.route.routeNumber}_'
          '${_format == ShareCardFormat.story ? 'story' : 'square'}.png';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
          fileNameOverrides: [name],
          text: '${widget.route.name}を完走しました！ #KOKUDO',
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('画像を共有できませんでした。時間をおいて試してください。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '完走をシェア',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue))
          : SafeArea(
              child: Column(
                children: [
                  _formatSwitch(),
                  Expanded(child: _preview(data)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '画像をタップするとキャラクターの表示を切り替えられます',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        height: 52,
                        onPressed: _share,
                        child: _sharing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'この画像を共有',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _formatSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Expanded(child: _formatChip(ShareCardFormat.story, 'ストーリー', 'Instagram')),
          const SizedBox(width: 10),
          Expanded(child: _formatChip(ShareCardFormat.square, '正方形', 'X・Facebook')),
        ],
      ),
    );
  }

  Widget _formatChip(ShareCardFormat format, String title, String note) {
    final selected = _format == format;
    return Material(
      color: selected ? AppColors.routeSignBlue : AppColors.bgSurfaceRaised,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _format = format),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Colors.transparent : AppColors.borderSubtle),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                note,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? Colors.white70 : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// プレビュー。カードは常に実寸(1080×1920 など)で組み立て、
  /// 表示だけ FittedBox で縮める。こうすると RepaintBoundary を
  /// `pixelRatio: 1` で画像にしたときに、そのままの解像度で出る。
  Widget _preview(ShareCardData data) {
    return GestureDetector(
      onTap: () => setState(() => _showCharacter = !_showCharacter),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: RepaintBoundary(
              key: _cardKey,
              child: ShareCard(
                format: _format,
                data: data,
                showCharacter: _showCharacter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
