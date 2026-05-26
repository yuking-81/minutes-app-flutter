# アカウント・ポイント機能フォローアップタスク

## 進め方

このタスクリストは、アカウント管理・ポイント管理・録音課金機能の実装後に必要な確認と仕上げを順番に進めるためのものです。

## タスク

- [ ] 1. 実機/シミュレータで認証フローを確認する
  - [ ] 新規登録できる
  - [ ] ログインできる
  - [ ] アプリ再起動後にログイン状態が復元される
  - [ ] ログアウトできる
  - [ ] ポイント履歴が表示される
  - メモ: `flutter devices` では macOS と Chrome のみ検出。iOS/Android の実機・シミュレータは未検出のため未実施。実機確認時に結果を追記する。

- [ ] 2. 録音課金の実動作を確認する
  - [ ] 録音開始時にログイン必須になる
  - [ ] 60秒経過で1pt消費される
  - [ ] 残高不足時に録音が自動停止する
  - [ ] 自動停止後に録音済み音声が文字起こし・保存へ進む
  - メモ: iOS/Android 実機・シミュレータが未検出。マイク録音、通知、広告、60秒経過を含む実機操作が必要なため未実施。自動テストで補える範囲はタスク5で追加済み。

- [ ] 3. 本番/デプロイ環境変数を確認する
  - [x] Backend local `DATABASE_URL` の存在確認
  - [ ] Backend local `GROQ_API_KEY`
  - [ ] Backend local `JWT_SECRET`
  - [x] Flutter `.env` の `BACKEND_URL` の存在確認
  - [ ] Vercel/本番 `DATABASE_URL`
  - [ ] Vercel/本番 `GROQ_API_KEY`
  - [ ] Vercel/本番 `JWT_SECRET`
  - メモ: ローカル `server/.env.local` には DB 系キーはあるが、`GROQ_API_KEY` と `JWT_SECRET` は未確認。`.env.example` に `JWT_SECRET` を追加。Vercel/本番環境にはこの環境からアクセスしない。

- [x] 4. server生成物を整理する
  - [x] `server/dist/` をGit管理対象外にする
  - [x] `server/dist-test/` をGit管理対象外にする
  - [x] `server/node_modules/` をGit管理対象外にする
  - [x] `server` の `git status` に生成物が出ない状態にする
  - 完了コミット: `0d72407 chore: ignore generated server artifacts`

- [x] 5. 認証/ポイントAPIの統合テストを追加する
  - [x] register/login/me の正常系を確認する
  - [x] 重複メールと不正パスワードを確認する
  - [x] reward/consume/history の正常系を確認する
  - [x] 残高不足時に403になることを確認する
  - [x] transaction が記録されることを確認する
  - 完了コミット: `8d8db89 test: cover authenticated point APIs`
  - 確認: `npm run build` 成功、`npm test` 成功（supertestの一時HTTPサーバー起動のため権限付きで実行）

## 完了条件

- ローカルで実行可能な自動テストが通っている
- 手動確認が必要な項目は手順と結果をこのファイルに記録している
- 変更はタスク単位でコミットされている
