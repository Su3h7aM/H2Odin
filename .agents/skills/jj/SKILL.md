---
name: jj
description: Use Jujutsu (jj) as the primary VCS interface for Git-backed repositories. Required for repositories with `.jj/`. Prefer `jj` over raw `git` for status, diff, commit description, rebase, bookmark, push, conflict resolution, and history inspection. Use compact, explicit, non-interactive commands suitable for agents. Prefer the `jj desc` + `jj new` workflow instead of `jj commit`.
---

# Jujutsu (`jj`) for Agents

Use `jj` as the primary version-control interface. Treat Git as the backend, transport, authentication layer, and compatibility layer only.

This skill is optimized for automated/non-interactive agent environments.

## Activation Rules

Always activate this skill before any VCS operation when any of the following is true:

* The repository contains `.jj/`.
* The user mentions Jujutsu, `jj`, bookmarks, revsets, change IDs, divergent commits, or working-copy commits.
* Git appears to be in detached HEAD but `.jj/` exists.
* You need to run status, diff, commit description, branch/bookmark, rebase, fetch, push, restore, abandon, undo, or conflict-resolution commands.

If `.jj/` exists, do not use raw `git` to mutate repository state unless the user explicitly requires a Git-only operation and you understand the colocated Git/JJ consequences.

## Hard Rules

* Prefer `jj` over `git` for repository mutation.
* Prefer non-interactive commands.
* Prefer the `jj desc` + `jj new` workflow over `jj commit`.
* Always start new work from an empty working-copy commit.
* Before editing, set a WIP description with `jj desc -m "WIP: ..."` describing the intended work.
* After editing, replace the WIP description with the final project-style commit description using `jj desc -m "..."`
* After finalizing the description, run `jj new` to create the next empty working-copy commit.
* Use explicit `-m`, `-r`, `--from`, `--to`, `--bookmark`, `--change`, and filesets/revsets.
* Use `--no-pager` for commands that produce output.
* Use `--git` for diffs when human-readable unified diff is desired.
* Avoid editor, pager, TUI, and merge UI by default.
* Never run interactive commands from plain `bash`.
* Avoid `jj split`, `jj squash -i`, `jj diffedit`, and `jj resolve` in agent mode unless an interactive shell tool and an explicit interactive-shell skill are available.
* After mutations, verify with `jj --no-pager st` and, when relevant, `jj --no-pager log`.
* If official behavior is unclear or version-dependent, check the official docs instead of guessing.

## Core Model

### Working Copy

In `jj`, the working copy is itself a commit.

* `@` is the current working-copy commit.
* `@-` is the parent of `@`.
* Most `jj` commands snapshot the working copy before running.
* There is no Git-style dirty area outside history.
* There is no staging area/index workflow.
* New, modified, and deleted tracked files are recorded automatically in the working-copy commit.

Common inspection commands:

```bash
jj --no-pager st
jj --no-pager diff --git
jj --no-pager show @ --git
```

A normal agent workflow should end with an empty `@` on top of the completed change. In that state, the completed change is `@-`, and the current working copy `@` is empty.

### No Staging Area

Do not use Git-index mental models.

Git habit:

```bash
git add -p
git commit
```

JJ preferred agent workflow:

```bash
# Ensure @ is empty first
jj --no-pager st

# Describe intended work
jj desc -m "WIP: Add input validation"

# edit files

# Review
jj --no-pager st
jj --no-pager diff --git

# Finalize description
jj desc -m "feat: add input validation"

# Move to next empty working-copy commit
jj new
```

Interactive alternatives exist but should usually be avoided in agent mode:

```bash
jj split       # interactive
jj squash -i  # interactive
jj diffedit    # interactive
```

### Change IDs vs Commit IDs

Use change IDs when referencing mutable commits.

* Change ID: stable across rewrites.
* Commit ID: content hash; changes when the commit is rewritten.

For scripts, disambiguate:

```bash
jj --no-pager show 'change_id(<prefix>)'
jj --no-pager show 'commit_id(<prefix>)'
```

Use `exactly(<revset>, 1)` when a command must target one commit.

## Preferred Agent Workflow

### 1. Inspect Repository State

Always start by inspecting the current state:

```bash
jj --no-pager st
jj --no-pager log -r 'reachable(@, mutable())'
```

### 2. Ensure Working Copy Is Empty

Before starting any new work, the agent must ensure `@` is an empty working-copy commit.

If `jj st` shows no changes and the current commit is empty, continue.

