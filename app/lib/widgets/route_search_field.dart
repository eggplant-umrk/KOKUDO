import 'package:flutter/material.dart';

import '../data/route_catalog.dart';
import '../models/national_route.dart';
import '../theme/app_colors.dart';

/// 路線一覧(459路線)を路線番号・都道府県・地名で絞り込むための検索欄。
///
/// 使い方の例: 「16」→ 16号・160号台、「神奈川」→ 神奈川県を通る路線、
/// 「神奈川 1」→ 神奈川県を通る 1号・1xx号（空白区切りはAND）。
/// 「1」と入れたときに 1号だけでなく 10号・100号…も残るように、番号は
/// 前方一致にしている。
class RouteSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;

  /// 画面をまたいで検索語を引き継ぐときに渡す（地図パネルと全画面地図など）。
  /// 渡すと、文字があるときに右端に「×」（消去）が出る。
  final TextEditingController? controller;

  const RouteSearchField({
    super.key,
    required this.onChanged,
    this.hintText = '路線番号・都道府県で検索（例: 神奈川 1）',
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _buildField(context, null, hasText: false);
    // 文字の有無で「×」を出し分けるので、コントローラーの変化を自分で購読する
    // (親の setState に頼らない)。
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => _buildField(context, controller, hasText: value.text.isNotEmpty),
    );
  }

  Widget _buildField(BuildContext context, TextEditingController? controller, {required bool hasText}) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: hasText && controller != null
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.clear, size: 16, color: AppColors.textTertiary),
                  tooltip: '消去',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          filled: true,
          fillColor: AppColors.bgSurfaceRaised,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            borderSide: const BorderSide(color: AppColors.routeSignBlue, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// [query] に一致する路線かどうか。空の検索語はすべて一致。
/// 空白（全角も可）で区切った語はすべて満たす必要がある（AND）。
/// 各語は「路線番号の前方一致」「都道府県名の前方一致」「路線名・起点・終点の
/// 部分一致」のどれかに当たれば一致とする。
final RegExp _termSeparator = RegExp(r'[\s\u3000]+');
final RegExp _fullWidthDigit = RegExp('[０-９]');
final RegExp _digitsOnly = RegExp(r'^\d+$');

bool routeMatchesQuery(NationalRoute route, String query) {
  final terms = query.split(_termSeparator).where((t) => t.isNotEmpty);
  for (final term in terms) {
    if (!_matchesTerm(route, term)) return false;
  }
  return true;
}

/// [query] の中で都道府県を指している語を、正式名(「神奈川県」など)にして返す。
/// 「神奈川 1」→ ['神奈川県']、「16」→ []。地図を都道府県の範囲に寄せるときに使う。
List<String> prefecturesInQuery(String query) {
  final result = <String>[];
  for (final term in query.split(_termSeparator)) {
    if (!_isPrefectureTerm(term)) continue;
    for (final pref in _prefectureNames) {
      if (pref.startsWith(term) && !result.contains(pref)) result.add(pref);
    }
  }
  return result;
}

/// 都道府県名の書き出しに当たる語か。1文字だと「山」で山形・山梨・山口に
/// 当たるなど広すぎるので、2文字以上に限る(1文字は地名の部分一致で探す)。
bool _isPrefectureTerm(String term) =>
    term.length >= 2 && _prefectureNames.any((p) => p.startsWith(term));

bool _matchesTerm(NationalRoute route, String term) {
  // 全角数字や「国道」「号」付きの入力も番号検索として扱う。
  final normalized = term
      .replaceAllMapped(_fullWidthDigit, (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0))
      .replaceAll('国道', '')
      .replaceAll('号', '')
      .trim();
  if (_digitsOnly.hasMatch(normalized)) {
    return route.routeNumber.toString().startsWith(normalized);
  }

  // 都道府県: 「神奈川」「神奈川県」「東京」「京都」のどれでも当たるよう前方一致。
  // 語が都道府県名の書き出しに当たるときは都道府県だけで判定する
  // (「京都」で東京都中央区が起点の路線まで拾わないように)。
  // 路線に都道府県の情報が無い場合だけ、下の地名の部分一致に落とす。
  if (_isPrefectureTerm(term)) {
    final prefectures = RouteCatalog.prefecturesOf(route.routeId);
    if (prefectures.isNotEmpty) return prefectures.any((p) => p.startsWith(term));
  }

  return route.name.contains(term) ||
      (route.startPoint.label?.contains(term) ?? false) ||
      (route.endPoint.label?.contains(term) ?? false);
}

const List<String> _prefectureNames = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県', '茨城県', '栃木県', '群馬県',
  '埼玉県', '千葉県', '東京都', '神奈川県', '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県',
  '岐阜県', '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県',
  '鳥取県', '島根県', '岡山県', '広島県', '山口県', '徳島県', '香川県', '愛媛県', '高知県', '福岡県',
  '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
];
