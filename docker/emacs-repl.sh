#!/bin/bash
# Copyright © 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# emacs-repl.sh - Interactive REPL using emacsclient

# Don't exit on errors - we want to handle them gracefully
set +e

cleanup() {
    echo "Shutting down Emacs daemon..."
    emacsclient --eval "(kill-emacs)" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM


# Use default emacsclient (Unix socket)

echo "=== Emacs Lisp REPL ==="
echo "Connected to containerized Emacs daemon"
echo "Projects directory: /projects"
echo "HTTP API: port 7080"
echo ""
echo "Enter Lisp expressions (or commands):"
echo "  (+ 1 2 3)           - Evaluate Lisp"
echo "  (buffer-list)       - List buffers" 
echo "  (pwd)               - Current directory"
echo "  (undefined-func)    - Test error handling"
echo "  .help               - Show this help"
echo "  .logs               - Show daemon logs"
echo "  .bash               - Drop to bash shell"
echo "  .quit or (quit)     - Exit"
echo ""

# CRITICAL FIX: This loop will properly exit when stdin is closed
while true; do
    # Read input with prompt
    echo -n "emacs> "
    
    # The key fix: check if read succeeds
    if ! read -r line; then
        echo ""
        echo "stdin closed - shutting down container"
        break
    fi
    
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # Handle special commands
    case "$line" in
        ".help")
            echo "Available commands:"
            echo "  .help    - Show this help"
            echo "  .logs    - Show daemon logs"
            echo "  .bash    - Drop to bash shell (exit to return)"
            echo "  .quit    - Exit REPL"
            echo ""
            echo "Or enter any Emacs Lisp expression:"
            echo "  (+ 1 2 3)"
            echo "  (buffer-list)"
            echo "  (directory-files \"/projects\")"
            continue
            ;;
        ".logs")
            echo "=== Daemon logs ==="
            cat /tmp/emacs-daemon.log 2>/dev/null || echo "No logs available"
            echo "==================="
            continue
            ;;
        ".bash")
            echo "Dropping to bash shell (type 'exit' to return to REPL)..."
            /bin/bash
            echo "Returned to Emacs REPL"
            continue
            ;;
        ".quit" | "(quit)" | "(exit)" | "exit" | "quit")
            echo "Goodbye!"
            break
            ;;
    esac
    
    # Evaluate Lisp expression using emacsclient
    if emacsclient --eval "t" > /dev/null 2>&1; then
        # Wrap the evaluation in error handling to prevent crashes
        result=$(emacsclient --eval "(condition-case err $line (error (format \"Error: %s\" err)))" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            echo "$result"
        else
            echo "Error: emacsclient failed with exit code $exit_code"
            echo "Output: $result"
        fi
    else
        echo "Error: Cannot connect to Emacs daemon"
        echo "Try: .logs to check daemon status"
        echo "Or:  .bash to debug manually"
    fi
done


