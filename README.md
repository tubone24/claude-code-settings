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
│   ├── observability.json # 監視設定
│   └── scripts/           # フック用スクリプト
│       └── obsidian-export.py  # Obsidian連携
├── mcp-configs/           # MCP サーバー設定
│   └── mcp-servers.json
└── examples/              # サンプル
    ├── CLAUDE.md          # プロジェクト用CLAUDE.md
    └── user-CLAUDE.md     # ユーザー用CLAUDE.md
```

---

## インストール方法

### プラグインとしてインストール（推奨）

Claude Code のプラグインシステムを使用してインストールします。

```bash
# マーケットプレイスを追加
/plugin marketplace add tubone24/claude-code-settings

# プラグインをインストール
/plugin install claude-code-settings@tubone24/claude-code-settings
```

---

## Obsidian連携

Claude Codeセッションの内容をObsidianに自動エクスポートする機能です。

### 機能

- **セッション終了時に自動エクスポート**: `SessionEnd` hookでトランスクリプトを解析
- **構造化されたMarkdown**: プロンプト、編集ファイル、実行コマンドを整理
- **YAMLフロントマター**: Obsidianのプロパティ/タグに対応
- **折りたたみ対応**: 長いプロンプトは自動的に `<details>` で折りたたみ

### セットアップ

1. 環境変数 `OBSIDIAN_VAULT_PATH` を設定:

```bash
# ~/.bashrc または ~/.zshrc に追加
export OBSIDIAN_VAULT_PATH="$HOME/Documents/Obsidian/MyVault"
```

2. プラグインをインストールすると、自動的にhookが有効になります

### 出力例

```markdown
---
date: 2026-01-28
time: 15:30:45
session_id: abc123
project: my-project
tags:
  - claude-code
  - session
---

# Claude Code Session - 2026-01-28 15:30:45

## User Prompts

### Prompt 1
\`\`\`
ユーザーのプロンプト内容...
\`\`\`

## Files Edited

- `src/index.ts`
- `package.json`

## Commands Run

\`\`\`bash
npm install
npm test
\`\`\`

## Tool Usage Summary

| Tool | Count |
|------|-------|
| Edit | 5 |
| Bash | 3 |
| Read | 2 |
```

### 保存先

`$OBSIDIAN_VAULT_PATH/Claude-Sessions/claude-session-YYYY-MM-DD-HHMMSS-{session_id}.md`

---

## ライセンス

MIT License
