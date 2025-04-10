# 🕷️ Spider ZSH Utils

ZSH utilities for Spider Strategies developers to streamline Git workflow and branch naming conventions.

![Demo](demo.png)

## Features

- 🧠 Auto-generates branch names like `issue-60938-field-widgets-have-a-span-with-a-nested-div-structure`
- 📌 Infers base branch from GitHub milestone (via `gh` CLI)
- 📁 Auto-cds into correct `~/impact/vXYZ` folder based on milestone
- 📝 Includes helpers for commit messages, issue IDs, and capitalization


## Installation

### Option 1 – Direct paste into `.zshrc`

```zsh
source /path/to/spider-utils.plugin.zsh
```

### Option 2 – Oh My Zsh plugin (recommended)

```bash
git clone git@github.com:nicholasnadel/spider-zsh-utils.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/spider-utils
```

Then add to your `.zshrc`:

```zsh
plugins=(... spider-utils)
```

Reload ZSH:

```zsh
source ~/.zshrc
```

## Usage

Create a new branch from a description with issue number:

```zsh
cb "Field widgets have a span with a nested div structure #60938"
```

This will:

- Switch to the correct milestone base branch
- Change directory to the correct version folder (e.g., `~/impact/v571`)
- Create and checkout:

```bash
issue-60938-field-widgets-have-a-span-with-a-nested-div-structure
```

### Aliases & Helpers

```zsh
id
# → Issue #60938

cm
# → issue #60938 - field widgets have a span with a nested div structure

fm
# → Fix #60938 - Field Widgets Have A Span With A Nested Div Structure
```

## Requirements

```bash
brew install gh jq
```