If `@` contains unrelated user changes, do not overwrite, squash, abandon, or modify them. Create a new working-copy commit on top of the current commit:

```bash
jj new
```

If starting from a specific base, use an explicit revision:

```bash
jj new trunk()
jj new main
jj new main@origin
```

After creating the new working-copy commit, verify:

```bash
jj --no-pager st
```

Expected state: no changes, empty working-copy commit.

### 3. Set WIP Description Before Editing

Before making changes, describe the intended work:

```bash
jj desc -m "WIP: {brief description of intended work}"
```

Examples:

```bash
jj desc -m "WIP: Add subagent spawn tool"
jj desc -m "WIP: Refactor workspace path creation"
jj desc -m "WIP: Remove legacy get_subagent_result tool"
```

The WIP description should be specific enough to explain what the agent is about to do, but it does not need to be the final commit message.

### 4. Do the Work

Edit files normally.

`jj` automatically snapshots file changes into the current working-copy commit.

Inspect frequently:

```bash
jj --no-pager st
jj --no-pager diff --git
```

### 5. Review the Actual Change

Before finalizing, review the actual diff:

```bash
jj --no-pager st
jj --no-pager diff --git
jj --no-pager show @ --git
```

Check:

* The change is atomic.
* The diff matches the intended task.
* There are no unrelated edits.
* Generated files, lockfiles, snapshots, and formatting changes are intentional.
* Tests or validation commands were run when appropriate.

### 6. Replace WIP Description With Final Commit Description

Do not use `jj commit` as the preferred finishing step.

Instead, replace the WIP description:

```bash
jj desc -m "{type}: {final real description}"
```

The final description must match the actual change, not the original intention.

Use the project’s existing commit convention when detectable from history:

```bash
jj --no-pager log -r 'trunk()..@ | ancestors(@, 20)' --no-graph
```

Common examples:

```bash
jj desc -m "feat: add subagent spawn tool"
jj desc -m "fix: isolate agent workspace paths by session"
jj desc -m "refactor: remove legacy subagent result polling"
jj desc -m "docs: document jj workflow for agents"
```

If the project does not have a clear convention, use a concise imperative sentence:

```bash
jj desc -m "Add subagent spawn tool"
```

### 7. Create the Next Empty Working-Copy Commit

After finalizing the description, run:

```bash
jj new
```

This leaves the repository ready for the next task.

After `jj new`:

* `@-` is the completed change.
* `@` is the new empty working-copy commit.

Verify:

```bash
jj --no-pager st
jj --no-pager log -r '@-::@'
```

## Default Safe Loop

Use this loop for most agent work:

```bash
jj --no-pager st
jj --no-pager log -r 'reachable(@, mutable())'

# Ensure @ is empty before starting.
# If @ has unrelated work:
jj new

jj desc -m "WIP: Implement focused change"

# edit files

jj --no-pager st
jj --no-pager diff --git
jj --no-pager show @ --git

# Replace WIP with final project-style description.
jj desc -m "feat: implement focused change"

# Leave a fresh empty working copy for the next task.
jj new

jj --no-pager st
jj --no-pager log -r '@-::@'
```

## When `jj commit` May Be Used

`jj commit -m` is valid JJ, but it is not the preferred workflow for agents using this skill.

Avoid this as the default:

```bash
jj commit -m "feat: implement focused change"
```

Prefer this:

```bash
jj desc -m "feat: implement focused change"
jj new
```

Reason: the preferred workflow keeps the mental model explicit. The agent works inside the current working-copy commit, updates its description, then explicitly creates the next empty working-copy commit.

Use `jj commit -m` only when:

* The repository or user explicitly expects that workflow.
* A script or automation already relies on it.
* You are adapting existing instructions and cannot safely change the flow.

## Commit Message Policy

Final commit descriptions should follow the current project’s convention.

Before choosing the final format, inspect recent history:

```bash
jj --no-pager log -r 'ancestors(@, 20)' --no-graph
```

If the project uses Conventional Commits, use:

```text
feat: add new behavior
fix: correct broken behavior
refactor: restructure without behavior change
docs: update documentation
test: add or update tests
chore: update tooling or maintenance
ci: update CI configuration
build: update build system or dependencies
perf: improve performance
style: formatting-only change
```

If the project does not use Conventional Commits, use an imperative sentence without a trailing period:

```text
Add subagent spawn tool
Fix workspace cleanup isolation
Remove legacy result polling
```

Do not leave final descriptions as:

