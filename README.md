# My Claude Code Settings

Claude Code の拡張機能（エージェント、スキル、コマンド、フック、ルール、MCP設定）を包括的にまとめたリポジトリです。

## 特徴

- **17+ 専門エージェント**: architect, code-reviewer, security-reviewer, typescript-expert など
- **16+ スラッシュコマンド**: `/tdd`, `/plan`, `/code-review`, `/think-harder` など
- **セキュリティフック**: 機密ファイルブロック、危険なコマンド防止
- **品質フック**: 自動フォーマット、TypeScriptチェック、console.log検出
- **20+ MCP サーバー設定**: GitHub, Slack, Database など
- **フレームワーク別スキル**: React, Next.js, TypeScript, AWS など

## コンテキストウィンドウ効率化

本リポジトリはプログレッシブ・ディスクロージャー設計を採用しています:

- **SKILL.md**: 簡潔なメタデータと概要（100-500行）
- **references/**: 詳細な参照資料（必要時のみ読み込み）
- **チェックリスト**: 別ファイルに分離

これにより、コンテキストウィンドウを圧迫せず、必要な情報のみを効率的に利用できます。

## ディレクトリ構造

```
everything-claude-code/
├── .claude-plugin/        # プラグイン設定ファイル
│   ├── plugin.json        # プラグインマニフェスト
│   ├── marketplace.json   # マーケットプレイス定義
│   └── install.sh         # インストールスクリプト
├── agents/                # 専門エージェント定義
│   ├── architect.md       # アーキテクチャ設計
│   ├── code-reviewer.md   # コードレビュー
│   ├── security-reviewer.md
│   ├── typescript-expert.md
│   └── ...
├── commands/              # スラッシュコマンド
│   ├── tdd.md             # /tdd - テスト駆動開発
│   ├── plan.md            # /plan - 設計・計画
│   ├── code-review.md     # /code-review
│   ├── think-harder.md    # /think-harder - 深い思考
│   └── ...
├── skills/                # スキル定義（プログレッシブ・ディスクロージャー設計）
│   ├── architecture/      # アプリアーキテクチャ（DDD, Clean Architecture等）
│   ├── frameworks/        # フレームワーク別（React, Next.js等）
│   ├── languages/         # 言語別（TypeScript等）
│   ├── operations/        # 運用（CI/CD, モニタリング, SRE）
│   ├── tools/             # ツール別
│   └── workflows/         # ワークフロー
│       ├── terraform/     # IaC（モジュール, ステート管理, CI/CD統合）
│       ├── monorepo/      # モノレポ設計（Turborepo, pnpm workspace）
│       ├── security-review/ # セキュリティレビュー（OWASP, ツール）
│       └── tdd-workflow/  # TDD
├── rules/                 # ルール定義
│   ├── coding-style.md    # コーディングスタイル
│   ├── security.md        # セキュリティ
│   ├── testing.md         # テスト
│   └── ...
├── hooks/                 # フック設定
│   ├── hooks.json         # フック定義
│   └── observability.json # 監視設定
├── mcp-configs/           # MCP サーバー設定
│   └── mcp-servers.json
└── examples/              # サンプル
    ├── CLAUDE.md          # プロジェクト用CLAUDE.md
    └── user-CLAUDE.md     # ユーザー用CLAUDE.md
```

---

## インストール方法

### 方法1: プラグインとしてインストール（推奨）

Claude Code のプラグインシステムを使用してインストールします。

```bash
# マーケットプレイスを追加
/plugin marketplace add tubone24/everything-claude-code

# プラグインをインストール
/plugin install claude-code-context-efficient@tubone24/everything-claude-code
```

### 方法2: ワンライナーインストール

```bash
curl -fsSL https://raw.githubusercontent.com/tubone24/everything-claude-code/main/.claude-plugin/install.sh | bash
```

### 方法3: 手動インストール

```bash
# リポジトリをクローン
git clone https://github.com/tubone24/everything-claude-code.git ~/.claude/plugins/everything-claude-code

# コマンドをシンボリックリンク
ln -sf ~/.claude/plugins/everything-claude-code/commands/* ~/.claude/commands/

# エージェントをシンボリックリンク
ln -sf ~/.claude/plugins/everything-claude-code/agents/* ~/.claude/agents/

# フックを設定（settings.jsonにマージ）
# ~/.claude/settings.json にhooks/hooks.jsonの内容を追加
```

### 方法4: 必要なファイルのみコピー

必要なコンポーネントのみをコピーして使用することもできます。

```bash
# 例: コマンドのみコピー
cp -r commands/* ~/.claude/commands/

# 例: 特定のエージェントのみコピー
cp agents/code-reviewer.md ~/.claude/agents/
```

## ライセンス

MIT License
