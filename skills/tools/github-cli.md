---
name: github-cli
description: gh CLI reference for GitHub operations
---

# GitHub CLI (gh)

## 認証
```bash
gh auth login
gh auth status
```

## PR
```bash
gh pr list [--state open|closed|merged]
gh pr view [number] [--json title,body,files]
gh pr create --title "..." --body "..."
gh pr checkout [number]
gh pr diff [number]
gh pr review [number] --approve|--comment|--request-changes
gh pr merge [number] --merge|--squash|--rebase
```

## Issue
```bash
gh issue list [--label bug]
gh issue view [number]
gh issue create --title "..." --body "..."
gh issue close [number]
```

## Repo
```bash
gh repo view [owner/repo]
gh repo clone [owner/repo]
gh release list
gh release create [tag] --notes "..."
```

## API
```bash
gh api repos/{owner}/{repo}/pulls
gh api graphql -f query='...'
```