```text
WIP: ...
changes
update
fix
misc
work
```

## Bookmarks

JJ uses bookmarks, not current branches.

Important facts:

* Bookmarks are named pointers to revisions.
* There is no active/current/checked-out bookmark.
* Creating commits on top of a bookmark does not automatically move the bookmark.
* Bookmarks can move automatically when their target commit is rewritten by `jj` operations such as rebase.
* Local bookmarks map to Git branches when pushing/fetching.
* Remote bookmark syntax is `<name>@<remote>`, for example `main@origin`.

List bookmarks:

```bash
jj --no-pager bookmark list
```

Create bookmark at completed change after the preferred workflow:

```bash
jj bookmark create my-feature -r @-
```

Move bookmark to completed change:

```bash
jj bookmark move my-feature --to @-
```

Create bookmark at current working copy only when `@` is intentionally the completed change:

```bash
jj bookmark create my-feature -r @
```

Delete bookmark:

```bash
jj bookmark delete my-feature
```

Forget bookmark locally without propagating deletion:

```bash
jj bookmark forget my-feature
```

Track remote bookmark:

```bash
jj bookmark track my-feature
jj bookmark track main@origin
```

Untrack remote bookmark:

```bash
jj bookmark untrack main@origin
```

## Git Backend and Colocated Repositories

Most Git-backed `jj` repositories are colocated: both `.jj/` and `.git/` exist.

Initialize or clone:

```bash
jj git clone <url>
jj git init --colocate
```

Colocated behavior:

* `.jj/` and `.git/` are both present.
* Git tools that require `.git` can often work.
* Git may show detached HEAD; this is normal with `jj`.
* `jj` automatically imports/exports Git refs in colocated repos.
* Raw Git mutation can create confusing divergence if mixed carelessly with JJ mutation.
* Git staging area is ignored by `jj`.
* Unfinished Git operations such as Git rebase/merge are not JJ workflows.
* Git tools generally do not understand JJ conflict representation.

Avoid raw Git for mutation:

```bash
# Prefer
jj bookmark move feature --to @-
jj git push --bookmark feature

# Avoid unless explicitly required
git checkout feature
git commit
git rebase
git push
```

## Fetching and Updating

There is no direct documented `jj pull` equivalent.

Use fetch plus explicit rebase:

```bash
jj git fetch
jj rebase -o trunk()
```

For remote trunk:

```bash
jj git fetch --remote origin
jj rebase -o main@origin
```

If multiple active stacks exist, rebase each stack explicitly:

```bash
jj rebase -b feature-a -o main@origin
jj rebase -b feature-b -o main@origin
```

Inspect before and after:

```bash
jj --no-pager log -r 'remote_bookmarks()..'
jj --no-pager st
```

## Pushing

Push only when the user explicitly asks or when the task clearly requires it.

Before pushing:

```bash
jj --no-pager st
jj --no-pager log -r 'trunk()..@'
jj --no-pager log -r 'trunk()..@-'
jj --no-pager bookmark list
```

In the preferred workflow, after `jj desc ...` and `jj new`, the completed change is normally `@-`.

### Push With Generated Bookmark

Preferred when no stable bookmark name is needed:

```bash
jj git push --change @-
```

If current `@` contains the actual completed change because `jj new` has not yet been run:

```bash
jj git push --change @
```

### Push Named Bookmark

Create or move a bookmark to the completed change:

```bash
jj bookmark create my-feature -r @-
jj bookmark track my-feature
jj git push --bookmark my-feature
```

For an existing bookmark:

```bash
jj bookmark move my-feature --to @-
jj git push --bookmark my-feature
```

Or push tracked bookmarks that are eligible:

```bash
jj git push
```

Do not assume `jj git push --all` pushes every commit. It pushes bookmarks, not arbitrary revisions.

## Conflicts

Conflicts are first-class commit state in JJ.

Important facts:

* Commands can create commits with conflicts.
* There is usually no Git-style `--continue` flow.
* Descendants can be automatically rebased on top of conflicted commits.
* Resolve conflicts by editing files, then snapshotting/squashing/describing normally.
* Avoid `jj resolve` in agent mode because it may invoke interactive tooling.

Inspect conflicts:

```bash
jj --no-pager st
jj --no-pager log -r 'conflicts()'
jj --no-pager show @ --git
```

Preferred non-interactive resolution flow:

