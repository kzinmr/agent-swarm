#!/bin/bash
# Start the Discord bot
cd "$(dirname "$0")"
pnpm register-commands && pnpm start