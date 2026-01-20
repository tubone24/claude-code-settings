# チェックポイント

## 作成: /checkpoint create [name]

```bash
git stash push -m "checkpoint: $name"
```

## 復元: /checkpoint restore [name]

```bash
git stash list | grep "checkpoint: $name"
git stash pop stash@{n}
```

## 一覧: /checkpoint list

```bash
git stash list | grep "checkpoint:"
```

安全に状態を保存・復元するためのワークフロー。
