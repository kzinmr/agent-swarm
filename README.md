# Agent Swarm - OpenClaw + OpenCode + Qwen

Elvis氏のAgent SwarmアーキテクチャをOpenClaw + OpenCode + Qwenモデル用に実装した基盤です。

## アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────────┐
│                         OpenClaw (Zoe)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Memory    │  │   Task      │  │  Notify     │             │
│  │  (Context)  │  │  Orchestral │  │  (Telegram) │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ spawns & monitors
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Coding Agents (tmux)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  OpenCode   │  │  OpenCode   │  │  OpenCode   │  ...        │
│  │  (Qwen)     │  │  (Qwen)     │  │  (Qwen)     │             │
│  │             │  │             │  │             │             │
│  │ worktree/1  │  │ worktree/2  │  │ worktree/3  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ creates PR
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Automated Review                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  OpenCode   │  │   Gemini    │  │   Claude    │             │
│  │  Review     │  │   Review    │  │   Review    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ all checks passed
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Human Review & Merge                         │
└─────────────────────────────────────────────────────────────────┘
```

## 前提条件

- OpenClaw (インストール済み)
- OpenCode CLI (`opencode` コマンド)
- Alibaba Cloud Model Studio API Key (または他のLLMプロバイダー)
- tmux
- jq
- gh CLI (GitHub CLI)
- git

## ディレクトリ構成

```
agent-swarm/
├── config/
│   ├── swarm.config.sh       # 環境設定
│   └── active-tasks.json     # タスクレジストリ
├── scripts/
│   ├── spawn-agent.sh        # エージェント起動
│   ├── monitor-agents.sh     # 監視スクリプト
│   ├── steer-agent.sh        # 中途リダイレクト
│   ├── auto-review.sh        # 自動レビュー
│   ├── cleanup.sh            # クリーンアップ
│   └── setup-cron.sh         # Cron設定
└── templates/
    └── review-prompt.md      # レビュープロンプト
```

## クイックスタート

### 1. 環境変数の設定

```bash
# Alibaba Cloud Model Studio (Qwen) の場合
export OPENCODE_DEFAULT_MODEL="qwen-coder-plus"
export OPENCODE_HIGH_EFFORT_MODEL="qwen-coder-max"

# または .zshrc / .bashrc に追加
```

### 2. 初期化

```bash
# 設定ファイルを読み込み
source agent-swarm/config/swarm.config.sh

# 初期化
init_registry
```

### 3. エージェントの起動

```bash
# 基本的な使い方
./scripts/spawn-agent.sh feat-new-feature opencode qwen-coder-plus

# 高優先度タスク
./scripts/spawn-agent.sh fix-critical-bug opencode qwen-coder-max high
```

### 4. 監視の設定

```bash
# Cron ジョブのインストール
./scripts/setup-cron.sh --install

# 確認
./scripts/setup-cron.sh --show
```

### 5. エージェントへの指示

```bash
# 方向修正
./scripts/steer-agent.sh feat-new-feature "Focus on the API layer first."

# コンテキスト追加
./scripts/steer-agent.sh feat-new-feature "The schema is in src/types/api.ts"
```

### 6. 自動レビュー

```bash
# PRレビューの実行
./scripts/auto-review.sh 341
```

## 設定オプション

`config/swarm.config.sh` で設定可能：

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `SWARM_ROOT` | `~/.agent-swarm` | Swarmのルートディレクトリ |
| `WORKTREES_DIR` | `~/worktrees` | Worktree配置ディレクトリ |
| `OPENCODE_DEFAULT_MODEL` | `qwen-coder-plus` | デフォルトモデル |
| `OPENCODE_HIGH_EFFORT_MODEL` | `qwen-coder-max` | 高複雑度タスク用モデル |
| `CHECK_INTERVAL_SECONDS` | `600` | 監視間隔（秒） |
| `MAX_RETRY_ATTEMPTS` | `3` | 最大再試行回数 |

## タスクレジストリ

`active-tasks.json` で各タスクの状態を管理：

```json
{
  "id": "feat-templates",
  "tmuxSession": "agent-feat-templates",
  "agent": "opencode",
  "model": "qwen-coder-plus",
  "status": "running",
  "checks": {
    "prCreated": true,
    "prNumber": 341,
    "ciPassed": true,
    "reviews": {
      "opencode": "passed",
      "gemini": "passed",
      "claude": "pending"
    }
  }
}
```

## Definition of Done

タスク完了の定義：

- [ ] PR作成済み
- [ ] ブランチがmainと同期（コンフリクトなし）
- [ ] CI通過（lint, typecheck, test, e2e）
- [ ] OpenCode レビュー通過
- [ ] Gemini レビュー通過
- [ ] Claude Code レビュー通過
- [ ] スクリーンショット含む（UI変更の場合）

## OpenClawとの統合

このシステムはOpenClawをオーケストレーターとして使用：

1. **OpenClaw (Zoe)** がビジネスコンテキストを保持
2. 顧客データ、会議ノート、過去の決定事項を参照
3. 適切なエージェントを選択してspawn
4. 進捗を監視し、必要に応じてリダイレクト
5. 完了時に通知

### OpenClawからのエージェント起動

```bash
# OpenClawセッション内からspawn
sessions_spawn \
  --runtime "acp" \
  --agent-id "opencode" \
  --task "Implement the billing feature based on customer request..."
```

### OpenClawからのステアリング

```bash
# エージェントへの指示
sessions_send \
  --session-key "agent-feat-templates" \
  --message "Stop. The customer wanted X, not Y."
```

## トラブルシューティング

### tmuxセッションが応答しない

```bash
# セッション確認
tmux ls

# アタッチ
tmux attach -t agent-feat-templates

# 強制終了
tmux kill-session -t agent-feat-templates
```

### worktreeの競合

```bash
# worktree一覧
git worktree list

# 強制削除
git worktree remove --force /path/to/worktree
```

### CIが失敗

```bash
# CI ログ確認
gh run list --branch feat-templates
gh run view <run-id>
```

## コスト目安

- Qwen-coder-plus: ~$0.001/1K tokens
- Qwen-coder-max: ~$0.003/1K tokens
- 1日50コミット運用で月額 $50-100 程度

## 参考

- [Elvis氏のオリジナル記事](https://x.com/elvissun/article/2025920521871716562)
- [OpenClaw Docs](https://docs.openclaw.ai)
- [OpenCode](https://github.com/opencode-ai/opencode)