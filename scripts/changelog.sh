#!/usr/bin/env bash
# scripts/changelog.sh
#
# Generates changelog entries from conventional commits since the last
# changelog update and prepends them to CHANGELOG.md.
#
# Usage:
#   bash scripts/changelog.sh             # Generate and update CHANGELOG.md
#   bash scripts/changelog.sh --dry-run   # Preview only, no file changes

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly CHANGELOG="${SCRIPT_DIR}/../CHANGELOG.md"

DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "${1}" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            printf 'Usage: %s [--dry-run]\n' "$(basename "${BASH_SOURCE[0]}")"
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "${1}" >&2
            exit 1
            ;;
    esac
done

# Convert a base-form verb to past tense.
# Prints empty string if the verb is not recognized.
_past_tense() {
    case "${1,,}" in
        add|adds)                 printf 'Added' ;;
        remove|removes)           printf 'Removed' ;;
        delete|deletes)           printf 'Deleted' ;;
        implement|implements)     printf 'Implemented' ;;
        create|creates)           printf 'Created' ;;
        update|updates)           printf 'Updated' ;;
        fix|fixes)                printf 'Fixed' ;;
        refactor|refactors)       printf 'Refactored' ;;
        reorganize|reorganizes)   printf 'Reorganized' ;;
        extract|extracts)         printf 'Extracted' ;;
        improve|improves)         printf 'Improved' ;;
        replace|replaces)         printf 'Replaced' ;;
        move|moves)               printf 'Moved' ;;
        rename|renames)           printf 'Renamed' ;;
        optimize|optimizes)       printf 'Optimized' ;;
        migrate|migrates)         printf 'Migrated' ;;
        introduce|introduces)     printf 'Introduced' ;;
        switch|switches)          printf 'Switched' ;;
        use|uses)                 printf 'Used' ;;
        enable|enables)           printf 'Enabled' ;;
        disable|disables)         printf 'Disabled' ;;
        allow|allows)             printf 'Allowed' ;;
        handle|handles)           printf 'Handled' ;;
        convert|converts)         printf 'Converted' ;;
        make|makes)               printf 'Made' ;;
        set|sets)                 printf 'Set' ;;
        change|changes)           printf 'Changed' ;;
        wrap|wraps)               printf 'Wrapped' ;;
        simplify|simplifies)      printf 'Simplified' ;;
        extend|extends)           printf 'Extended' ;;
        clean|cleans)             printf 'Cleaned' ;;
        organize|organizes)       printf 'Organized' ;;
        split|splits)             printf 'Split' ;;
        merge|merges)             printf 'Merged' ;;
        deprecate|deprecates)     printf 'Deprecated' ;;
        drop|drops)               printf 'Dropped' ;;
        restore|restores)         printf 'Restored' ;;
        revert|reverts)           printf 'Reverted' ;;
        bump|bumps)               printf 'Bumped' ;;
        integrate|integrates)     printf 'Integrated' ;;
        include|includes)         printf 'Included' ;;
        exclude|excludes)         printf 'Excluded' ;;
        validate|validates)       printf 'Validated' ;;
        generate|generates)       printf 'Generated' ;;
        parse|parses)             printf 'Parsed' ;;
        resolve|resolves)         printf 'Resolved' ;;
        reduce|reduces)           printf 'Reduced' ;;
        expand|expands)           printf 'Expanded' ;;
        adjust|adjusts)           printf 'Adjusted' ;;
        correct|corrects)         printf 'Corrected' ;;
        configure|configures)     printf 'Configured' ;;
        define|defines)           printf 'Defined' ;;
        clarify|clarifies)        printf 'Clarified' ;;
        document|documents)       printf 'Documented' ;;
        expose|exposes)           printf 'Exposed' ;;
        relax|relaxes)            printf 'Relaxed' ;;
        enforce|enforces)         printf 'Enforced' ;;
        ensure|ensures)           printf 'Ensured' ;;
        *)                        printf '' ;;
    esac
}

# Return a past-tense verb for a commit type (fallback when body has no known verb).
_type_verb() {
    case "${1}" in
        feat)     printf 'Added' ;;
        fix)      printf 'Fixed' ;;
        refactor) printf 'Refactored' ;;
        docs)     printf 'Documented' ;;
        chore)    printf 'Updated' ;;
        test)     printf 'Updated' ;;
        perf)     printf 'Improved' ;;
        ci)       printf 'Updated' ;;
        style)    printf 'Updated' ;;
        build)    printf 'Updated' ;;
        *)        printf 'Updated' ;;
    esac
}

