#!/bin/bash
# =============================================================================
# idea-explorer Container Entrypoint
# Validates environment, configures credentials, and starts the container
# =============================================================================

set -e

# Ensure PATH includes Python venv, uv-managed Python, and uv (in case not inherited from Dockerfile ENV)
export PATH="/app/.venv/bin:/python/bin:/usr/local/bin:${PATH}"

# Ensure PYTHONPATH includes /app for module imports
export PYTHONPATH="/app:${PYTHONPATH}"

# Handle running as arbitrary user (e.g., with --user flag)
# If HOME is not writable, use /tmp as home
if [ ! -w "${HOME:-/}" ]; then
    export HOME=/tmp
fi

# Restore Claude Code config if missing (lost between container restarts)
# Claude Code stores its config at $HOME/.claude.json (outside the .claude/ dir).
# The .claude/ directory is mounted from the host, but .claude.json is a sibling
# file that gets lost when the container is recreated (--rm). Claude Code backs it
# up inside .claude/backups/ which persists, so we restore the latest backup.
if [ ! -f "$HOME/.claude.json" ] && [ -d "$HOME/.claude/backups" ]; then
    latest_backup=$(ls -t "$HOME/.claude/backups/.claude.json.backup."* 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
        cp "$latest_backup" "$HOME/.claude.json"
    fi
fi

# Color output for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  idea-explorer Container Starting${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# Validate environment variables
# -----------------------------------------------------------------------------
validate_env() {
    echo -e "${BLUE}Checking environment...${NC}"

    # Check API keys: presence + format validation (prefix checks).
    # No HTTP calls here — keep container startup fast.
    # Full HTTP validation available via: python -m core.api_validator

    # Helper: check_key "ENV_VAR" "label" "required|optional" "prefix_pattern"
    check_key() {
        local var_name="$1"
        local label="$2"
        local required="$3"
        local prefix="$4"
        local value="${!var_name}"

        if [ -z "$value" ]; then
            if [ "$required" = "required" ]; then
                echo -e "  ${RED}[MISS]${NC} $var_name not set ($label)"
            else
                echo -e "  ${YELLOW}[INFO]${NC} $var_name not set ($label)"
            fi
            return
        fi

        # Format check (if prefix pattern provided)
        if [ -n "$prefix" ]; then
            if [[ "$value" == $prefix* ]]; then
                echo -e "  ${GREEN}[OK]${NC} $var_name configured ($label)"
            else
                # Special case: GITHUB_TOKEN accepts ghp_ or github_pat_
                if [ "$var_name" = "GITHUB_TOKEN" ] && [[ "$value" == github_pat_* ]]; then
                    echo -e "  ${GREEN}[OK]${NC} $var_name configured ($label)"
                else
                    echo -e "  ${YELLOW}[WARN]${NC} $var_name set but unexpected format (expected ${prefix}...) ($label)"
                fi
            fi
        else
            echo -e "  ${GREEN}[OK]${NC} $var_name configured ($label)"
        fi
    }

    check_key "ANTHROPIC_API_KEY" "Claude API access"        "optional"  "sk-ant-"
    check_key "OPENAI_API_KEY"    "IdeaHub, paper-finder"    "optional"  "sk-"
    check_key "GITHUB_TOKEN"      "GitHub repo creation"     "optional"  "ghp_"
    check_key "GOOGLE_API_KEY"    "Google/Gemini API access" "optional"  "AIza"
    check_key "S2_API_KEY"        "paper-finder"             "optional"  ""
    check_key "COHERE_API_KEY"    "paper-finder reranking"   "optional"  ""

    unset -f check_key
    echo ""
}

# -----------------------------------------------------------------------------
# Configure git credentials
# -----------------------------------------------------------------------------
setup_git() {
    if [ -n "$GITHUB_TOKEN" ]; then
        echo -e "${BLUE}Configuring Git credentials...${NC}"

        # Configure credential helper
        git config --global credential.helper store

        # Store credentials securely
        echo "https://oauth2:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
        chmod 600 ~/.git-credentials

        # Configure GitHub CLI if available
        if command -v gh &> /dev/null; then
            echo "$GITHUB_TOKEN" | gh auth login --with-token 2>/dev/null || true
        fi

        echo -e "  ${GREEN}[OK]${NC} Git credentials configured"
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Check GPU availability
# -----------------------------------------------------------------------------
check_gpu() {
    echo -e "${BLUE}GPU Status:${NC}"

    if command -v nvidia-smi &> /dev/null; then
        if nvidia-smi &> /dev/null; then
            nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader | \
                while IFS=',' read -r idx name mem driver; do
                    echo -e "  ${GREEN}[GPU $idx]${NC} $name |$mem | Driver:$driver"
                done
        else
            echo -e "  ${YELLOW}[WARN]${NC} nvidia-smi failed - GPU may not be accessible"
            echo "         Ensure --gpus all flag is used when running the container"
        fi
    else
        echo -e "  ${DIM}[CPU]${NC} No GPU detected (CPU-only mode)"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# Start paper-finder service (if S2_API_KEY is configured)
# -----------------------------------------------------------------------------
start_paper_finder() {
    echo -e "${BLUE}Paper-finder Service:${NC}"

    if [ -n "$S2_API_KEY" ]; then
        if [ -n "$OPENAI_API_KEY" ]; then
            echo -e "  ${GREEN}[OK]${NC} S2_API_KEY configured"

            # Check if paper-finder is installed
            if [ -d "/app/services/paper-finder" ]; then
                echo "  Starting paper-finder service..."

                # Create logs directory if needed
                mkdir -p /app/logs

                # Start paper-finder in background
                cd /app/services/paper-finder/agents/mabool/api
                nohup make start-dev >> /app/logs/paper-finder.log 2>&1 &
                PAPER_FINDER_PID=$!
                cd /workspaces

                # Wait for paper-finder to be healthy (max 60 seconds)
                for i in {1..60}; do
                    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
                        echo -e "  ${GREEN}[OK]${NC} Paper-finder started at localhost:8000"
                        if [ -n "$COHERE_API_KEY" ]; then
                            echo -e "  ${GREEN}[OK]${NC} COHERE_API_KEY configured (full reranking)"
                        else
                            echo -e "  ${YELLOW}[INFO]${NC} COHERE_API_KEY not set (reranking disabled, 92.5% quality)"
                        fi
                        echo ""
                        return 0
                    fi
                    sleep 1
                done
                echo -e "  ${YELLOW}[WARN]${NC} Paper-finder failed to start - using manual search fallback"
                echo "         Check /app/logs/paper-finder.log for errors"
            else
                echo -e "  ${YELLOW}[WARN]${NC} Paper-finder not installed"
            fi
        else
            echo -e "  ${YELLOW}[WARN]${NC} OPENAI_API_KEY required for paper-finder"
        fi
    else
        echo -e "  ${YELLOW}[INFO]${NC} S2_API_KEY not set - paper-finder disabled"
        echo "         Agents will use manual search (arXiv, Semantic Scholar, Papers with Code)"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# Display available commands
# -----------------------------------------------------------------------------
show_help() {
    echo -e "${BLUE}Available Commands:${NC}"
    echo ""
    echo "  Fetch idea from IdeaHub:"
    echo -e "    ${GREEN}python /app/src/cli/fetch_from_ideahub.py <url> [--submit]${NC}"
    echo ""
    echo "  Submit a research idea:"
    echo -e "    ${GREEN}python /app/src/cli/submit.py <idea.yaml>${NC}"
    echo ""
    echo "  Run research exploration:"
    echo -e "    ${GREEN}python /app/src/core/runner.py <idea_id> [options]${NC}"
    echo ""
    echo "  Options for runner.py:"
    echo "    --provider {claude|codex|gemini}  AI provider (default: claude)"
    echo "    --full-permissions                Skip permission prompts"
    echo "    --no-github                       Run locally without GitHub"
    echo "    --timeout SECONDS                 Execution timeout (default: 3600)"
    echo ""
    echo -e "${BLUE}Workspace:${NC} /workspaces (mounted from host)"
    echo -e "${BLUE}App:${NC} /app"
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

# Run all setup steps
validate_env
setup_git
check_gpu
start_paper_finder

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Container Ready${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

show_help

# Execute the command passed to the container
exec "$@"
