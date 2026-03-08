#!/usr/bin/env tsx
/**
 * Register Discord slash commands
 * 
 * Usage:
 *   pnpm register-commands
 *   # or
 *   tsx src/register-commands.ts
 */

import { registerCommands } from './commands.js';

console.log('🤖 Agent Swarm Discord Bot - Command Registration');
console.log('================================================\n');

registerCommands()
  .then(() => {
    console.log('\n✅ All commands registered!');
    console.log('💡 You can now use the commands in Discord.');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Failed to register commands:', error);
    process.exit(1);
  });