```bash
jj new <conflicted-rev>
jj desc -m "WIP: Resolve conflicts in <area>"

# edit conflicted files directly

jj --no-pager diff --git
jj --no-pager st

jj desc -m "fix: resolve conflicts in <area>"
jj new
```

Alternative, only when direct in-place editing is better:

```bash
jj edit <conflicted-rev>

# edit files directly

jj --no-pager st
jj desc -m "fix: resolve conflicts in <area>"
jj new
```

Do not leave conflict markers unresolved unless explicitly requested.

## Restoring, Moving, and Cleaning Changes

Restore current change from parent:

```bash
jj restore
```

Restore specific files from parent:

```bash
jj restore path/to/file
```

Restore files from a specific revision:

```bash
jj restore --from <rev> path/to/file
```

Move current changes into parent:

```bash
jj squash
```

Move current changes into parent with message:

```bash
jj squash -m "Update parent change"
```

Automatically absorb current changes into ancestor commits that last touched the same lines:

```bash
jj absorb
```

Abandon a commit:

```bash
jj abandon <rev>
```

Abandon an empty current working-copy commit if needed:

```bash
jj abandon @
```

Undo last repository operation:

```bash
jj undo
```

Inspect operation history:

```bash
jj --no-pager op log
```

Redo if supported by installed version:

```bash
jj redo
```

## Tracking and Ignored Files

By default:

* New files are auto-tracked.
* Modified tracked files are auto-recorded.
* Deleted tracked files are auto-recorded.
* Ignored files are not auto-tracked.

If a file should stop being tracked but remain on disk:

```bash
jj file untrack path/to/file
```

Make sure the file is ignored before or immediately after untracking; otherwise it may be tracked again by a later snapshot.

```bash
echo 'path/to/file' >> .gitignore
jj file untrack path/to/file
jj --no-pager st
```

## Revsets

Revsets select commits. Use them with `-r` and wherever commands accept revisions.

Core symbols:

```text
@                 current working-copy commit
@-                parent of @
<workspace>@      working copy in another workspace
<name>@<remote>   remote bookmark/tag
```

Operators:

```text
x-        parents of x
x+        children of x
::x       ancestors of x, including x
x::       descendants of x, including x
x..y      ancestors of y excluding ancestors of x
x::y      ancestry path from x to y
x..       everything not in ancestors of x
~x        complement of x
x & y     intersection
x | y     union
x ~ y     subtraction
```

Use parentheses in nontrivial expressions.

Symbol resolution priority:

1. Tag
2. Bookmark
3. Git ref
4. Commit ID or change ID

For scripts, prefer explicit functions:

```bash
jj --no-pager show 'commit_id(abc123)'
jj --no-pager show 'change_id(tqpwlq)'
jj --no-pager show 'exactly(bookmarks(main), 1)'
```

Useful revset functions:

```text
parents(x[, depth])
children(x[, depth])
ancestors(x[, depth])
descendants(x[, depth])
first_parent(x[, depth])
first_ancestors(x[, depth])
reachable(srcs, domain)
connected(x)
all()
none()
heads(x)
roots(x)
latest(x[, count])
fork_point(x)
merges()
visible_heads()
root()
bookmarks([pattern])
remote_bookmarks([name], [remote])
tracked_remote_bookmarks(...)
untracked_remote_bookmarks(...)
tags([pattern])
description(pattern)
subject(pattern)
author(pattern)
author_name(pattern)
author_email(pattern)
author_date(pattern)
mine()
committer(pattern)
committer_date(pattern)
signed()
empty()
conflicts()
divergent()
files(fileset)
diff_lines(text[, files])
diff_lines_added(text[, files])
diff_lines_removed(text[, files])
present(x)
coalesce(a, b, ...)
working_copies()
at_operation(op, x)
trunk()
immutable()
mutable()
visible()
hidden()
```

String patterns:

```text
exact:"..."
glob:"..."
glob-i:"..."
regex:"..."
substring:"..."
```

Date patterns:

```text
after:"2026-01-01"
before:"2 days ago"
```

Revset recipes:

```bash
jj --no-pager log -r @
jj --no-pager log -r ::@
jj --no-pager log -r 'trunk()..@'
jj --no-pager log -r 'trunk()..@-'
jj --no-pager log -r 'remote_bookmarks()..'
jj --no-pager log -r 'remote_bookmarks(remote=origin)..'
jj --no-pager log -r '(remote_bookmarks()..@)::'
jj --no-pager log -r 'mine() & bookmarks() & ~remote_bookmarks()'
jj --no-pager log -r 'author(regex:"Alice") & description(substring:"fix")'
jj --no-pager show -r 'exactly(bookmarks(main), 1)'
jj --no-pager diff --git -r 'fork_point(@ | trunk())..@'
jj --no-pager log -r 'reachable(@, mutable())'
jj --no-pager log -r 'conflicts()'
jj --no-pager log -r 'divergent()'
```

