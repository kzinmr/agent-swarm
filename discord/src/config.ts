import { readFileSync } from 'fs';
import { resolve } from 'path';

const workspaceRoot = resolve(import.meta.dirname, '..', '..');
const configDir = resolve(workspaceRoot, 'config');
const scriptsDir = resolve(workspaceRoot, 'scripts');

interface DiscordCredentials {
  botToken: string;
  applicationId: string;
  publicKey: string;
  serverId: string;
  channelId: string;
}

interface Task {
  id: string;
  tmuxSession: string;
  agent: string;
  model: string;
  description: string;
  repo: string;
  repoPath: string;
  worktree: string;
  worktreePath: string;
  branch: string;
  baseBranch: string;
  startedAt: number;
  status: 'running' | 'completed' | 'failed' | 'paused' | 'reviewing';
  attempt: number;
  maxAttempts: number;
  notifyOnComplete: boolean;
  priority: 'low' | 'normal' | 'high';
  tags: string[];
  prompt: string;
  context: {
    customerRequest: boolean;
    relatedFiles: string[];
    meetingNotes: string | null;
  };
  checks: {
    prCreated: boolean;
    prNumber: number | null;
    ciPassed: boolean | null;
    reviews: {
      opencode: boolean | null;
      gemini: boolean | null;
      claude: boolean | null;
    };
    screenshotIncluded: boolean | null;
  };
  completedAt: number | null;
  note: string | null;
}

interface TaskRegistry {
  tasks: Task[];
  lastUpdated: string;
  stats: {
    totalTasks: number;
    runningTasks: number;
    completedToday: number;
    failedToday: number;
  };
}

export function loadDiscordCredentials(): DiscordCredentials {
  const credentialsPath = resolve(configDir, 'discord.credentials.json');
  const content = readFileSync(credentialsPath, 'utf-8');
  return JSON.parse(content);
}

export function loadTaskRegistry(): TaskRegistry {
  const registryPath = resolve(configDir, 'active-tasks.json');
  const content = readFileSync(registryPath, 'utf-8');
  return JSON.parse(content);
}

export function getScriptsDir(): string {
  return scriptsDir;
}

export function getConfigDir(): string {
  return configDir;
}

export function getWorkspaceRoot(): string {
  return workspaceRoot;
}

export type { Task, TaskRegistry };