#!/bin/bash
set -e

echo "🚀 Running CI Logic Tests..."
export PYTHONPATH=$PYTHONPATH:$(pwd)/tools

python3 -m unittest discover tests/ci -v

echo "✅ All tests passed!"
