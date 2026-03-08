import { execSync } from 'child_process';
import { resolve } from 'path';
import { getScriptsDir, loadTaskRegistry, type Task } from './config.js';

function runScript(scriptName: string, args: string[] = []): { stdout: string; stderr: string; code: number } {
  const scriptPath = resolve(getScriptsDir(), scriptName);
  
  try {
    const stdout = execSync(`bash "${scriptPath}" ${args.map(a => `"${a}"`).join(' ')}`, {
      encoding: 'utf-8',
      timeout: 60000,
      maxBuffer: 10 * 1024 * 1024,
    });
    return { stdout, stderr: '', code: 0 };
  } catch (error: any) {
    return {
      stdout: error.stdout || '',
      stderr: error.stderr || error.message,
      code: error.status || 1,
    };
  }
}

function formatUptime(startedAt: number): string {
  const seconds = Math.floor((Date.now() - startedAt) / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  const remainMins = minutes % 60;
  return `${hours}h ${remainMins}m`;
}

function getStatusEmoji(status: Task['status']): string {
  switch (status) {
    case 'running': return '🟢';
    case 'completed': return '✅';
    case 'failed': return '🔴';
    case 'paused': return '⏸️';
    case 'reviewing': return '👀';
    default: return '❓';
  }
}

function formatChecks(task: Task): string {
  const checks = [];
  if (task.checks.prCreated) {
    checks.push(`PR #${task.checks.prNumber}`);
  }
  if (task.checks.ciPassed !== null) {
    checks.push(task.checks.ciPassed ? '✓ CI' : '✗ CI');
  }
  const reviewStatus = Object.entries(task.checks.reviews)
    .filter(([, v]) => v !== null)
    .map(([k, v]) => `${k}: ${v ? '✓' : '✗'}`);
  if (reviewStatus.length > 0) {
    checks.push(`Reviews: ${reviewStatus.join(', ')}`);
  }
  return checks.length > 0 ? checks.join(' | ') : 'No checks yet';
}

export interface SpawnResult {
  success: boolean;
  message: string;
  taskId: string;
}

export function handleSpawn(
  taskId: string,
  prompt: string,
  agent: string = 'opencode',
  model?: string,
  priority: string = 'normal',
  repo?: string,
): SpawnResult {
  const args = [taskId, agent];
  if (model) args.push(model);
  args.push(priority);
  if (repo) args.push(repo);

  // The spawn script expects: task-id [agent-type] [model] [priority]
  const result = runScript('spawn-agent.sh', [taskId, agent, model || '', priority]);

  if (result.code === 0) {
    return {
      success: true,
      message: `🚀 Spawned agent **${taskId}**\n\n**Agent:** ${agent}\n**Model:** ${model || 'default'}\n**Priority:** ${priority}`,
      taskId,
    };
  } else {
    return {
      success: false,
      message: `❌ Failed to spawn agent: ${result.stderr || result.stdout}`,
      taskId,
    };
  }
}

export interface StatusResult {
  success: boolean;
  message: string;
  tasks?: Task[];
}

export function handleStatus(taskId?: string): StatusResult {
  const registry = loadTaskRegistry();
  
  if (taskId) {
    const task = registry.tasks.find(t => t.id === taskId);
    if (!task) {
      return { success: false, message: `❌ Task \`${taskId}\` not found.` };
    }
    
    const lines = [
      `${getStatusEmoji(task.status)} **Task: ${task.id}**`,
      '',
      `**Status:** ${task.status}`,
      `**Agent:** ${task.agent} (${task.model})`,
      `**Priority:** ${task.priority}`,
      `**Uptime:** ${formatUptime(task.startedAt)}`,
      `**Branch:** ${task.branch}`,
      `**Repo:** ${task.repo}`,
      '',
      `**Checks:**`,
      formatChecks(task),
      '',
      `**Description:**`,
      task.description || task.prompt?.slice(0, 200) + '...' || 'No description',
    ];
    
    return { success: true, message: lines.join('\n'), tasks: [task] };
  }
  
  // Show all tasks
  if (registry.tasks.length === 0) {
    return { success: true, message: '📭 No tasks registered.' };
  }
  
  const lines = registry.tasks.map(task => {
    const emoji = getStatusEmoji(task.status);
    const uptime = task.status === 'running' ? ` (${formatUptime(task.startedAt)})` : '';
    const pr = task.checks.prCreated ? ` PR #${task.checks.prNumber}` : '';
    return `${emoji} **${task.id}** - ${task.status}${uptime}${pr}`;
  });
  
  lines.unshift('📋 **Active Tasks**\n');
  lines.push(`\n_Total: ${registry.tasks.length} tasks_`);
  
  return { success: true, message: lines.join('\n'), tasks: registry.tasks };
}

export interface SteerResult {
  success: boolean;
  message: string;
}

export function handleSteer(taskId: string, message: string): SteerResult {
  const result = runScript('steer-agent.sh', [taskId, message]);
  
  if (result.code === 0) {
    return {
      success: true,
      message: `📨 Message sent to **${taskId}**\n\n> ${message}`,
    };
  } else {
    return {
      success: false,
      message: `❌ Failed to steer agent: ${result.stderr || result.stdout}`,
    };
  }
}

export interface ListResult {
  success: boolean;
  message: string;
  tasks: Task[];
}

export function handleList(status?: string): ListResult {
  const registry = loadTaskRegistry();
  let tasks = registry.tasks;
  
  if (status) {
    tasks = tasks.filter(t => t.status === status);
  }
  
  if (tasks.length === 0) {
    return { success: true, message: `📭 No tasks${status ? ` with status "${status}"` : ''}.`, tasks: [] };
  }
  
  const lines = tasks.map(task => {
    const emoji = getStatusEmoji(task.status);
    const uptime = task.status === 'running' ? ` (${formatUptime(task.startedAt)})` : '';
    return `${emoji} \`${task.id}\` - ${task.agent} | ${task.priority}${uptime}`;
  });
  
  return {
    success: true,
    message: `📋 **${tasks.length} Tasks**\n\n${lines.join('\n')}`,
    tasks,
  };
}

export interface KillResult {
  success: boolean;
  message: string;
}

export function handleKill(taskId: string, cleanup: boolean = false): KillResult {
  // Kill tmux session
  try {
    execSync(`tmux kill-session -t agent-${taskId} 2>/dev/null || true`, { encoding: 'utf-8' });
  } catch {
    // Session might not exist
  }
  
  if (cleanup) {
    const result = runScript('cleanup.sh', ['--task-id', taskId]);
    return {
      success: true,
      message: `☠️ Agent **${taskId}** stopped and worktree removed.`,
    };
  }
  
  return {
    success: true,
    message: `☠️ Agent **${taskId}** stopped.`,
  };
}

export interface ReviewResult {
  success: boolean;
  message: string;
}

export function handleReview(prNumber: number, models?: string): ReviewResult {
  const args = [String(prNumber)];
  if (models) {
    args.push('--models', models);
  }
  
  const result = runScript('auto-review.sh', args);
  
  if (result.code === 0) {
    return {
      success: true,
      message: `🔍 Review started for PR #${prNumber}\n\n${result.stdout.slice(0, 500)}`,
    };
  } else {
    return {
      success: false,
      message: `❌ Review failed: ${result.stderr || result.stdout}`,
    };
  }
}

export interface CleanupResult {
  success: boolean;
  message: string;
}

export function handleCleanup(ageDays?: number, dryRun: boolean = false): CleanupResult {
  const args = [];
  if (ageDays) args.push('--age-days', String(ageDays));
  if (dryRun) args.push('--dry-run');
  
  const result = runScript('cleanup.sh', args);
  
  return {
    success: true,
    message: `🧹 Cleanup ${dryRun ? '(dry run)' : 'complete'}\n\n${result.stdout.slice(0, 1000)}`,
  };
}