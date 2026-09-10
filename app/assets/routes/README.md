# 国道GeoJSONデータ（先行6路線分）

このディレクトリには、各国道のルート形状を表すGeoJSONファイルを
`route_{route_number}.geojson`（例: `route_174.geojson`）という命名で配置します。

このコミット時点では実際のGeoJSONファイルは未追加です。
`lib/data/mock_data.dart` の `geojsonPath` はこのディレクトリ内のパスを
先行して参照していますが、実データ投入（ルート形状の描画）は別タスクで対応します。
