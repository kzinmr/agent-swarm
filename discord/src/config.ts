import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { resolve } from 'path';
import { homedir } from 'os';

const workspaceRoot = resolve(import.meta.dirname, '..', '..');
const configDir = resolve(workspaceRoot, 'config');
const scriptsDir = resolve(workspaceRoot, 'scripts');

// Use the same registry location as swarm scripts
const SWARM_ROOT = process.env.SWARM_ROOT || resolve(homedir(), '.agent-swarm');
const TASK_REGISTRY_PATH = resolve(SWARM_ROOT, 'active-tasks.json');

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
  status: 'running' | 'completed' | 'failed' | 'paused' | 'reviewing' | 'spawning';
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
  stats?: {
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
  // Ensure directory exists
  if (!existsSync(SWARM_ROOT)) {
    mkdirSync(SWARM_ROOT, { recursive: true });
  }
  
  // Create empty registry if doesn't exist
  if (!existsSync(TASK_REGISTRY_PATH)) {
    const emptyRegistry: TaskRegistry = {
      tasks: [],
      lastUpdated: new Date().toISOString(),
    };
    return emptyRegistry;
  }
  
  const content = readFileSync(TASK_REGISTRY_PATH, 'utf-8');
  return JSON.parse(content);
}

export function saveTaskRegistry(registry: TaskRegistry): void {
  // Ensure directory exists
  if (!existsSync(SWARM_ROOT)) {
    mkdirSync(SWARM_ROOT, { recursive: true });
  }
  
  registry.lastUpdated = new Date().toISOString();
  writeFileSync(TASK_REGISTRY_PATH, JSON.stringify(registry, null, 2), 'utf-8');
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