"""
API Key Validator - Pre-execution validation for idea-explorer

Validates API keys before launching expensive agent pipelines.
Checks: presence -> format (regex) -> lightweight API call (zero tokens consumed).
All HTTP checks run concurrently via ThreadPoolExecutor to stay under 5 seconds.
"""

import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Set, Tuple
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError


HTTP_TIMEOUT = 5  # seconds per HTTP check

# Format patterns: (regex, human-readable hint)
KEY_FORMATS = {
    'ANTHROPIC_API_KEY': (r'^sk-ant-', 'sk-ant-...'),
    'OPENAI_API_KEY': (r'^sk-', 'sk-...'),
    'GITHUB_TOKEN': (r'^(ghp_|github_pat_)', 'ghp_... or github_pat_...'),
    'GOOGLE_API_KEY': (r'^AIza', 'AIza...'),
    'S2_API_KEY': (None, None),  # No known prefix
    'COHERE_API_KEY': (None, None),  # No known prefix
}

# Display order
ALL_KEYS = [
    'ANTHROPIC_API_KEY',
    'OPENAI_API_KEY',
    'GITHUB_TOKEN',
    'GOOGLE_API_KEY',
    'S2_API_KEY',
    'COHERE_API_KEY',
]


# ---------------------------------------------------------------------------
# Lightweight HTTP checks (zero tokens consumed)
# Each returns True if key is valid, False if definitely invalid.
# On network/timeout errors, returns True (format was already checked).
# ---------------------------------------------------------------------------

def _check_openai(key: str) -> bool:
    """GET /v1/models — lists available models, consumes zero tokens."""
    req = Request('https://api.openai.com/v1/models', method='GET')
    req.add_header('Authorization', f'Bearer {key}')
    try:
        with urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return resp.status == 200
    except HTTPError as e:
        # 401 = invalid key; other codes (429, 500) don't mean the key is bad
        return e.code != 401
    except (URLError, OSError):
        return True


def _check_anthropic(key: str) -> bool:
    """GET /v1/models — lists available models, consumes zero tokens."""
    req = Request('https://api.anthropic.com/v1/models', method='GET')
    req.add_header('x-api-key', key)
    req.add_header('anthropic-version', '2023-06-01')
    try:
        with urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return resp.status == 200
    except HTTPError as e:
        return e.code != 401
    except (URLError, OSError):
        return True


def _check_semantic_scholar(key: str) -> bool:
    """GET /graph/v1/paper/search?query=test&limit=1 — minimal search."""
    url = 'https://api.semanticscholar.org/graph/v1/paper/search?query=test&limit=1'
    req = Request(url, method='GET')
    req.add_header('x-api-key', key)
    try:
        with urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return resp.status == 200
    except HTTPError as e:
        # 403 = forbidden (bad key); others may be transient
        return e.code != 403
    except (URLError, OSError):
        return True


def _check_google(key: str) -> bool:
    """GET /v1/models?key=... — lists models, consumes zero tokens."""
    url = f'https://generativelanguage.googleapis.com/v1/models?key={key}'
    req = Request(url, method='GET')
    try:
        with urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return resp.status == 200
    except HTTPError as e:
        return e.code not in (400, 403)
    except (URLError, OSError):
        return True


# Map env var -> HTTP check function (None = skip HTTP check)
HTTP_CHECKS = {
    'ANTHROPIC_API_KEY': _check_anthropic,
    'OPENAI_API_KEY': _check_openai,
    'S2_API_KEY': _check_semantic_scholar,
    'GOOGLE_API_KEY': _check_google,
    'GITHUB_TOKEN': None,      # Already validated by GitHubManager
    'COHERE_API_KEY': None,    # No free health endpoint
}


def _get_required_keys(provider: str = 'claude', no_github: bool = False) -> Set[str]:
    """Determine which keys are required based on provider and flags."""
    required: Set[str] = set()

    if provider == 'claude':
        required.add('ANTHROPIC_API_KEY')
    elif provider == 'gemini':
        required.add('GOOGLE_API_KEY')
    # codex uses OAuth, no API key required

    if not no_github:
        required.add('GITHUB_TOKEN')

    return required


