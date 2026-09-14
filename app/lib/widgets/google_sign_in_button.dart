/// Web版でのみ、Google Identity Servicesが描画するサインインボタンを
/// 表示するためのラッパー。Web版はauthenticate()を使ったアプリ独自の
/// ボタンからのサインインができない（Google側の仕様）ため、SDKが描画する
/// ボタンを使う必要がある。
///
/// google_sign_in_webはWeb専用パッケージのため、Android/iOSビルドを壊さない
/// よう条件付きimportで切り替える（非Web環境では[google_sign_in_button_stub.dart]
/// が使われ、実際には呼ばれない想定＝LoginScreen側でkIsWebによりWeb版でのみ
/// 呼び出す）。
library;

import 'package:flutter/widgets.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart' as impl;

Widget buildGoogleSignInButton() => impl.buildGoogleSignInButton();