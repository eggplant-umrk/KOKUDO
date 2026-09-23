import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import 'progress_bar.dart';

const Map<RouteStatus, Color> _statusColor = {
  RouteStatus.notStarted: AppColors.routeInactive,
  RouteStatus.inProgress: AppColors.routeSignBlue,
  RouteStatus.completed: AppColors.accentGold,
};

class RouteCard extends StatelessWidget {
  final NationalRoute route;
  final UserRouteProgress? progress;

  /// タップしたときの動作。走破・地図コレクション画面では、地図をその路線に
  /// 寄せるために渡す。渡さないとタップできないカードになる。
  final VoidCallback? onTap;

  /// 完走画像をシェアする動作。完走済みの路線にだけシェアボタンが出る。
  /// 完走直後のお祝いダイアログを閉じてしまった後でも、ここからやり直せる。
  final VoidCallback? onShare;

  const RouteCard({
    super.key,
    required this.route,
    required this.progress,
    this.onTap,
    this.onShare,
  });

  RouteStatus get _status {
    if (progress == null) return RouteStatus.notStarted;
    if (progress!.isCompleted) return RouteStatus.completed;
    if (progress!.currentDistanceKm > 0) return RouteStatus.inProgress;
    return RouteStatus.notStarted;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final currentKm = progress?.currentDistanceKm ?? 0;
    final ratio = route.totalDistanceKm > 0
        ? (currentKm / route.totalDistanceKm).clamp(0.0, 1.0).toDouble()
        : 0.0;

    Color badgeBg;
    Color badgeText;
    switch (status) {
      case RouteStatus.completed:
        badgeBg = AppColors.accentGold;
        badgeText = const Color(0xFF4A2F00);
        break;
      case RouteStatus.notStarted:
        badgeBg = AppColors.routeInactive;
        badgeText = Colors.white;
        break;
      case RouteStatus.inProgress:
        badgeBg = AppColors.routeSignBlue;
        badgeText = Colors.white;
        break;
    }

    final digits = route.totalDistanceKm < 1 ? 3 : 1;
    var meta = '${regionLabel[route.region]} ・ ${route.totalDistanceKm.toStringAsFixed(digits)}km';
    if (status == RouteStatus.inProgress && progress != null) {
      meta += ' ・ 目標 ${formatDate(progress!.targetEndDate)}';
    }

    // タップできるときは、押した感じ(リップル)が出るよう背景色を Material 側に
    // 持たせる。Container に色を残すとリップルがその下に隠れて見えない。
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: onTap == null ? AppColors.bgSurfaceRaised : null,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status == RouteStatus.inProgress ? null : badgeBg,
              gradient: status == RouteStatus.inProgress ? AppColors.routeSignGradient : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '国道\n${route.routeNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(color: badgeText, fontWeight: FontWeight.w900, fontSize: 11, height: 1.1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        route.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    if (status == RouteStatus.completed) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x2EFFB238),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '完走',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accentGoldText),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  meta,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 5),
                AppProgressBar(
                  ratio: ratio,
                  height: 4,
                  fillColor: _statusColor[status],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(ratio * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary),
          ),
          if (onShare != null && status == RouteStatus.completed) ...[
            const SizedBox(width: 2),
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.ios_share, size: 18),
              color: AppColors.accentGoldText,
              tooltip: '完走画像をシェア',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: AppColors.bgSurfaceRaised,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: card),
    );
  }
}
