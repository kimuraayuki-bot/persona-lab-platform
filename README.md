# Persona Lab MVP

SwiftUI + Supabaseで構成した、16タイプ診断アプリのMVPです。

## 現在の実装範囲
- 作成者ログイン（Email/Password: Supabase Auth接続済み）
- 診断作成（設問・選択肢・4軸スコア）
- 回答フロー（1問ずつ）
- 16タイプ判定（E/I, S/N, T/F, J/P）
- 結果表示と画像カード生成
- iOS共有シートでSNS共有
- Deep Link (`myapp://quiz/{id}?token=...`) の受け取り
- Supabase Edge Functions (`create_share_link`, `submit_response`) の実装
- Web回答UI（`web-app`）: アプリ未インストールでもブラウザで回答可能

## ディレクトリ
- `Sources/PersonaLabCore`: モデル、判定ロジック、バリデーション、API/認証クライアント
- `Sources/PersonaLabApp`: SwiftUIアプリ本体
- `ios-app/PersonaLabiOS`: Xcodeで実行するiOSアプリ
- `web-app`: Vercel想定のNext.js回答UI
- `supabase/migrations`: DBスキーマ + RLS
- `supabase/functions`: Edge Functions

## Supabase セットアップ
1. プロジェクト作成
2. `supabase/migrations/202603071930_init.sql` を適用
3. Functionsをデプロイ
   - `create_share_link`
   - `submit_response`
4. Functionsシークレット設定
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `APP_DOMAIN`

### Functionsシークレット設定例
```bash
supabase secrets set \
  SUPABASE_URL="https://<project-ref>.supabase.co" \
  SUPABASE_ANON_KEY="<anon-key>" \
  SUPABASE_SERVICE_ROLE_KEY="<service-role-key>" \
  APP_DOMAIN="https://example.com" \
  --project-ref <project-ref>
```

## iOSアプリ設定
Xcode: `Product > Scheme > Edit Scheme... > Run > Arguments > Environment Variables`

- 本番接続に必要
  - `SUPABASE_PROJECT_REF=tdctpfxrormusqduvyuq` など
  - `SUPABASE_ANON_KEY=<anon-key>`
  - `APP_DOMAIN=https://example.com`
- 開発効率化
  - `USE_MOCK_API=true`（APIをモック化）
  - `SKIP_LOGIN_FOR_DEV=true`（ログイン画面をスキップ）

## Web回答UI（Vercel）
### 目的
- 共有リンクを開いたユーザーが、アプリ未インストールでもその場で回答できるようにする。

### セットアップ
```bash
cd web-app
npm install
npm run dev
```

- Node.js 20以上（検証済み: 24.x）
- `web-app` は Next.js 16 を使用（`npm audit` high 0）

### 必須環境変数（Vercel）
- `NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY=<anon-key>`

### 回答URL
- `https://<APP_DOMAIN>/q/{quiz_public_id}?token={access_token}`
- Web側はこのURLを受け取り、匿名で設問取得→`submit_response` 実行→結果表示を行います。

### 本番反映のポイント
1. Vercelデプロイ（例: `https://persona-lab-web.vercel.app`）
2. Supabase Functionsの `APP_DOMAIN` を上記ドメインに更新
3. iOS側 `APP_DOMAIN` も同じ値に更新
4. 共有リンクが `https://<APP_DOMAIN>/q/{quiz_public_id}?token=...` 形式で発行されることを確認

## テスト
```bash
swift test
```

## バックエンド疎通テスト
```bash
SUPABASE_URL="https://<project-ref>.supabase.co" \
SUPABASE_ANON_KEY="<anon-key>" \
./scripts/backend_smoke.sh
```

## Functions の JWT 検証設定
`supabase/config.toml` で `create_share_link` と `submit_response` は `verify_jwt = false` 設定です。
再デプロイ時に反映されます。

```bash
supabase functions deploy create_share_link --use-api
supabase functions deploy submit_response --use-api
```

## 残タスク
- Sign in with Apple 実装
- Universal Links / Associated Domains 本番設定