# Format one conventional commit subject as a changelog bullet line.
# Examples:
#   "feat: add X (#5)"      → "- Added X. (#5)"
#   "fix: broken Y (#3)"    → "- Fixed broken Y. (#3)"
#   "refactor: reorganize Z (#8)" → "- Reorganized Z. (#8)"
format_entry() {
    local raw="${1}"

    # Match: type(scope): body  OR  type: body
    # (Stored in variables to avoid bash parser issues with ) in regex patterns)
    local conv_pattern='^([a-z]+)(\([^)]+\))?: (.+)$'
    local type body
    if [[ "${raw}" =~ ${conv_pattern} ]]; then
        type="${BASH_REMATCH[1]}"
        body="${BASH_REMATCH[3]}"
    else
        # Non-conventional commit: capitalize and use as-is
        printf -- '- %s.\n' "${raw^}"
        return
    fi

    # Strip trailing PR ref like "(#123)"
    local pr_pattern='^(.*[^ ]) +(\(#[0-9]+\))$'
    local pr_ref=""
    if [[ "${body}" =~ ${pr_pattern} ]]; then
        body="${BASH_REMATCH[1]}"
        pr_ref=" ${BASH_REMATCH[2]}"
    fi

    # Split body into first word and remainder
    local first_word rest
    first_word="${body%% *}"
    rest="${body#"${first_word}"}"
    rest="${rest# }"  # strip leading space from rest

    # Attempt past-tense conversion of first word
    local past_verb
    past_verb=$(_past_tense "${first_word}")

    local entry
    if [[ -n "${past_verb}" ]]; then
        entry="${past_verb}${rest:+ ${rest}}"
    else
        # First word not recognized: prepend type verb and keep full body
        entry="$(_type_verb "${type}") ${body}"
    fi

    # Capitalize, ensure single trailing period, then append PR ref
    entry="${entry^}"
    entry="${entry%.}"

    printf -- '- %s.%s\n' "${entry}" "${pr_ref}"
}

# Print commit subjects since the last CHANGELOG.md update.
# Excludes: chore:release commits (CI version bumps) and merge commits.
get_new_commits() {
    local last_commit
    last_commit=$(git log --format="%H" -- CHANGELOG.md 2>/dev/null | head -1 || true)

    if [[ -n "${last_commit}" ]]; then
        git log --no-merges --format="%s" "${last_commit}..HEAD" 2>/dev/null \
            | grep -v '^chore: release' \
            | grep -v '^Merge ' || true
    else
        git log --no-merges --format="%s" 2>/dev/null \
            | grep -v '^chore: release' \
            | grep -v '^Merge ' || true
    fi
}

# Format commit subjects into bullet entry lines.
build_entries() {
    local commits="${1}"
    local result="" line
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        result+="$(format_entry "${line}")"$'\n'
    done <<< "${commits}"
    printf '%s' "${result}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

TODAY=$(date +%Y-%m-%d)
NEW_COMMITS=$(get_new_commits)

if [[ -z "${NEW_COMMITS}" ]]; then
    printf 'No new commits since last changelog update.\n'
    exit 0
fi

ENTRIES=$(build_entries "${NEW_COMMITS}")

if [[ -z "${ENTRIES}" ]]; then
    printf 'No formatted entries to add.\n'
    exit 0
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '## %s\n\n%s\n' "${TODAY}" "${ENTRIES}"
    exit 0
fi

# Write entries to temp file — avoids special-character escaping issues in awk
TEMP_ENTRIES=$(mktemp)
TEMP_OUT=$(mktemp)
trap 'rm -f "${TEMP_ENTRIES}" "${TEMP_OUT}"' EXIT
printf '%s' "${ENTRIES}" > "${TEMP_ENTRIES}"

ENTRY_COUNT=$(grep -c '^- ' "${TEMP_ENTRIES}" || true)

if grep -q "^## ${TODAY}$" "${CHANGELOG}"; then
    # Today's section exists: insert new entries after the blank line that
    # follows the ## TODAY heading (entries appear at top of today's section)
    awk -v today="${TODAY}" -v ef="${TEMP_ENTRIES}" '
        BEGIN { in_today=0; inserted=0 }
        /^## / {
            in_today = ($0 == "## " today)
            print; next
        }
        in_today && !inserted && /^$/ {
            print
            while ((getline line < ef) > 0) { print line }
            inserted=1
            next
        }
        { print }
        END {
            if (in_today && !inserted) {
                printf "\n"
                while ((getline line < ef) > 0) { print line }
            }
        }
    ' "${CHANGELOG}" > "${TEMP_OUT}"
    mv "${TEMP_OUT}" "${CHANGELOG}"

    printf 'Appended %d entr%s to existing ## %s section.\n' \
        "${ENTRY_COUNT}" "$([[ ${ENTRY_COUNT} -eq 1 ]] && printf 'y' || printf 'ies')" "${TODAY}"
else
    # New section: insert after the "# Changelog" heading (line 1).
    # tail -n +3 skips the heading and the blank line that follows it so we
    # don't end up with a double blank line between sections.
    {
        head -1 "${CHANGELOG}"
        printf '\n## %s\n\n' "${TODAY}"
        cat "${TEMP_ENTRIES}"
        printf '\n'
        tail -n +3 "${CHANGELOG}"
    } > "${TEMP_OUT}"
    mv "${TEMP_OUT}" "${CHANGELOG}"

    printf 'Added ## %s section with %d entr%s.\n' \
        "${TODAY}" "${ENTRY_COUNT}" "$([[ ${ENTRY_COUNT} -eq 1 ]] && printf 'y' || printf 'ies')"
fi
