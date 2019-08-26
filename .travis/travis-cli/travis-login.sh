#!/bin/bash

# If running on host, pass github token as argument
# If running in Travis box, the github token should
# have been provided through Travis page so pass no
# arguments.

gh_token="${1:-$GITHUB_TOKEN}"
travis login --github-token ${gh_token}
