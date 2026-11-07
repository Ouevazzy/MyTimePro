#!/bin/zsh
set -u

REPO="/Users/jordan/Documents/Xcode/WorkTimer"
LOG="$HOME/Library/Logs/WorkTimerAutoPush.log"

mkdir -p "$(dirname "$LOG")"
cd "$REPO" || {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Missing repo: $REPO" >> "$LOG"
  exit 1
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] $*" >> "$LOG"
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "Not a git repository"
  exit 1
fi

branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  log "Detached HEAD; skipping"
  exit 0
fi

git fetch --prune origin >/dev/null 2>&1 || {
  log "Fetch failed; check GitHub connection"
  exit 1
}

upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$upstream" ]]; then
  log "No upstream configured for $branch; skipping"
  exit 0
fi

behind="$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
if [[ "$behind" != "0" ]]; then
  log "$branch is behind $upstream by $behind commit(s); manual sync needed before auto-push"
  exit 0
fi

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A

  if git diff --cached --quiet; then
    log "Changes ignored by .gitignore; nothing to commit"
  else
    git commit -m "chore: auto-save WorkTimer changes $(date '+%Y-%m-%d %H:%M')" >/dev/null 2>&1 || {
      log "Commit failed"
      exit 1
    }
    log "Committed local changes on $branch"
  fi
fi

ahead="$(git rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
if [[ "$ahead" != "0" ]]; then
  git push origin "$branch" >/dev/null 2>&1 && log "Pushed $ahead commit(s) to origin/$branch" || {
    log "Push failed"
    exit 1
  }
else
  log "No local commits to push"
fi
