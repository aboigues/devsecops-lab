#!/usr/bin/env bash
# Fonctions partagées par tous les verify.sh des TP.
# Usage : source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

set -euo pipefail

TP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Couleurs (désactivées sans terminal, par exemple en CI)
if [ -t 1 ]; then
  GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BLUE=''; NC=''
fi

PASS=0
FAIL=0

step()  { printf "${BLUE}>> %s${NC}\n" "$*"; }
info()  { printf "   %s\n" "$*"; }

# check "description" commande... : exécute la commande, valide le code retour
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "   ${GREEN}[OK]${NC} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "   ${RED}[KO]${NC} %s\n" "$desc"; FAIL=$((FAIL+1))
  fi
}

# check_fails "description" commande... : la commande DOIT échouer (une gate doit bloquer)
check_fails() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf "   ${RED}[KO]${NC} %s ${YELLOW}(la commande a réussi alors qu'elle devait échouer)${NC}\n" "$desc"; FAIL=$((FAIL+1))
  else
    printf "   ${GREEN}[OK]${NC} %s\n" "$desc"; PASS=$((PASS+1))
  fi
}

# check_verbose "description" commande... : comme check, mais affiche la sortie en cas d'échec
check_verbose() {
  local desc="$1" out; shift
  if out="$("$@" 2>&1)"; then
    printf "   ${GREEN}[OK]${NC} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "   ${RED}[KO]${NC} %s\n" "$desc"; FAIL=$((FAIL+1))
    printf '%s\n' "$out" | tail -n 30 | sed 's/^/        /'
  fi
}

# assert_contains "description" "aiguille" "botte de foin"
assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q -- "$needle"; then
    printf "   ${GREEN}[OK]${NC} %s\n" "$desc"; PASS=$((PASS+1))
  else
    printf "   ${RED}[KO]${NC} %s ${YELLOW}(attendu : « %s »)${NC}\n" "$desc" "$needle"; FAIL=$((FAIL+1))
  fi
}

# require outil... : arrête le TP proprement si un outil manque
require() {
  local missing=0 t
  for t in "$@"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      printf "   ${RED}Outil manquant : %s${NC} (voir tp/README.md, section Prérequis)\n" "$t"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || exit 2
}

# Attendre qu'une URL réponde (HTTP 2xx/3xx), avec délai maximal en secondes
wait_for_http() {
  local url="$1" timeout="${2:-60}" i=0
  step "Attente de $url (max ${timeout}s)"
  until curl -fsS -o /dev/null "$url" 2>/dev/null; do
    i=$((i+2)); sleep 2
    if [ "$i" -ge "$timeout" ]; then
      printf "   ${RED}Délai dépassé${NC}\n"; return 1
    fi
  done
  printf "   ${GREEN}Service disponible (%ss)${NC}\n" "$i"
}

# Bilan final : code de sortie non nul si au moins un échec
summary() {
  echo "-----------------------------------------"
  if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}TP validé : %d vérification(s) réussie(s).${NC}\n" "$PASS"
    return 0
  else
    printf "${RED}TP non validé : %d échec(s) sur %d.${NC}\n" "$FAIL" "$((PASS+FAIL))"
    return 1
  fi
}
