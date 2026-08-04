#!/bin/bash

# Retry with Timeout Script
#
# Usage: ./retry-with-timeout.sh <timeout_sec> <max_attempts> [--on-retry <command>] <command> [args...]
# Example: ./retry-with-timeout.sh 60 3 --on-retry "xcrun simctl shutdown all" xcrun simctl boot "iPhone 15"
#
# Requirements: coreutils (for timeout command on macOS)
#   Install with: brew install coreutils
#
# Exit codes:
#   0   - Success
#   1   - All retry attempts exhausted
#   124 - Timeout occurred (from timeout command)

set -euo pipefail

# Check if timeout is available (from coreutils), install if missing
if ! command -v timeout &> /dev/null; then
    echo "timeout not found, installing coreutils..."
    if command -v brew &> /dev/null; then
        brew install coreutils
    else
        echo "Error: brew not found. Please install Homebrew first."
        exit 1
    fi

    # Verify installation
    if ! command -v timeout &> /dev/null; then
        echo "Error: Failed to install timeout from coreutils"
        exit 1
    fi
    echo "✓ coreutils installed successfully"
fi

# Check minimum arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <timeout_sec> <max_attempts> [--on-retry <retry_command>] <command> [args...]"
    echo ""
    echo "Arguments:"
    echo "  timeout_sec      - Timeout in seconds for each attempt"
    echo "  max_attempts     - Maximum number of retry attempts"
    echo "  --on-retry       - Optional: command to run before each retry (after failure)"
    echo "  command          - Main command to execute"
    echo "  args             - Optional arguments for the main command"
    echo ""
    echo "Examples:"
    echo "  $0 60 3 ./my-script.sh"
    echo "  $0 60 3 --on-retry 'echo Retrying...' ./my-script.sh"
    echo "  $0 300 3 --on-retry 'xcrun simctl shutdown all' xcrun simctl boot 'iPhone 15'"
    exit 1
fi

TIMEOUT=$1
MAX_ATTEMPTS=$2
shift 2

# Parse optional --on-retry flag
RETRY_COMMAND=""
if [ "$1" = "--on-retry" ]; then
    shift
    RETRY_COMMAND="$1"
    shift
fi

COMMAND=("$@")

START_TIME=$(date +%s)

echo "Starting retry wrapper"
echo "Command: ${COMMAND[*]}"
echo "Timeout: ${TIMEOUT}s per attempt"
echo "Max attempts: $MAX_ATTEMPTS"
if [ -n "$RETRY_COMMAND" ]; then
    echo "On-retry command: $RETRY_COMMAND"
fi
echo ""

for ((attempt=1; attempt<=MAX_ATTEMPTS; attempt++)); do
    ATTEMPT_START=$(date +%s)
    echo "=== Attempt $attempt/$MAX_ATTEMPTS at $(date '+%Y-%m-%d %H:%M:%S') ==="

    # Run command with timeout from coreutils (disable exit on error temporarily)
    set +e
    timeout $TIMEOUT "${COMMAND[@]}"
    EXIT_CODE=$?
    set -e

    ATTEMPT_DURATION=$(($(date +%s) - ATTEMPT_START))

    # Check exit code
    if [ $EXIT_CODE -eq 0 ]; then
        TOTAL_DURATION=$(($(date +%s) - START_TIME))
        echo ""
        echo "✓ Success after ${ATTEMPT_DURATION}s (total: ${TOTAL_DURATION}s)"
        exit 0
    fi

    # Handle different error types
    if [ $EXIT_CODE -eq 124 ]; then
        echo "⏱ Timeout after ${TIMEOUT}s"
    else
        echo "✗ Error: exit code $EXIT_CODE"
    fi

    # Execute retry command before next attempt (except after last attempt)
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        # Execute on-retry command if specified
        if [ -n "$RETRY_COMMAND" ]; then
            echo ""
            echo "Executing on-retry command: $RETRY_COMMAND"
            set +e
            bash -c "$RETRY_COMMAND"
            RETRY_EXIT_CODE=$?
            set -e
            if [ $RETRY_EXIT_CODE -eq 0 ]; then
                echo "✓ On-retry command completed successfully"
            else
                echo "⚠ On-retry command failed with exit code $RETRY_EXIT_CODE"
            fi
        fi
        echo ""
    fi
done

TOTAL_DURATION=$(($(date +%s) - START_TIME))
echo ""
echo "❌ All $MAX_ATTEMPTS attempts exhausted (total time: ${TOTAL_DURATION}s)"
exit 1
