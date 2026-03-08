#!/usr/bin/env tsx
/**
 * CLI entry point for sending notifications from shell scripts
 * 
 * Usage:
 *   tsx cli-notify.ts <type> <task-id> [json-extra]
 * 
 * Types:
 *   spawned, pr-created, ci-passed, ci-failed, completed, failed, review
 */

import { notifications, closeNotificationClient } from './notifications.js';
import { loadTaskRegistry } from './config.js';

const type = process.argv[2];
const taskId = process.argv[3];
const extraJson = process.argv[4] || '{}';

if (!type || !taskId) {
  console.error('Usage: tsx cli-notify.ts <type> <task-id> [json]');
  process.exit(1);
}

async function main() {
  const registry = loadTaskRegistry();
  const task = registry.tasks.find(t => t.id === taskId);
  
  if (!task) {
    console.error(`Task ${taskId} not found`);
    process.exit(1);
  }
  
  const extra = JSON.parse(extraJson);
  
  try {
    switch (type) {
      case 'spawned':
        await notifications.agentSpawned(task);
        break;
      
      case 'pr-created':
        await notifications.prCreated(task, extra.prNumber || task.checks.prNumber || 0, extra.prUrl || '');
        break;
      
      case 'ci-passed':
        await notifications.ciPassed(task, extra.prNumber || task.checks.prNumber || 0);
        break;
      
      case 'ci-failed':
        await notifications.ciFailed(task, extra.prNumber || task.checks.prNumber || 0, extra.logs);
        break;
      
      case 'completed':
        await notifications.agentCompleted(task);
        break;
      
      case 'failed':
        await notifications.agentFailed(task, extra.error || 'Unknown error');
        break;
      
      case 'review':
        await notifications.reviewCompleted(task, extra.results || []);
        break;
      
      default:
        console.error(`Unknown notification type: ${type}`);
        process.exit(1);
    }
    
    console.log(`✅ Notification sent: ${type} for ${taskId}`);
  } catch (error) {
    console.error('Failed to send notification:', error);
    process.exit(1);
  } finally {
    await closeNotificationClient();
  }
}

main();