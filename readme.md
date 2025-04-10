# 🕷️ Spider ZSH Utils

ZSH utilities for Spider Strategies developers to streamline Git workflow and branch naming conventions.

## Features

- 🧠 Auto-generates branch names like `issue-60938-field-widgets-have-a-span-with-a-nested-div-structure`
- 📌 Infers base branch from GitHub milestone (via `gh` CLI)
- 📁 Auto-cds into correct `~/impact/vXYZ` folder based on milestone
- 📝 Includes helpers for commit messages, issue IDs, and capitalization

## Installation

### Option 1 – Direct paste into `.zshrc`

source /path/to/spider-utils.plugin.zsh

### Option 2 – Oh My Zsh plugin (recommended)

git clone git@github.com:nicholasnadel/spider-zsh-utils.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/spider-utils

Then add to your `.zshrc`:

plugins=(... spider-utils)

And reload your shell:

source ~/.zshrc

## Usage

Create a new branch from a description with issue number:

cb "Field widgets have a span with a nested div structure #60938"

This will:

- Switch to the correct milestone base branch
- Change directory to the correct version folder (e.g., ~/impact/v571)
- Create and checkout:  
  issue-60938-field-widgets-have-a-span-with-a-nested-div-structure

### Aliases & Helpers

id
# → Issue #60938

cm
# → issue #60938 - field widgets have a span with a nested div structure

fm
# → Fix #60938 - Field Widgets Have A Span With A Nested Div Structure

## Requirements

brew install gh jq