#!/usr/bin/env bash
set -euo pipefail

# ─── ANSI colors ──────────────────────────────────────────────
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
BLACK='\033[30m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'
WHITE='\033[97m'
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_MAGENTA='\033[45m'
BG_CYAN='\033[46m'
BG_RED='\033[41m'
SECTION="${BOLD}${WHITE}${BG_BLUE}"
SUCCESS="${BOLD}${WHITE}${BG_GREEN}"
WARN="${BOLD}${BLACK}${BG_YELLOW:-${YELLOW}}"
FAIL="${BOLD}${WHITE}${BG_RED}"

# ─── Args ─────────────────────────────────────────────────────
REPO="${1:?Usage: $0 <owner/repo> <label> [github-token]}"
LABEL="${2:?Usage: $0 <owner/repo> <label> [github-token]}"
TOKEN="${3:-${GITHUB_TOKEN:?GITHUB_TOKEN must be set via arg or env}}"
export PATH="/Users/jan/.opencode/bin:$PATH"
export NODE_TLS_REJECT_UNAUTHORIZED=0
BASE_BRANCH="$(git branch --show-current 2>/dev/null || echo main)"
TIMESTAMP=$(date '+%H:%M:%S')

# ─── Helpers ──────────────────────────────────────────────────
header()  { printf "\n${SECTION}  %-60s  ${RESET}\n" "$1"; }
step()    { printf "  ${BOLD}${CYAN}▸${RESET}  %s\n" "$1"; }
ok()      { printf "  ${GREEN}✓${RESET}  %s\n" "$1"; }
fail()    { printf "  ${RED}✗${RESET}  %s\n" "$1"; }
warn()    { printf "  ${YELLOW}⚠${RESET}  %s\n" "$1"; }
info()    { printf "  ${DIM}%s${RESET}\n" "$1"; }
separator() { printf "  ${DIM}─────────────────────────────────────────────────────────────${RESET}\n"; }
summary() { printf "\n${SUCCESS}  %-60s  ${RESET}\n" "$1"; }

# ─── Main ─────────────────────────────────────────────────────
clear 2>/dev/null || true

echo ""
echo "  ${BOLD}${WHITE}${BG_BLUE}  ⚡ AI Issue → PR Pipeline                          ${RESET}"
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

  step "Creating branch ${BOLD}fix/issue-${NUMBER}${RESET}..."
  git checkout "$BASE_BRANCH" 2>/dev/null || true
  git checkout -b "$BRANCH" 2>/dev/null || true
  ok "Branch ready"

  PROMPT="GitHub issue #$NUMBER: $TITLE

$BODY

Implement the changes described above. Then git add and git commit the changes."

  step "OpenCode generating implementation..."
  echo ""
  opencode run "$PROMPT" --dangerously-skip-permissions 2>&1 || true
  echo ""

  # If OpenCode didn't commit, commit any uncommitted changes
  if ! git diff --cached --quiet 2>/dev/null || ! git diff --quiet 2>/dev/null; then
    git add -A
    git commit -m "fix: $TITLE (closes #$NUMBER)" 2>/dev/null || true
  fi

  # Check if any new commit was made on this branch
  COMMITS_AHEAD=$(git rev-list --count "$BASE_BRANCH..HEAD" 2>/dev/null || echo 0)
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
  PR_URL=$(gh pr create \
    --repo "$REPO" \
    --base "$BASE_BRANCH" \
    --head "$BRANCH" \
    --title "$TITLE" \
    --body "Closes #${NUMBER}
/cc @mindthevirt" \
    --reviewer mindthevirt 2>&1) || true

  if [[ -n "$PR_URL" ]]; then
    ok "PR created: ${BOLD}${CYAN}${PR_URL}${RESET}"
  else
    ok "PR created successfully"
  fi

  step "Tagging issue with ${BOLD}ready-for-review${RESET}..."
  gh issue edit "$NUMBER" --repo "$REPO" --remove-label "$LABEL" --add-label "ready-for-review" 2>&1 || \
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
