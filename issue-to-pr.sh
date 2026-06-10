#!/usr/bin/env bash
set -euo pipefail

# ─── ANSI colors ──────────────────────────────────────────────
BOLD=$'\033[1m'
DIM=$'\033[2m'
RESET=$'\033[0m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
CYAN=$'\033[36m'
WHITE=$'\033[97m'
BG_BLUE=$'\033[44m'
BG_GREEN=$'\033[42m'
BG_RED=$'\033[41m'
SECTION="${BOLD}${WHITE}${BG_BLUE}"
SUCCESS="${BOLD}${WHITE}${BG_GREEN}"

# ─── Args ─────────────────────────────────────────────────────
REPO="${1:?Usage: $0 <owner/repo> <label> [github-token]}"
LABEL="${2:?Usage: $0 <owner/repo> <label> [github-token]}"
TOKEN="${3:-${GITHUB_TOKEN:?GITHUB_TOKEN must be set via arg or env}}"
export PATH="/Users/jan/.opencode/bin:$PATH"
export NODE_TLS_REJECT_UNAUTHORIZED=0
BASE_BRANCH="main"

# ─── Helpers ──────────────────────────────────────────────────
header()    { printf "\n${SECTION}  %-60s  ${RESET}\n" "$1"; }
step()      { printf "  ${BOLD}${CYAN}▸${RESET}  %s\n" "$1"; }
ok()        { printf "  ${GREEN}✓${RESET}  %s\n" "$1"; }
fail()      { printf "  ${RED}✗${RESET}  %s\n" "$1"; }
warn()      { printf "  ${YELLOW}⚠${RESET}  %s\n" "$1"; }
info()      { printf "  ${DIM}%s${RESET}\n" "$1"; }
summary()   { printf "\n${SUCCESS}  %-60s  ${RESET}\n" "$1"; }
separator() { printf "  ${DIM}─────────────────────────────────────────────────────────────${RESET}\n"; }

# ─── Main ─────────────────────────────────────────────────────
clear 2>/dev/null || true

echo ""
echo "  ${SECTION}  ⚡ AI Issue → PR Pipeline                          ${RESET}"
echo "  ${DIM}  $(date '+%Y-%m-%d %H:%M:%S')  •  ${REPO}  •  label: ${LABEL}${RESET}"
echo ""

step "Fetching open issues in ${BOLD}${REPO}${RESET} labeled ${BOLD}${LABEL}${RESET}..."
ISSUES=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO/issues?state=open&labels=$(echo -n "$LABEL" | jq -sRr @uri)")

ISSUE_COUNT=$(echo "$ISSUES" | jq 'length')
if [[ "$ISSUE_COUNT" -eq 0 ]]; then
  echo ""
  info "No open issues found with label '${LABEL}'."
  echo ""
  exit 0
fi
ok "Found ${BOLD}$ISSUE_COUNT${RESET} open issue(s)"

echo ""
echo "$ISSUES" | jq -c '.[]' | while read -r issue; do
  NUMBER=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title')
  BODY=$(echo "$issue" | jq -r '.body // ""')
  BRANCH="fix/issue-${NUMBER}"

  echo ""
  header "  Processing Issue #${NUMBER}: ${TITLE}"
  echo ""

  step "Syncing to latest ${BOLD}${BASE_BRANCH}${RESET}..."
  git fetch origin "$BASE_BRANCH" 2>/dev/null || true
  git checkout "$BASE_BRANCH" 2>/dev/null || true
  git reset --hard "origin/$BASE_BRANCH" 2>/dev/null || true
  ok "Up to date with origin/${BASE_BRANCH}"

  step "Creating branch ${BOLD}fix/issue-${NUMBER}${RESET}..."
  git branch -D "$BRANCH" 2>/dev/null || true
  git checkout -b "$BRANCH"
  ok "Branch ready"

  PROMPT="GitHub issue #$NUMBER: $TITLE

$BODY

Implement the changes described above. Then git add and git commit the changes."

  step "OpenCode generating implementation..."
  echo ""
  opencode run "$PROMPT" --dangerously-skip-permissions 2>&1 || true
  echo ""

  # Stage any uncommitted changes (including untracked files) and commit
  git add -A
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "fix: $TITLE (closes #$NUMBER)" 2>/dev/null || true
  fi

  COMMITS_AHEAD=$(git rev-list --count "origin/$BASE_BRANCH..HEAD" 2>/dev/null || echo 0)
  if [[ "$COMMITS_AHEAD" -eq 0 ]]; then
    echo ""
    warn "No changes generated for issue #${NUMBER} — skipping."
    git checkout "$BASE_BRANCH" 2>/dev/null || true
    git branch -D "$BRANCH" 2>/dev/null || true
    continue
  fi

  ok "Generated ${COMMITS_AHEAD} commit(s)"
  step "Pushing branch to origin..."
  git push origin "$BRANCH" -u 2>&1 || { fail "Push failed for ${BRANCH}"; continue; }
  ok "Branch pushed"

  step "Creating Pull Request..."
  PR_RESPONSE=$(curl -s -X POST -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$REPO/pulls" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg title "$TITLE" \
      --arg head "$BRANCH" \
      --arg base "$BASE_BRANCH" \
      --arg body "Closes #${NUMBER}" \
      '{title: $title, head: $head, base: $base, body: $body, maintainer_can_modify: true}')")

  PR_NUMBER=$(echo "$PR_RESPONSE" | jq -r '.number // empty')
  PR_HTML_URL=$(echo "$PR_RESPONSE" | jq -r '.html_url // empty')

  if [[ -n "$PR_NUMBER" ]]; then
    ok "PR created: ${BOLD}${CYAN}${PR_HTML_URL}${RESET}"
    curl -s -X POST -H "Authorization: token $TOKEN" \
      "https://api.github.com/repos/$REPO/pulls/$PR_NUMBER/requested_reviewers" \
      -H "Content-Type: application/json" \
      -d '{"reviewers":["mindthevirt"]}' > /dev/null 2>&1 || true
  else
    fail "Failed to create PR: $(echo "$PR_RESPONSE" | jq -r '.message // "unknown error"')"
    git checkout "$BASE_BRANCH" 2>/dev/null || true
    git branch -D "$BRANCH" 2>/dev/null || true
    continue
  fi

  step "Tagging issue with ${BOLD}ready-for-review${RESET}..."
  curl -s -X DELETE -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$REPO/issues/$NUMBER/labels/$(echo -n "$LABEL" | jq -sRr @uri)" > /dev/null 2>&1 || true
  curl -s -X POST -H "Authorization: token $TOKEN" \
    "https://api.github.com/repos/$REPO/issues/$NUMBER/labels" \
    -H "Content-Type: application/json" \
    -d '{"labels":["ready-for-review"]}' > /dev/null 2>&1 || \
    fail "Failed to update labels"
  ok "Issue #${NUMBER} labels updated"

  separator
  info "Issue #${NUMBER} → PR ✓"
  separator

done

echo ""
git checkout "$BASE_BRANCH" 2>/dev/null || true
summary "  ✅ All done — ${ISSUE_COUNT} issue(s) processed"
echo ""
