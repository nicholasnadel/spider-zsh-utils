#!/bin/bash
# ^ Using bash explicitly, though zsh should mostly work

# --- Dependencies ---
# Requires: git, gh (GitHub CLI), jq

# --- Configuration ---
# Set your default GitHub owner/repo here if needed.
# If empty, the script will try to detect it from 'git remote get-url origin'.
DEFAULT_GITHUB_REPO="SpiderStrategies/Scoreboard" # <--- CONFIGURE THIS (or leave empty to auto-detect)

##### 🔧 GENERAL GIT BRANCH UTILITIES #####

# Returns the current Git branch name
function branch() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo ""; return; fi
    if git responds-to --show-current >/dev/null 2>&1; then
        git branch --show-current 2>/dev/null
    else
        git rev-parse --abbrev-ref HEAD 2>/dev/null
    fi
}

# Extracts issue number from the current branch name
function extract_issue_number() {
    local current_branch=$(branch)
    if [[ -z "$current_branch" ]]; then return; fi
    if [[ "$current_branch" =~ ^[^0-9]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$current_branch" | grep -oE '^issue-[0-9]+' | cut -d- -f2
    fi
}

# Extracts the slug part of the branch name
function extract_slug() {
    local current_branch=$(branch)
    if [[ -z "$current_branch" ]]; then return; fi
    echo "$current_branch" | sed -E 's/^[^0-9]*[0-9]+-//'
}

# Outputs "Issue #[number]" based on current branch
function issue_number() {
    local num=$(extract_issue_number)
    [[ -n "$num" ]] && echo "Issue #$num"
}
alias issue='issue_number'
alias in='issue_number'

# Lowercase commit message (does not close issue) based on current branch
function commit_message() {
    local num=$(extract_issue_number)
    if [[ -z "$num" ]]; then echo "Error: Not on an issue branch?"; return 1; fi
    local title_slug=$(extract_slug)
    local title=""
    if command -v gh >/dev/null && command -v jq >/dev/null; then
        title=$(gh issue view "$num" --json title --jq '.title // ""' 2>/dev/null | sed 's/[[:cntrl:]]//g')
    fi
    if [[ -z "$title" ]]; then
        title=$(echo "$title_slug" | tr '-' ' ')
    fi
    [[ -n "$num" && -n "$title" ]] && echo "issue #$num - $title"
}
alias cm='commit_message'

# Capitalized commit message (for auto-closing) based on current branch
function fixmessage() {
    local num=$(extract_issue_number)
    if [[ -z "$num" ]]; then echo "Error: Not on an issue branch?"; return 1; fi
    local title_slug=$(extract_slug)
    local title=""
    if command -v gh >/dev/null && command -v jq >/dev/null; then
        title=$(gh issue view "$num" --json title --jq '.title // ""' 2>/dev/null | sed 's/[[:cntrl:]]//g')
    fi
    if [[ -z "$title" ]]; then
        title=$(echo "$title_slug" | tr '-' ' ' | awk '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1')
    else
       title=$(echo "$title" | awk '{ $0 = toupper(substr($0,1,1)) tolower(substr($0,2)); print }')
    fi
    [[ -n "$num" && -n "$title" ]] && echo "Fix #$num - $title"
}
alias fm='fixmessage'

# Helper function to get owner/repo from git remote (Zsh-safe regex)
function _get_owner_repo() {
    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Error: Not inside a git repository." >&2
        return 1
    fi
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo "Error: Could not get URL for remote 'origin'." >&2
        return 1
    fi

    # Use separate checks for ':' (SSH) and '/' (HTTPS)
    if [[ "$remote_url" =~ github\.com:([^/]+)/([^/]+?)(\.git)?$ ]]; then # SSH format
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return 0
    elif [[ "$remote_url" =~ github\.com/([^/]+)/([^/]+?)(\.git)?$ ]]; then # HTTPS format
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return 0
    else
        echo "Error: Could not parse owner/repo from remote URL: $remote_url" >&2
        return 1
    fi
}


##### 🧠 SPIDER BRANCH CREATION TOOL (REVISED - Simplify Zsh Triggers) #####

function createbranch() {
    local input="$*" # Capture all arguments as the input

    if [[ -z "$input" ]]; then
        echo "❌ Usage: createbranch <github_issue_url | number | #number | text containing #number>"
        # ... (rest of usage message) ...
        return 1
    fi

    # Check dependencies
    # ... (gh, jq checks) ...

    local issue_identifier=""

    # --- Determine the issue identifier ---
    # (Input parsing logic is kept)
    # ... (if/elif/else for URL, #num, num, text) ...
    if [[ "$input" =~ ^https?:// ]]; then
        issue_identifier="$input"
    elif [[ "$input" =~ ^#([0-9]+)$ ]]; then
        issue_identifier="${BASH_REMATCH[1]}"
    elif [[ "$input" =~ ^([0-9]+)$ ]]; then
        issue_identifier="$input"
    else
        local extracted_num=$(echo "$input" | grep -oE '#[0-9]+' | head -n 1 | tr -d '#')
        if [[ -n "$extracted_num" ]]; then
             issue_identifier="$extracted_num"
        elif [[ "$input" =~ github\.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
             local extracted_partial_num="${BASH_REMATCH[3]}"
             issue_identifier="$extracted_partial_num"
        else
             echo "❌ Error: Cannot determine issue identifier from input '$input'."
             # ... (rest of error message) ...
             return 1
        fi
    fi
    # --- End of Identifier Determination ---


    if [[ -z "$issue_identifier" ]]; then
         echo "❌ Error: Could not determine issue identifier after analysis (variable is empty)."
         return 1
    fi

    echo "🔍 Fetching issue details using 'gh --json ... --jq' for identifier: '$issue_identifier'..."

    local issue_number issue_title milestone milestone_title

    # --- Fetch fields individually using gh --json field --jq '.field' ---
    # (gh calls kept from previous version)
    issue_number_raw=$(gh issue view "$issue_identifier" --json number --jq '.number' 2>&1)
    # ... (error check issue_number_raw) ...
    issue_number="$issue_number_raw"

    issue_title_raw=$(gh issue view "$issue_identifier" --json title --jq '.title // ""' 2>&1)
    # ... (error check issue_title_raw, sanitize) ...
    issue_title=$(echo "$issue_title_raw" | sed 's/[[:cntrl:]]//g')

    echo "✅ Fetched Issue #$issue_number: $issue_title"

    # --- Handle milestone separately ---
    echo "⏳ Fetching milestone title..."
    milestone=""
    milestone_title_raw=$(gh issue view "$issue_identifier" --json milestone --jq '.milestone.title // ""' 2>&1)
    # ... (error check milestone_title_raw, sanitize) ...
    milestone_title=$(echo "$milestone_title_raw" | sed 's/[[:cntrl:]]//g')
    if [[ -n "$milestone_title" ]]; then
         milestone="$milestone_title"
         echo "✅ Found milestone: $milestone"
    fi
    if [[ -z "$milestone" ]]; then
        echo "ℹ️ Issue #$issue_number has no milestone assigned or milestone has no title."
    fi
    # --- End Milestone Handling ---


    local source_branch=""
    local suggested_dir=""

    # --- Milestone-based Logic (Uses $milestone variable) ---
    if [[ -n "$milestone" ]]; then
         # 1. Suggest Directory (unchanged)
         # ... (directory suggestion logic) ...

         # 2. Determine Source Branch from Milestone Description
         echo "⏳ Fetching milestone description to find source branch..."
         local repo_owner_repo="${DEFAULT_GITHUB_REPO}"
         local repo_detected_msg=""

         # Auto-detect repo if needed (Simplified stderr handling)
         if [[ -z "$repo_owner_repo" ]]; then
             echo "ℹ️ DEFAULT_GITHUB_REPO not set. Trying to detect from 'origin' remote..."
             repo_owner_repo=$(_get_owner_repo 2>/dev/null) # Redirect stderr to null
             local detect_status=$?
             if [[ $detect_status -ne 0 || -z "$repo_owner_repo" ]]; then
                 echo "❌ Error: Could not detect owner/repo from 'origin' remote. Please set DEFAULT_GITHUB_REPO variable." >&2
                 milestone="" # Clear milestone to skip description fetch
                 echo "⚠️ Skipping source branch detection based on milestone description."
                 repo_owner_repo=""
             else
                 repo_detected_msg=" (Detected: $repo_owner_repo)"
                 echo "✅ Detected repository: $repo_owner_repo"
             fi
         fi

         # Proceed only if we have a repo and milestone title
         if [[ -n "$repo_owner_repo" && -n "$milestone" ]]; then
             local api_repo_path="repos/${repo_owner_repo}/"
             local milestones_api_url="${api_repo_path}milestones"
             local milestone_desc_raw

             milestone_desc_raw=$(gh api "$milestones_api_url" --jq ".[] | select(.title == \"$milestone\") | .description // \"\"" 2>&1)
             local gh_api_exit_code=$?

             if [[ $gh_api_exit_code -eq 0 ]]; then
                 if [[ -n "$milestone_desc_raw" && "$milestone_desc_raw" != "null" ]]; then
                     local milestone_desc=$(echo "$milestone_desc_raw" | sed 's/[[:cntrl:]]//g')
                     if [[ -n "$milestone_desc" ]]; then
                         # Refactored grep/sed logic
                         source_branch=$(grep -oP '(?<=Branch from \*\*).*(?=\*\*)' <<< "$milestone_desc" 2>/dev/null)
                         local grep_status=$?
                         if [[ $grep_status -ne 0 || -z "$source_branch" ]]; then # Check if grep failed or returned empty
                             # Fallback to sed
                             source_branch=$(echo "$milestone_desc" | sed -n 's/.*Branch from \*\*\([^*]*\)\*\*.*/\1/p')
                         fi
                         source_branch=$(echo "$source_branch" | xargs) # Trim whitespace
                         [[ -n "$source_branch" ]] && echo "📄 Source branch from milestone description: $source_branch"
                     else
                         echo "⚠️ Milestone description for '$milestone' was empty after sanitization."
                     fi
                 else
                     echo "ℹ️ No description found for milestone '$milestone'."
                 fi
             else
                 echo "⚠️ Error fetching milestone description${repo_detected_msg} (gh api exit code: $gh_api_exit_code):"
                 echo "$milestone_desc_raw"
             fi
         fi
    fi
    # --- End Milestone-based Logic ---


    # --- Fallback source branch logic (unchanged) ---
    if [[ -z "$source_branch" ]]; then
       # ... (fallback logic based on directory) ...
       echo "✅ Fallback source branch set to: $source_branch"
    fi


    # --- Generate branch slug (unchanged) ---
    # ... (slug generation logic) ...
    local branch_name="issue-${issue_number}-${branch_slug}"
    local commit_title_preview="Issue #${issue_number} - ${issue_title}"


    # --- Plan Summary (unchanged) ---
    # ... (print plan details) ...


    # --- Confirmation Prompt (Zsh compatible) ---
    # (print -n / read -r kept from previous version)
    print -n "🚀 Proceed with branch creation? [y/N] "
    read -r REPLY
    echo


    # --- Git Operations ---
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        # ... (cd logic kept) ...
        # ... (cleanup function kept) ...
        # ... (trap EXIT ERR INT TERM kept) ...
        # ... (git commands kept) ...
        # ... (inner read prompt uses print -n / read -r) ...
        if git show-ref --verify --quiet refs/heads/"$branch_name"; then
            echo "⚠️ Branch '$branch_name' already exists."
            print -n "❓ Switch to existing branch '$branch_name'? [y/N] "
            read -r SWITCH_REPLY
            echo # Add newline
            # ... (rest of git branch exists logic) ...
        else
            # ... (git checkout -b logic) ...
        fi
        # ... (trap disable / cleanup call / return logic kept) ...
    else
        echo "❌ Operation cancelled by user."
        return 1
    fi
    # --- Function End ---
}
alias cb='createbranch'


##### 🧵 PULL REQUEST CREATION TOOL (Revised for Zsh Compatibility) #####

function openpr() {
    # ... (Dependency checks kept) ...
    # ... (Current branch / issue number extraction kept) ...
    # ... (gh fetch calls kept) ...
    # ... (Base branch logic kept) ...

    # Ask if PR should close issue (Zsh compatible)
    print -n "❓ Should this PR automatically close Issue #$issue_number on merge? [y/N] "
    read -r REPLY
    echo
    # ... (Set pr_body_prefix) ...

    # ... (Construct PR Title & Body) ...
    # ... (PR Plan Summary) ...

    # Confirmation Prompt (Zsh compatible)
    print -n "🚀 Open Pull Request now? [y/N] "
    read -r CREATE_REPLY
    echo

    # gh pr create command
    if [[ "$CREATE_REPLY" =~ ^[Yy]$ ]]; then
        # ... (gh pr create call and status check) ...
    else
        echo "❌ PR creation cancelled."
    fi
    # --- Function End ---
}
alias pr='openpr'

# Add a final command to potentially help shell parsing at EOF
true
# ----- End of file -----