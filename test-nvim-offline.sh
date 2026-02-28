#!/bin/bash
# Test nvim in offline container
echo "=== Testing nvim startup in offline mode ==="

# Run nvim headless and capture output
output=$(docker run --rm --network none airgap-dev:latest zsh -c '
  nvim --headless +qa 2>&1
' 2>&1)

echo "$output"

# Check for common error patterns
if echo "$output" | grep -qi "error\|failed\|not found\|cannot"; then
  echo ""
  echo "=== ERRORS FOUND ==="
  exit 1
else
  echo ""
  echo "=== NO ERRORS ==="
  exit 0
fi
