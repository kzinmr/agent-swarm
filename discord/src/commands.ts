import {
  SlashCommandBuilder,
  ChatInputCommandInteraction,
  Client,
  REST,
  Routes,
  RESTPostAPIChatInputApplicationCommandsJSONBody,
} from 'discord.js';
import { loadDiscordCredentials } from './config.js';

// Command definitions
export const commands = {
  spawn: new SlashCommandBuilder()
    .setName('spawn')
    .setDescription('Spawn a new coding agent')
    .addStringOption(opt =>
      opt.setName('task-id')
        .setDescription('Unique task identifier (e.g., feat-auth, fix-billing)')
        .setRequired(true))
    .addStringOption(opt =>
      opt.setName('prompt')
        .setDescription('Task description for the agent')
        .setRequired(true))
    .addStringOption(opt =>
      opt.setName('agent')
        .setDescription('Agent type')
        .setRequired(false)
        .addChoices(
          { name: 'OpenCode', value: 'opencode' },
          { name: 'Codex', value: 'codex' },
          { name: 'Claude', value: 'claude' },
        ))
    .addStringOption(opt =>
      opt.setName('model')
        .setDescription('Model to use (e.g., qwen-coder-plus)')
        .setRequired(false))
    .addStringOption(opt =>
      opt.setName('priority')
        .setDescription('Task priority')
        .setRequired(false)
        .addChoices(
          { name: 'Low', value: 'low' },
          { name: 'Normal', value: 'normal' },
          { name: 'High', value: 'high' },
        ))
    .addStringOption(opt =>
      opt.setName('repo')
        .setDescription('Repository path (relative to ~/projects)')
        .setRequired(false))
    .toJSON(),

  status: new SlashCommandBuilder()
    .setName('status')
    .setDescription('Check status of tasks')
    .addStringOption(opt =>
      opt.setName('task-id')
        .setDescription('Specific task ID (optional, shows all if omitted)')
        .setRequired(false))
    .toJSON(),

  steer: new SlashCommandBuilder()
    .setName('steer')
    .setDescription('Send a message to a running agent')
    .addStringOption(opt =>
      opt.setName('task-id')
        .setDescription('Task ID to steer')
        .setRequired(true))
    .addStringOption(opt =>
      opt.setName('message')
        .setDescription('Message to send to the agent')
        .setRequired(true))
    .toJSON(),

  list: new SlashCommandBuilder()
    .setName('list')
    .setDescription('List all active tasks')
    .addStringOption(opt =>
      opt.setName('status')
        .setDescription('Filter by status')
        .setRequired(false)
        .addChoices(
          { name: 'Running', value: 'running' },
          { name: 'Completed', value: 'completed' },
          { name: 'Failed', value: 'failed' },
          { name: 'Reviewing', value: 'reviewing' },
        ))
    .toJSON(),

  kill: new SlashCommandBuilder()
    .setName('kill')
    .setDescription('Stop a running agent')
    .addStringOption(opt =>
      opt.setName('task-id')
        .setDescription('Task ID to kill')
        .setRequired(true))
    .addBooleanOption(opt =>
      opt.setName('cleanup')
        .setDescription('Also remove worktree')
        .setRequired(false))
    .toJSON(),

  review: new SlashCommandBuilder()
    .setName('review')
    .setDescription('Run automated code review on a PR')
    .addIntegerOption(opt =>
      opt.setName('pr-number')
        .setDescription('PR number to review')
        .setRequired(true))
    .addStringOption(opt =>
      opt.setName('models')
        .setDescription('Review models (comma-separated: opencode,gemini,claude)')
        .setRequired(false))
    .toJSON(),

  cleanup: new SlashCommandBuilder()
    .setName('cleanup')
    .setDescription('Clean up completed tasks and orphaned worktrees')
    .addIntegerOption(opt =>
      opt.setName('age-days')
        .setDescription('Remove tasks older than N days')
        .setRequired(false))
    .addBooleanOption(opt =>
      opt.setName('dry-run')
        .setDescription('Show what would be cleaned without actually cleaning')
        .setRequired(false))
    .toJSON(),
};

// Register commands with Discord
export async function registerCommands(): Promise<void> {
  const credentials = loadDiscordCredentials();
  const rest = new REST({ version: '10' }).setToken(credentials.botToken);

  const commandsArray = Object.values(commands) as RESTPostAPIChatInputApplicationCommandsJSONBody[];

  console.log(`Registering ${commandsArray.length} commands...`);

  // Register for specific guild (faster for development)
  await rest.put(
    Routes.applicationGuildCommands(credentials.applicationId, credentials.serverId),
    { body: commandsArray },
  );

  console.log('✅ Commands registered successfully!');
}

// Get command names for verification
export function getCommandNames(): string[] {
  return Object.keys(commands);
}