def validate_api_keys(provider: str = 'claude', no_github: bool = False) -> bool:
    """
    Validate all API keys before launching agents.

    Checks presence, format, and (where possible) makes a lightweight HTTP
    call to verify the key works. All HTTP checks run concurrently.

    Args:
        provider: AI provider (claude, gemini, codex)
        no_github: Whether GitHub integration is disabled

    Returns:
        True if all required keys pass validation, False otherwise.
    """
    required = _get_required_keys(provider, no_github)

    # status, message, is_required
    results: Dict[str, Tuple[str, str, bool]] = {}

    # Keys that need an HTTP check: (key_name, value, is_required)
    keys_to_http_check: List[Tuple[str, str, bool]] = []

    # --- Pass 1: presence + format ---
    for key_name in ALL_KEYS:
        value = os.environ.get(key_name, '').strip()
        is_required = key_name in required

        if not value:
            if is_required:
                results[key_name] = ('FAIL', 'Not set (REQUIRED)', True)
            else:
                results[key_name] = ('SKIP', 'Not set (optional)', False)
            continue

        # Check format
        pattern_info = KEY_FORMATS.get(key_name, (None, None))
        pattern, hint = pattern_info
        if pattern and not re.match(pattern, value):
            results[key_name] = ('WARN', f'Unexpected format (expected {hint})', is_required)
            # Still attempt HTTP check — maybe the format changed
            check_fn = HTTP_CHECKS.get(key_name)
            if check_fn:
                keys_to_http_check.append((key_name, value, is_required))
            continue

        # Queue for HTTP check or mark as set
        check_fn = HTTP_CHECKS.get(key_name)
        if check_fn:
            keys_to_http_check.append((key_name, value, is_required))
        elif key_name == 'GITHUB_TOKEN':
            results[key_name] = ('PASS', 'Set (checked elsewhere)', is_required)
        else:
            results[key_name] = ('PASS', 'Set', is_required)

    # --- Pass 2: concurrent HTTP validation ---
    if keys_to_http_check:
        with ThreadPoolExecutor(max_workers=len(keys_to_http_check)) as executor:
            future_to_key = {}
            for key_name, value, is_required in keys_to_http_check:
                check_fn = HTTP_CHECKS[key_name]
                future = executor.submit(check_fn, value)
                future_to_key[future] = (key_name, is_required)

            for future in as_completed(future_to_key, timeout=HTTP_TIMEOUT + 2):
                key_name, is_required = future_to_key[future]
                try:
                    valid = future.result(timeout=HTTP_TIMEOUT + 1)
                    if valid:
                        results[key_name] = ('PASS', 'Key is valid', is_required)
                    else:
                        results[key_name] = ('FAIL', 'Key is invalid (auth failed)', is_required)
                except Exception:
                    # Timeout or error — assume valid (format was already checked)
                    results[key_name] = ('PASS', 'Set (check timed out)', is_required)

    # --- Display results ---
    print()
    print("API Key Validation")
    print("=" * 60)

    any_required_failed = False

    for key_name in ALL_KEYS:
        if key_name not in results:
            continue

        status, message, is_required = results[key_name]
        req_label = "(required)" if is_required else "(optional)"

        if status == 'PASS':
            tag = "  [PASS]"
        elif status == 'FAIL':
            tag = "  [FAIL]"
            if is_required:
                any_required_failed = True
        elif status == 'WARN':
            tag = "  [WARN]"
        else:  # SKIP
            tag = "  [ -- ]"

        print(f"{tag} {key_name:<28s} {req_label:<12s} {message}")

    print("=" * 60)

    if any_required_failed:
        print()
        print("ERROR: One or more required API keys failed validation.")
        print("Fix the issues above or use --skip-validation to bypass.")
        print()
        return False

    print()
    return True


if __name__ == '__main__':
    # Standalone usage: python -m core.api_validator [provider]
    provider = sys.argv[1] if len(sys.argv) > 1 else 'claude'
    no_github = '--no-github' in sys.argv
    ok = validate_api_keys(provider=provider, no_github=no_github)
    sys.exit(0 if ok else 1)
