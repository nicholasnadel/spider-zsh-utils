##### 🔧 GENERAL GIT BRANCH UTILITIES #####

# Returns the current Git branch name (shorthand for `git rev-parse`)
function branch() {
	git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Extracts the issue number (e.g., "60938") from a branch like "issue-60938-description"
function extract_issue_number() {
	branch | grep -oE 'issue-[0-9]+' | cut -d- -f2
}

# Extracts the description slug (e.g., "field-widgets-structure") from the current branch
function extract_slug() {
	branch | cut -d- -f3-
}

# Echoes "Issue #[number]" (e.g., "Issue #60938")
function issueid() {
	local num=$(extract_issue_number)
	[[ -n "$num" ]] && echo "Issue #$num"
}
alias id='issueid'

# Returns a lowercase commit message (e.g., "Issue #60938 - field widgets structure")
function commitmessage() {
	local num=$(extract_issue_number)
	local title=$(extract_slug | tr '-' ' ')
	[[ -n "$num" && -n "$title" ]] && echo "issue #$num - $title"
}
alias cm='commitmessage'

# Returns a capitalized commit message (e.g., "Fix #60938 - Field Widgets Structure")
function fixmessage() {
	local num=$(extract_issue_number)
	local raw=$(extract_slug)
	local title=$(echo "$raw" | tr '-' ' ' | awk '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))} 1')
	[[ -n "$num" && -n "$title" ]] && echo "Fix #$num - $title"
}
alias fm='fixmessage'


##### 🧠 SPIDER BRANCH CREATION TOOL #####
# Usage:
# createbranch "Field widgets have a span with a nested div structure #60938"
# → Creates a Git branch: issue-60938-field-widgets-have-a-span-with-a-nested-div-structure
# → Detects milestone, attempts to cd to ~/impact/vXYZ folder

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
	if command -v gh >/dev/null && command -v jq >/dev/null; then
		echo "🔍 Attempting to fetch milestone using GitHub CLI..."
		local milestone=$(gh issue view "$issue_number" --json milestone | jq -r '.milestone.title')

		if [[ -n "$milestone" && "$milestone" != "null" ]]; then
			echo "✅ Found milestone: $milestone"

			if [[ "$milestone" =~ ^[56]\.[0-9]+\.[0-9]+$ ]]; then
				local version_digits=$(echo "$milestone" | tr -d '.')
				local impact_dir="$HOME/impact/v$version_digits"
				if [[ -d "$impact_dir" ]]; then
					echo "📂 Changing to $impact_dir"
					cd "$impact_dir"
				else
					echo "⚠️ Directory $impact_dir does not exist — staying in current dir"
				fi
			else
				echo "⚠️ Milestone format not recognized (expected x.y.z)"
			fi

			local milestone_desc=$(gh api repos/SpiderStrategies/Scoreboard/milestones \
				| jq -r ".[] | select(.title == \"$milestone\") | .description")
			source_branch=$(echo "$milestone_desc" | grep -o 'Branch from \*\*[^*]*\*\*' \
				| sed 's/Branch from \*\*//;s/\*\*//')

			if [[ -n "$source_branch" ]]; then
				echo "📄 Source branch from milestone description: $source_branch"
			else
				echo "⚠️ Milestone found but no branch info — falling back"
			fi
		else
			echo "⚠️ No milestone found — falling back"
		fi
	else
		echo "⚠️ GitHub CLI or jq not available — skipping milestone lookup"
		echo "💡 Tip: brew install gh jq"
	fi

	if [[ -z "$source_branch" ]]; then
		echo "🔎 Attempting to infer from current folder..."
		case "$PWD" in
			*impact*/v600*) source_branch="main" ;;
			*impact*/v571*) source_branch="branch-here-release-5.7.1" ;;
			*impact*/v570*) source_branch="branch-here-release-5.7.0" ;;
			*impact*/v562*) source_branch="branch-here-release-5.6.2" ;;
			*impact*/v561*) source_branch="branch-here-release-5.6.1" ;;
			*) source_branch="main" ;;
		esac
		echo "✅ Folder-based source branch: $source_branch"
	fi

	local issue_title=$(echo "$input" | sed -E 's/#?[0-9]+//g' | sed -E 's/issues\/[0-9]+//g' | xargs)
	local branch_slug=$(echo "$issue_title" \
		| tr '[:upper:]' '[:lower:]' \
		| tr -cs 'a-z0-9' '-' \
		| sed -E 's/^-+|-+$//g; s/-+/-/g')
	local branch_name="issue-${issue_number}-${branch_slug}"
	local commit_title_preview="Issue #${issue_number} - ${issue_title}"

	echo
	echo "📂 Base branch: $source_branch"
	echo "🌿 Branch name: $branch_name"
	echo "📝 Commit title preview: $commit_title_preview"
	echo
	read "REPLY?Run git checkout + branch create? [y/N] "
	if [[ "$REPLY" =~ ^[Yy]$ ]]; then
		if ! git rev-parse --verify "$source_branch" >/dev/null 2>&1; then
			echo "🔍 Source branch '$source_branch' not found locally. Fetching..."
			git fetch origin "$source_branch":"$source_branch"
			if [ $? -ne 0 ]; then
				echo "❌ Failed to fetch source branch '$source_branch'. Aborting."
				return 1
			fi
		fi

		echo "🔄 Switching to '$source_branch' and pulling latest changes..."
		git checkout "$source_branch" &&
		git pull origin "$source_branch" &&
		echo "🌿 Creating and switching to new branch '$branch_name'..." &&
		git checkout -b "$branch_name" &&
		echo "✅ Successfully created and checked out branch:" &&
		git branch --show-current
	else
		echo "❌ Cancelled"
	fi
}
alias cb='createbranch'