## Filesets

Filesets select paths. Use them with `jj diff`, `jj file list`, path-aware revsets, and templates.

Pattern kinds:

```text
cwd:"path"
file:"path"
glob:"pattern"
prefix-glob:"pattern"
root:"path"
root-file:"path"
root-glob:"pattern"
root-prefix-glob:"pattern"
```

Add `-i` for case-insensitive glob kinds when supported.

Fileset operators:

```text
~x       complement
x & y    intersection
x | y    union
x ~ y    subtraction
all()
none()
```

Fileset recipes:

```bash
jj --no-pager diff --git 'src'
jj --no-pager diff --git 'src ~ glob:"**/*.gen.ts"'
jj --no-pager file list 'src & glob:"**/*.rs"'
jj --no-pager file list 'root:"src" ~ root-glob:"src/**/*.snap"'
```

Filesets inside revsets:

```bash
jj --no-pager log -r 'files("src")'
jj --no-pager log -r 'diff_lines("TODO", "src")'
```

Quote filesets in the shell whenever they contain spaces, operators, parentheses, or glob metacharacters.

## Templates

Use templates for compact, scriptable output. Prefer templates over parsing default human output.

Rules:

* Use `--no-pager`.
* Use short explicit templates.
* Prefer `json(...)` or explicit separators for machine-readable output.
* Do not parse graphical log output unless necessary.

Useful globals:

```text
if(cond, then[, else])
coalesce(...)
concat(...)
join(sep, ...)
separate(sep, ...)
surround(prefix, suffix, content)
stringify(x)
json(x)
label(name, content)
config(name)
git_web_url([remote])
```

Useful commit fields/methods:

```text
commit_id
change_id
bookmarks()
local_bookmarks()
remote_bookmarks()
tags()
current_working_copy()
mine()
divergent()
hidden()
immutable()
conflict()
empty()
root()
contained_in("revset")
description()
trailers()
author()
committer()
signature()
diff([files])
files([files])
conflicted_files()
commit_id.short()
commit_id.shortest()
change_id.short()
change_id.shortest()
author.email().local()
timestamp.ago()
timestamp.format("%Y-%m-%d")
diff().summary()
diff().git()
diff().stat()
list.map(|x| ...)
list.join(", ")
list.any(...)
list.all(...)
```

Template recipes:

```bash
jj --no-pager log --no-graph -r @ -T 'commit_id.short() ++ " " ++ change_id.short() ++ "\n"'
```

```bash
jj --no-pager log --no-graph -r @ -T 'parents.map(|c| c.commit_id().short()).join(",") ++ "\n"'
```

```bash
jj --no-pager log --no-graph -r @ -T 'coalesce(description, "(no description set)\n")'
```

```bash
jj --no-pager log --no-graph -r @ -T 'diff().summary()'
```

```bash
jj --no-pager log --no-graph -r 'bookmarks() | @' -T 'json(self) ++ "\n"'
```

```bash
jj --no-pager log --no-graph -r @ -T 'if(conflict(), "CONFLICT ", "") ++ commit_id.short() ++ "\n"'
```

```bash
jj --no-pager log --no-graph -r @ -T 'if(contained_in("trunk().."), "mutable\n", "base\n")'
```

## Multi-Remote Patterns

### Fork Workflow

Use when `upstream` is the canonical project and `origin` is the user's fork.

```bash
jj git remote list
jj config set --repo git.fetch '["upstream", "origin"]'
jj config set --repo git.push origin
jj bookmark track main@upstream
jj config set --repo 'revset-aliases."trunk()"' 'main@upstream'
jj git fetch
```

Work:

```bash
jj new trunk()
jj desc -m "WIP: Implement feature"

# edit

jj --no-pager diff --git
jj desc -m "feat: implement feature"
jj new
jj git push --change @-
```

### Independent Origin

Use when `origin` is the canonical remote.

```bash
jj config set --repo git.fetch '["origin"]'
jj config set --repo git.push origin
jj bookmark track main@origin
jj config set --repo 'revset-aliases."trunk()"' 'main@origin'
jj git fetch
```

## Divergent Changes

