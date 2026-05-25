# 議事録アプリ

音声録音から文字起こし、AI 要約、議事録の保存までを行う Flutter アプリです。録音中は波形を表示し、作成した議事録は端末内 DB に保存されます。

## 主な機能

- 音声録音と録音中の波形表示
- 録音ファイルの再生
- バックエンド API 経由の文字起こし
- AI による議事録要約
- 議事録一覧、詳細表示、削除
- ポイント残高表示、広告報酬、テスト用ポイント追加
- Android foreground service による録音通知操作

## 構成

- Flutter アプリ: `lib/`
- Widget/unit tests: `test/`
- iOS / Android ネイティブ設定: `ios/`, `android/`
- バックエンド: `server/`

`server/` は親リポジトリでは除外されていますが、ローカルには Express + TypeScript のバックエンドがあります。PostgreSQL にポイント情報を保存し、Groq API へ文字起こし・要約リクエストを送ります。

## セットアップ

Flutter 依存関係を取得します。

```sh
flutter pub get
```

アプリ直下に `.env` を作成します。

```env
GROQ_API_KEY=your_groq_api_key_here
BACKEND_URL=http://localhost:3000
```

バックエンドを使う場合は `server/.env.local` を用意します。

```env
DATABASE_URL=postgresql://user:password@host:5432/database?sslmode=require
GROQ_API_KEY=your_groq_api_key_here
PORT=3000
```

バックエンドの依存関係と起動:

```sh
cd server
npm install
npm run dev
```

アプリ起動:

```sh
flutter run
```

## 開発コマンド

Flutter:

```sh
flutter analyze
flutter test
```

バックエンド:

```sh
cd server
npm run build
npm test
```

## 注意事項

- `.env` と `server/.env.local` は秘密情報を含むためコミットしません。
- Android の録音・通知・広告関連機能は権限や実機環境に依存します。
- 現在の広告ユニット ID はテスト用です。
- 依存関係には更新候補があります。更新時は別コミットで `flutter analyze` と `flutter test` を再実行してください。
