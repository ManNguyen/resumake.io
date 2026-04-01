#!/usr/bin/env bash

set -euo pipefail

# ─────────────────────────────────────────────
#  resumake — install script
# ─────────────────────────────────────────────

BOLD="\033[1m"
DIM="\033[2m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/app/cli" && pwd)"

print_header() {
  echo ""
  echo -e "${BOLD}${CYAN}┌──────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${CYAN}│           resumake installer          │${RESET}"
  echo -e "${BOLD}${CYAN}└──────────────────────────────────────┘${RESET}"
  echo ""
}

print_step() {
  echo -e "${BOLD}  →${RESET} $1"
}

print_ok() {
  echo -e "  ${GREEN}✔${RESET}  $1"
}

print_warn() {
  echo -e "  ${YELLOW}⚠${RESET}  $1"
}

print_error() {
  echo -e "  ${RED}✖${RESET}  $1" >&2
}

# ─── Dependency check helpers ────────────────

check_node() {
  print_step "Checking Node.js..."
  if command -v node &>/dev/null; then
    local version
    version=$(node --version)
    print_ok "Node.js found: ${version}"
  else
    print_error "Node.js is not installed."
    echo ""
    echo -e "  ${DIM}Install it from: https://nodejs.org  (v10 or higher recommended)${RESET}"
    echo -e "  ${DIM}Or via a version manager: https://github.com/nvm-sh/nvm${RESET}"
    echo ""
    read -rp "  Attempt to install Node.js via nvm now? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      # shellcheck source=/dev/null
      [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
      nvm install --lts
      print_ok "Node.js installed via nvm."
    else
      print_error "Node.js is required. Aborting."
      exit 1
    fi
  fi
}

check_npm() {
  print_step "Checking npm..."
  if command -v npm &>/dev/null; then
    local version
    version=$(npm --version)
    print_ok "npm found: v${version}"
  else
    print_error "npm not found. It is normally bundled with Node.js."
    print_error "Please reinstall Node.js from https://nodejs.org"
    exit 1
  fi
}

check_latex_engine() {
  local cmd="$1"
  local pkg="$2"   # suggested package name
  if command -v "$cmd" &>/dev/null; then
    print_ok "${cmd} found"
    return 0
  else
    print_warn "${cmd} not found  ${DIM}(needed for some templates)${RESET}"
    echo ""
    read -rp "  Install ${cmd} now? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
      if command -v apt-get &>/dev/null; then
        sudo apt-get install -y "$pkg"
      elif command -v brew &>/dev/null; then
        brew install --cask mactex-no-gui
        echo -e "  ${DIM}Note: macOS users may need to restart their shell after MacTeX installs.${RESET}"
        return 0
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm "$pkg"
      elif command -v dnf &>/dev/null; then
        sudo dnf install -y "$pkg"
      else
        print_warn "Could not detect package manager. Install ${cmd} manually."
      fi
      if command -v "$cmd" &>/dev/null; then
        print_ok "${cmd} installed."
      else
        print_warn "${cmd} still not found — you may need to restart your shell."
      fi
    else
      print_warn "Skipping ${cmd}. Templates that require it will fail at runtime."
    fi
    echo ""
    return 0
  fi
}

check_latex_deps() {
  echo ""
  print_step "Checking LaTeX engines..."
  echo ""
  # pdflatex  — templates 1, 3, 5, 7, 9
  check_latex_engine "pdflatex"  "texlive-latex-base"
  # xelatex   — templates 2, 4, 6
  check_latex_engine "xelatex"   "texlive-xetex"
  # lualatex  — template 8
  check_latex_engine "lualatex"  "texlive-luatex"
}

# ─── Install ─────────────────────────────────

install_npm_deps() {
  echo ""
  print_step "Installing npm dependencies in app/cli..."
  (cd "$CLI_DIR" && npm install --silent)
  print_ok "npm packages installed."
}

link_cli() {
  echo ""
  print_step "Linking 'resumake' command globally..."
  if (cd "$CLI_DIR" && npm link 2>/dev/null); then
    print_ok "'resumake' is now available as a global command."
  else
    print_warn "npm link failed (may need sudo on some systems)."
    echo ""
    read -rp "  Retry with sudo? [y/N] " answer
    if [[ "${answer,,}" == "y" ]]; then
      (cd "$CLI_DIR" && sudo npm link)
      print_ok "'resumake' linked with sudo."
    else
      print_warn "Skipping global link."
      echo -e "  ${DIM}You can still run it directly:${RESET}"
      echo -e "  ${DIM}  node ${CLI_DIR}/bin/resumake.js resume.json -style1${RESET}"
    fi
  fi
}

# ─── Welcome ─────────────────────────────────

print_welcome() {
  echo ""
  echo -e "${BOLD}${GREEN}┌──────────────────────────────────────────────────────┐${RESET}"
  echo -e "${BOLD}${GREEN}│                                                      │${RESET}"
  echo -e "${BOLD}${GREEN}│   ✔  resumake installed successfully!                │${RESET}"
  echo -e "${BOLD}${GREEN}│                                                      │${RESET}"
  echo -e "${BOLD}${GREEN}└──────────────────────────────────────────────────────┘${RESET}"
  echo ""
  echo -e "  ${BOLD}Usage:${RESET}"
  echo -e "    ${CYAN}resumake${RESET} <path-to-resume.json> ${CYAN}-style<1-9>${RESET}"
  echo ""
  echo -e "  ${BOLD}Examples:${RESET}"
  echo -e "    resumake resume.json${DIM}              # style 1 (default)${RESET}"
  echo -e "    resumake resume.json ${CYAN}-style2${RESET}${DIM}      # FontAwesome modern${RESET}"
  echo -e "    resumake resume.json ${CYAN}-style4${RESET}${DIM}      # Deedy modern${RESET}"
  echo ""
  echo -e "  ${BOLD}Output:${RESET}  ${DIM}resume.pdf${RESET} in your current directory"
  echo ""
  echo -e "  ${DIM}Full template list: styles 1–9 (see README)${RESET}"
  echo ""
}

# ─── Main ────────────────────────────────────

main() {
  print_header
  check_node
  check_npm
  check_latex_deps
  install_npm_deps
  link_cli
  print_welcome
}

main