Divergence usually means the same change ID has multiple visible commit versions.

Inspect:

```bash
jj --no-pager log -r 'divergent()'
jj --no-pager show 'divergent()'
```

Resolve by choosing the intended version and abandoning/rebasing the unwanted version. Be explicit. Prefer change IDs or full commit IDs when ambiguity exists.

Example inspection:

```bash
jj --no-pager log -r 'all() & divergent()' --no-graph -T 'change_id.short() ++ " " ++ commit_id.short() ++ " " ++ description.first_line() ++ "\n"'
```

Do not guess which divergent version is correct solely from short IDs. Compare content, timestamps, parents, and descriptions.

## Recovery

Use the operation log early.

```bash
jj --no-pager op log
jj undo
jj redo
```

To inspect an older operation state:

```bash
jj --no-pager log -r 'at_operation(<op-id>, all())'
```

To recover lost-looking commits, inspect visible heads and operation history:

```bash
jj --no-pager log -r 'visible_heads()'
jj --no-pager op log
```

## Quick Git → JJ Map

```text
git init                         -> jj git init
git clone                        -> jj git clone
git fetch                        -> jj git fetch
git status                       -> jj st
git diff HEAD                    -> jj diff
git diff HEAD -- path            -> jj diff path
git diff A B                     -> jj diff --from A --to B
git show REV                     -> jj show REV
git commit -a                    -> jj desc -m "message"; jj new
git branch                       -> jj bookmark list
git branch NAME REV              -> jj bookmark create NAME -r REV
git branch -f NAME REV           -> jj bookmark move NAME --to REV
git checkout REV                 -> jj new REV
git switch -c NAME               -> jj new trunk(); jj bookmark create NAME -r @
git merge A                      -> jj new @ A
git rebase BASE BRANCH           -> jj rebase -b BRANCH -o BASE
git cherry-pick SRC              -> jj duplicate SRC -o DEST
git stash                        -> jj new @-
git restore FILE                 -> jj restore FILE
git rm --cached FILE             -> jj file untrack FILE
git reflog                       -> jj op log
git push origin NAME             -> jj git push --bookmark NAME --remote origin
```

## Command Reference for Agent Use

Status:

```bash
jj --no-pager st
```

Log:

```bash
jj --no-pager log
jj --no-pager log -r 'trunk()..@'
jj --no-pager log -r 'trunk()..@-'
jj --no-pager log -r 'reachable(@, mutable())'
```

Diff:

```bash
jj --no-pager diff --git
jj --no-pager diff --git -r @
jj --no-pager diff --git --from main --to @
```

Show:

```bash
jj --no-pager show @ --git
jj --no-pager show @- --git
```

New work:

```bash
jj --no-pager st
jj new
jj desc -m "WIP: Describe intended work"
```

Finalize current work:

```bash
jj --no-pager st
jj --no-pager diff --git
jj --no-pager show @ --git
jj desc -m "feat: describe actual completed work"
jj new
```

Bookmark and push completed work:

```bash
jj bookmark create my-feature -r @-
jj bookmark track my-feature
jj git push --bookmark my-feature
```

Generated bookmark push:

```bash
jj git push --change @-
```

Fetch and rebase:

```bash
jj git fetch
jj rebase -o trunk()
```

Undo:

```bash
jj undo
```

## Things Not to Claim

Do not claim:

* JJ has a Git-style staging area.
* `jj new` is the same as `git checkout`.
* Bookmarks are current branches.
* Bookmarks automatically advance when new commits are created on top of them.
* `jj pull` is the documented normal update command.
* `jj git push --all` pushes all commits.
* Raw Git and JJ mutation are always interchangeable in colocated repositories.
* Git submodules, Git hooks, `.gitattributes`, shallow clones, partial clones, or Git worktrees are fully supported in JJ.
* Git tools understand JJ conflict storage reliably.

## Final Agent Checklist

Before starting:

```bash
jj --no-pager st
```

Confirm `@` is empty. If not, protect existing work and create a new commit:

```bash
jj new
```

Then:

```bash
jj desc -m "WIP: {intended work}"
```

Before finishing:

```bash
jj --no-pager st
jj --no-pager diff --git
jj --no-pager show @ --git
```

Finalize:

```bash
jj desc -m "{project commit type}: {actual completed change}"
jj new
```

After finishing:

```bash
jj --no-pager st
jj --no-pager log -r '@-::@'
```

Only push after explicit user instruction:

```bash
jj git push --change @-
```

