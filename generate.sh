#!/bin/bash

# ─── Config ───────────────────────────────────────────────────────────────────
REPO_DIR="/var/www/cron-chaos"
LOG_FILE="$REPO_DIR/cron.log"
MAX_LOG_LINES=500

cd "$REPO_DIR" || exit 1

# ─── Helpers ──────────────────────────────────────────────────────────────────
random_name() {
  cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6
}

# ─── 1. Supprimer tous les anciens fichiers et dossiers ───────────────────────
find "$REPO_DIR" -mindepth 1 -maxdepth 3 \
  ! -path '*/.git*' \
  ! -name 'generate.sh' \
  ! -name 'README.md' \
  ! -name 'cron.log' \
  -delete 2>/dev/null

echo "  [CLEAN] anciens fichiers supprimés"

# ─── 2. Créer exactement 4 fichiers aléatoires ───────────────────────────────
EXTENSIONS=("txt" "md" "json" "log" "csv" "yaml")

for i in 1 2 3 4; do
  EXT=${EXTENSIONS[$((RANDOM % ${#EXTENSIONS[@]}))]}
  FILE_NAME="$(random_name).$EXT"
  DEST_FILE="$REPO_DIR/$FILE_NAME"

  case "$EXT" in
    json)
      echo "{\"id\": \"$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)\", \"value\": $((RANDOM % 1000)), \"active\": $([ $((RANDOM%2)) -eq 0 ] && echo true || echo false)}" > "$DEST_FILE"
      ;;
    csv)
      echo "id,name,score" > "$DEST_FILE"
      echo "$((RANDOM % 999)),$(random_name),$((RANDOM % 100))" >> "$DEST_FILE"
      ;;
    yaml)
      echo "name: $(random_name)"  > "$DEST_FILE"
      echo "value: $((RANDOM % 500))" >> "$DEST_FILE"
      echo "enabled: true"         >> "$DEST_FILE"
      ;;
    md)
      echo "# $(random_name)"      > "$DEST_FILE"
      echo "generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$DEST_FILE"
      ;;
    *)
      echo "generated: $(date '+%Y-%m-%d %H:%M:%S')" > "$DEST_FILE"
      echo "id: $(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 12)" >> "$DEST_FILE"
      echo "value: $((RANDOM % 99999))"               >> "$DEST_FILE"
      ;;
  esac

  echo "  [FILE]  créé $FILE_NAME"
done

# ─── 3. Git add + commit + push ───────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT_MSG="chore: reset + 4 new files [$TIMESTAMP]"

git add -A

if git diff --cached --quiet; then
  echo "  [GIT]   rien à commiter"
else
  git commit -m "$COMMIT_MSG" --quiet
  git push origin main --quiet 2>&1

  if [ $? -eq 0 ]; then
    echo "  [GIT]   pushed: $COMMIT_MSG"
  else
    echo "  [GIT]   push FAILED"
  fi
fi

# ─── 4. Log ───────────────────────────────────────────────────────────────────
echo "[$TIMESTAMP] run complete — 4 fichiers générés" >> "$LOG_FILE"

if [ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]; then
  tail -n $MAX_LOG_LINES "$LOG_FILE" > "$LOG_FILE.tmp"
  mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
