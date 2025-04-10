##### 🔧 GENERAL GIT BRANCH UTILITIES #####

# Returns the current Git branch name
function branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Extracts issue number from branch name
function extract_issue_number() {
	branch | grep -oE 'issue-[0-9]+' | cut -d- -f2
}

# Extracts the slug part of the branch name
function extract_slug() {
	branch | cut -d- -f3-
}

# Outputs "Issue #[number]"
function issue_number() {
	local num=$(extract_issue_number)
	[[ -n "$num" ]] && echo "Issue #$num"
}
alias issue='issue_number'
alias in='issue_number'

# Lowercase commit message (does not close issue)
function commit_message() {
	local num=$(extract_issue_number)
	local title=$(extract_slug | tr '-' ' ')
	[[ -n "$num" && -n "$title" ]] && echo "issue #$num - $title"
}
alias cm='commit_message'

# Capitalized commit message (for auto-closing)
function fixmessage() {
	local num=$(extract_issue_number)
	local raw=$(extract_slug)
	local title=$(echo "$raw" | tr '-' ' ' | awk '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1')
	[[ -n "$num" && -n "$title" ]] && echo "Fix #$num - $title"
}
alias fm='fixmessage'


##### 🧠 SPIDER BRANCH CREATION TOOL #####

function createbranch() {
	local input="$*"
	local issue_number=$(echo "$input" | grep -oE '#[0-9]+' | tr -d '#')
	[[ -z "$issue_number" ]] && issue_number=$(echo "$input" | grep -oE 'issues/[0-9]+' | cut -d/ -f2)
	if [[ -z "$issue_number" ]]; then
		echo "❌ No issue number found"
		return 1
	fi

	echo "🔍 Using issue number: $issue_number"

	local source_branch=""
	local suggested_dir=""
	if command -v gh >/dev/null && command -v jq >/dev/null; then
		local milestone=$(gh issue view "$issue_number" --json milestone | jq -r '.milestone.title')
		if [[ -n "$milestone" && "$milestone" != "null" ]]; then
			echo "✅ Found milestone: $milestone"
			if [[ "$milestone" =~ ^[56]\.[0-9]+\.[0-9]+$ ]]; then
				local version_digits=$(echo "$milestone" | tr -d '.')
				suggested_dir="$HOME/impact/v$version_digits/app"
				if [[ -d "$suggested_dir" ]]; then
					echo "📂 Suggested directory: $suggested_dir"
				else
					echo "⚠️ Directory $suggested_dir does not exist — staying in current dir"
				fi
			else
				echo "⚠️ Milestone format not recognized"
			fi
			local milestone_desc=$(gh api repos/SpiderStrategies/Scoreboard/milestones | jq -r ".[] | select(.title == \"$milestone\") | .description")
			source_branch=$(echo "$milestone_desc" | grep -o 'Branch from \*\*[^*]*\*\*' | sed 's/Branch from \*\*//;s/\*\*//')
			[[ -n "$source_branch" ]] && echo "📄 Source branch from milestone description: $source_branch"
		fi
	fi

	if [[ -z "$source_branch" ]]; then
		case "$PWD" in
			*impact*/v600*) source_branch="main" ;;
			*impact*/v571*) source_branch="branch-here-release-5.7.1" ;;
			*impact*/v570*) source_branch="branch-here-release-5.7.0" ;;
			*impact*/v562*) source_branch="branch-here-release-5.6.2" ;;
			*impact*/v561*) source_branch="branch-here-release-5.6.1" ;;
			*) source_branch="main" ;;
		esac
		echo "✅ Fallback source branch: $source_branch"
	fi

	local issue_title=$(echo "$input" | sed -E 's/#?[0-9]+//g' | sed -E 's/issues\/[0-9]+//g' | xargs)
	local branch_slug=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -E 's/^-+|-+$//g; s/-+/-/g')
	local branch_name="issue-${issue_number}-${branch_slug}"
	local commit_title_preview="Issue #${issue_number} - ${issue_title}"

	echo
	echo "📂 Base branch: $source_branch"
	echo "🌿 Branch name: $branch_name"
	echo "📜 Commit title preview: $commit_title_preview"
	echo
	read "REPLY?Run git checkout + branch create? [y/N] "
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		if [[ -n "$suggested_dir" && -d "$suggested_dir/.git" ]]; then
			echo "📂 Entering $suggested_dir"
			cd "$suggested_dir"
		fi

		if ! git rev-parse --verify "$source_branch" >/dev/null 2>&1; then
			echo "🔍 Fetching missing base branch: $source_branch"
			git fetch origin "$source_branch":"$source_branch" || return 1
		fi

		git checkout "$source_branch" &&
		git pull origin "$source_branch" &&
		if git show-ref --verify --quiet refs/heads/"$branch_name"; then
			echo "⚠️ Branch '$branch_name' already exists. Switching..."
			git checkout "$branch_name"
		else
			echo "🌿 Creating and switching to '$branch_name'..."
			git checkout -b "$branch_name"
		fi
		echo "✅ Now on branch: $(git branch --show-current)"
	else
		echo "❌ Cancelled"
	fi
}
alias cb='createbranch'


##### 🧵 PULL REQUEST CREATION TOOL #####

function openpr() {
	local issue_number=$(extract_issue_number)
	local current_branch=$(branch)

	if [[ -z "$issue_number" || -z "$current_branch" ]]; then
		echo "❌ Missing branch or issue number"
		return 1
	fi

	echo "🔍 Fetching milestone for issue #$issue_number..."
	local milestone=""
	if command -v gh >/dev/null && command -v jq >/dev/null; then
		milestone=$(gh issue view "$issue_number" --json milestone | jq -r '.milestone.title')
	else
		echo "⚠️ GitHub CLI or jq not available"
	fi

	local base_branch="main"
	case "$milestone" in
		5.6.1) base_branch="branch-here-release-5.6.1" ;;
		5.6.2) base_branch="branch-here-release-5.6.2" ;;
		5.7.0) base_branch="branch-here-release-5.7.0" ;;
		5.7.1) base_branch="branch-here-release-5.7.1" ;;
		5.7.2) base_branch="main" ;;
		*)     base_branch="main" ;;
	esac

	echo "✅ Milestone: $milestone"
	echo "📂 Base branch for PR: **$base_branch**"
	echo
	read "REPLY?Should this PR close the issue on merge? [y/N] "
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		local pr_body="Fixes #$issue_number"
	else
		local pr_body="Issue #$issue_number"
	fi

	local issue_title=$(gh issue view "$issue_number" --json title | jq -r '.title')
	local pr_title="Issue #$issue_number - $issue_title"

	echo
	echo "🌿 Current branch: $current_branch"
	echo "📜 PR title: $pr_title"
	echo "📜 PR body: $pr_body"
	echo

	gh pr create \
		--base "$base_branch" \
		--head "$current_branch" \
		--title "$pr_title" \
		--body "$pr_body"
}
alias pr='openpr'
