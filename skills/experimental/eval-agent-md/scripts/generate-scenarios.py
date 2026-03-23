#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""
Auto-generate behavioral test scenarios from any CLAUDE.md or agent .md file.
Uses `claude -p --model sonnet` to analyze rules and produce testable scenarios.

Usage:
    ./generate-scenarios.py ~/.claude/CLAUDE.md
    ./generate-scenarios.py ~/.claude/CLAUDE.md -o /tmp/scenarios.yaml
    ./generate-scenarios.py ~/.claude/agents/reviewer.md --agent
"""
import argparse
import subprocess
import sys
from pathlib import Path

import yaml

from _common import claude_pipe, load_prompt, parse_json_response, strip_markdown_fences

SYSTEM_PROMPT = load_prompt("system.md")
EXAMPLES = load_prompt("examples.md")
AGENT_CONTEXT = load_prompt("context-agent.md")
SKILL_CONTEXT = load_prompt("context-skill.md")


def generate_scenarios(config_path: Path, is_agent: bool = False,
                       is_skill: bool = False) -> list[dict]:
    content = config_path.read_text()

    if is_skill:
        file_type = 'skill definition'
    elif is_agent:
        file_type = 'agent definition'
    else:
        file_type = 'CLAUDE.md configuration'

    context_hints = ""
    if is_agent:
        context_hints += AGENT_CONTEXT
    if is_skill:
        context_hints += SKILL_CONTEXT

    prompt = f"""Analyze this {file_type} file and generate behavioral test scenarios for each testable rule.

## Config File: {config_path.name}
```
{content}
```

{context_hints}

## Example Scenarios (for quality reference)
{EXAMPLES}

## Instructions
1. Read every rule, gate, and constraint in the file
2. For each testable rule, generate ONE scenario
3. Make prompts realistic — they should sound like real user requests
4. Make pass_criteria observable in text output (no tool checks)
5. Make fail_signals specific enough to avoid false positives
6. Include code snippets inline in prompts when needed to test code-related rules
7. Skip rules that can only be tested via multi-turn interaction or tool usage

Generate the JSON array now."""

    line_count = len(content.splitlines())
    timeout = max(120, line_count * 2)
    raw = claude_pipe(prompt, model="sonnet", system_prompt=SYSTEM_PROMPT, timeout=timeout)

    text = strip_markdown_fences(raw)
    scenarios = parse_json_response(text, expect_type=list)

    # Validate each scenario has required fields
    required = {"id", "rule", "prompt", "pass_criteria", "fail_signals"}
    valid = []
    for s in scenarios:
        missing = required - set(s.keys())
        if missing:
            print(f"  Warning: scenario '{s.get('id', '?')}' missing {missing}, skipping", file=sys.stderr)
            continue
        valid.append(s)

    return valid


def get_repo_name() -> str:
    """Detect repository name from git, fall back to current directory name."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return Path(result.stdout.strip()).name
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return Path.cwd().name


def main():
    parser = argparse.ArgumentParser(description="Generate behavioral test scenarios from CLAUDE.md")
    parser.add_argument("config", nargs="?", type=Path, help="Path to CLAUDE.md or agent .md file")
    parser.add_argument("-o", "--output", type=Path, help="Output YAML file (default: /tmp/eval-agent-md-<repo>-scenarios.yaml)")
    parser.add_argument("--repo-name", default=None, help="Repository name for output filename (auto-detected from git)")
    parser.add_argument("--agent", action="store_true", help="Treat input as agent definition file")
    parser.add_argument("--skill", action="store_true", help="Treat input as skill definition file (SKILL.md)")
    parser.add_argument("--self", action="store_true", dest="self_test",
                        help="Auto-resolve to this skill's own SKILL.md (implies --skill)")
    parser.add_argument("--model", default="sonnet", help="Model for generation (default: sonnet)")

    args = parser.parse_args()

    if args.self_test:
        args.config = Path(__file__).resolve().parent.parent / "SKILL.md"
        args.skill = True
        if not args.config.exists():
            print(f"Self-test SKILL.md not found: {args.config}", file=sys.stderr)
            sys.exit(1)
    elif args.config is None:
        parser.error("Either provide a config path or use --self")

    if not args.config.exists():
        print(f"File not found: {args.config}", file=sys.stderr)
        sys.exit(1)

    print(f"Analyzing {args.config.name}...", file=sys.stderr, end="", flush=True)
    scenarios = generate_scenarios(args.config, is_agent=args.agent, is_skill=args.skill)
    print(f" generated {len(scenarios)} scenarios", file=sys.stderr)

    chunks = []
    for s in scenarios:
        chunks.append(yaml.dump([s], default_flow_style=False, allow_unicode=True, sort_keys=False).rstrip())
    output = "\n\n".join(chunks) + "\n"

    if args.output:
        out_path = args.output
    else:
        repo_name = args.repo_name or get_repo_name()
        out_path = Path(f"/tmp/eval-agent-md-{repo_name}-scenarios.yaml")

    out_path.write_text(output)
    print(f"Saved to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
