#!/bin/bash

# ─── Config ───────────────────────────────────────────────────────────────────
REPO_DIR="/var/www/cron-chaos"
LOG_FILE="$REPO_DIR/cron.log"
MAX_LOG_LINES=500

cd "$REPO_DIR" || exit 1

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Génère un nom aléatoire de 6 caractères alphanum
random_name() {
  cat /dev/urandom | tr -dc 'a-z0-9' | head -c 6
}

# Génère un contenu aléatoire
random_content() {
  echo "generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "id: $(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 12)"
  echo "value: $((RANDOM % 99999))"
  echo "tags: $(cat /dev/urandom | tr -dc 'a-z' | head -c 4) $(cat /dev/urandom | tr -dc 'a-z' | head -c 4)"
}

# ─── 1. Créer un dossier aléatoire (50% de chance) ────────────────────────────
if [ $((RANDOM % 2)) -eq 0 ]; then
  DIR_NAME="dir_$(random_name)"
  mkdir -p "$REPO_DIR/$DIR_NAME"
  echo "  [DIR]  created $DIR_NAME"
fi

# ─── 2. Créer 1 à 4 fichiers aléatoires ──────────────────────────────────────
NUM_FILES=$((RANDOM % 4 + 1))
EXTENSIONS=("txt" "md" "json" "log" "csv" "yaml")

for i in $(seq 1 $NUM_FILES); do
  EXT=${EXTENSIONS[$((RANDOM % ${#EXTENSIONS[@]}))]}
  FILE_NAME="$(random_name).$EXT"

  # Choisir un dossier de destination (racine ou sous-dossier existant)
  DIRS=($(find "$REPO_DIR" -mindepth 1 -maxdepth 2 -type d \
    ! -path '*/.git*' 2>/dev/null))
  DIRS+=("$REPO_DIR")

  DEST_DIR=${DIRS[$((RANDOM % ${#DIRS[@]}))]}
  DEST_FILE="$DEST_DIR/$FILE_NAME"

  # Contenu selon l'extension
  case "$EXT" in
    json)
      echo "{\"id\": \"$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 8)\", \"value\": $((RANDOM % 1000)), \"active\": $([ $((RANDOM%2)) -eq 0 ] && echo true || echo false)}" > "$DEST_FILE"
      ;;
    csv)
      echo "id,name,score" > "$DEST_FILE"
      echo "$((RANDOM % 999)),$(random_name),$((RANDOM % 100))" >> "$DEST_FILE"
      ;;
    yaml)
      echo "name: $(random_name)" > "$DEST_FILE"
      echo "value: $((RANDOM % 500))" >> "$DEST_FILE"
      echo "enabled: true" >> "$DEST_FILE"
      ;;
    *)
      random_content > "$DEST_FILE"
      ;;
  esac

  REL_PATH="${DEST_FILE#$REPO_DIR/}"
  echo "  [FILE] created $REL_PATH"
done

# ─── 3. Supprimer un fichier aléatoire (30% de chance) ───────────────────────
if [ $((RANDOM % 10)) -lt 3 ]; then
  EXISTING=($(find "$REPO_DIR" -type f \
    ! -path '*/.git*' \
    ! -name 'generate.sh' \
    ! -name 'README.md' \
    ! -name 'cron.log' 2>/dev/null))

  if [ ${#EXISTING[@]} -gt 3 ]; then
    TARGET=${EXISTING[$((RANDOM % ${#EXISTING[@]}))]}
    REL="${TARGET#$REPO_DIR/}"
    rm "$TARGET"
    echo "  [DEL]  deleted $REL"
  fi
fi

# ─── 4. Git add + commit + push ───────────────────────────────────────────────
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
COMMIT_MSG="chore: auto-generate [$TIMESTAMP] — $NUM_FILES file(s)"

git add -A

# Vérifier s'il y a des changements à commiter
if git diff --cached --quiet; then
  echo "  [GIT]  nothing to commit"
else
  git commit -m "$COMMIT_MSG" --quiet
  git push origin main --quiet 2>&1

  if [ $? -eq 0 ]; then
    echo "  [GIT]  pushed: $COMMIT_MSG"
  else
    echo "  [GIT]  push FAILED"
  fi
fi

# ─── 5. Log ───────────────────────────────────────────────────────────────────
echo "[$TIMESTAMP] run complete — $NUM_FILES file(s) generated" >> "$LOG_FILE"

# Garder seulement les dernières MAX_LOG_LINES lignes dans le log
if [ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]; then
  tail -n $MAX_LOG_LINES "$LOG_FILE" > "$LOG_FILE.tmp"
  mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
