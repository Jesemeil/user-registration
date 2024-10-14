#!/bin/bash


set -e


handle_error() {
  echo "Error on line $1"
  exit 1
}


trap 'handle_error $LINENO' ERR

REPO_NAME="user-registration"
GITHUB_USERNAME="jesemeil"
BRANCHES=("dev" "uat" "system-test" "prod-support")

echo "Starting repository setup for '$REPO_NAME'..."

# Authenticate GitHub CLI
echo "Checking GitHub CLI authentication..."
if ! gh auth status > /dev/null 2>&1; then
  echo "GitHub CLI not authenticated. Please run 'gh auth login'."
  exit 1
fi
echo "GitHub CLI is authenticated."


echo "Checking if repository '$REPO_NAME' exists..."
if gh repo view "$GITHUB_USERNAME/$REPO_NAME" > /dev/null 2>&1; then
  echo "Repository '$REPO_NAME' already exists. Skipping creation."
else
  echo "Creating repository '$REPO_NAME'..."
  gh repo create "$REPO_NAME" --public --confirm
  echo "Repository '$REPO_NAME' created successfully."
fi

set_remote_to_ssh() {
  local repo_dir="$1"
  local username="$2"
  local repo="$3"

  cd "$repo_dir"
  echo "Setting remote URL to SSH for '$repo'..."
  git remote set-url origin "git@github.com:$username/$repo.git"
  echo "Remote URL set to SSH."
}

apply_branch_protection() {
  local repo="$1"
  local branch="$2"
  local approving_review_count="$3"

  echo "Applying branch protection to '$branch'..."

  gh api -X PUT "/repos/$GITHUB_USERNAME/$repo/branches/$branch/protection" \
    -H "Accept: application/vnd.github+json" <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": $approving_review_count
  },
  "restrictions": {
    "users": [],
    "teams": []
  },
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_signed_commits": true
}
EOF

  echo "Branch protection applied to '$branch'."
}


if [ -d "$REPO_NAME" ]; then
  echo "Directory '$REPO_NAME' already exists. Skipping cloning."
  set_remote_to_ssh "$REPO_NAME" "$GITHUB_USERNAME" "$REPO_NAME"
  cd "$REPO_NAME"
else
  echo "Cloning repository '$REPO_NAME' using SSH..."
  gh repo clone "$GITHUB_USERNAME/$REPO_NAME"
  echo "Repository cloned successfully."
  cd "$REPO_NAME"
fi


if [ ! -f README.md ]; then
  echo "Creating README.md..."
  echo "# User Registration" > README.md
  git add README.md
  git commit -m "Initial commit"
  git push origin main
  echo "README.md created and pushed to 'main' branch."
else
  echo "README.md already exists. Skipping initialization."
fi


for branch in "${BRANCHES[@]}"; do
  echo "Checking if branch '$branch' exists..."
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "Branch '$branch' already exists. Skipping creation."
  else
    echo "Creating and pushing branch '$branch'..."
    git checkout -b "$branch"
    git push origin "$branch"
    git checkout main
    echo "Branch '$branch' created and pushed."
  fi
done


apply_branch_protection "$REPO_NAME" "main" 2


for branch in "${BRANCHES[@]}"; do
  apply_branch_protection "$REPO_NAME" "$branch" 1
done

echo "Repository '$REPO_NAME' setup completed successfully."
