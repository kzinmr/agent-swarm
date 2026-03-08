import {
  Client,
  EmbedBuilder,
  GatewayIntentBits,
} from 'discord.js';
import { loadDiscordCredentials, type Task } from './config.js';

let _client: Client | null = null;

/**
 * Get or create a Discord client for notifications
 * This is separate from the main bot client
 */
export async function getNotificationClient(): Promise<Client> {
  if (_client) return _client;
  
  const credentials = loadDiscordCredentials();
  _client = new Client({
    intents: [GatewayIntentBits.Guilds],
  });
  
  await _client.login(credentials.botToken);
  return _client;
}

/**
 * Send a notification to the configured channel
 */
export async function sendNotification(
  title: string,
  description: string,
  options: {
    color?: number;
    fields?: { name: string; value: string; inline?: boolean }[];
    taskId?: string;
  } = {},
): Promise<void> {
  const credentials = loadDiscordCredentials();
  const client = await getNotificationClient();
  
  const channel = await client.channels.fetch(credentials.channelId);
  if (!channel || !channel.isTextBased()) {
    console.error('Notification channel not found or not text-based');
    return;
  }
  
  const embed = new EmbedBuilder()
    .setTitle(title)
    .setDescription(description)
    .setColor(options.color || 0x5865F2)
    .setTimestamp();
  
  if (options.fields) {
    embed.addFields(options.fields);
  }
  
  if (options.taskId) {
    embed.setFooter({ text: `Task: ${options.taskId}` });
  }
  
  await channel.send({ embeds: [embed] });
}

/**
 * Notification types with specific formatting
 */
export const notifications = {
  /**
   * Agent spawned successfully
   */
  async agentSpawned(task: Task): Promise<void> {
    await sendNotification(
      '🚀 Agent Spawned',
      `New coding agent started for **${task.id}**`,
      {
        color: 0x57F287, // Green
        taskId: task.id,
        fields: [
          { name: 'Agent', value: task.agent, inline: true },
          { name: 'Model', value: task.model, inline: true },
          { name: 'Priority', value: task.priority, inline: true },
          { name: 'Branch', value: `\`${task.branch}\``, inline: false },
        ],
      },
    );
  },

  /**
   * PR created by agent
   */
  async prCreated(task: Task, prNumber: number, prUrl: string): Promise<void> {
    await sendNotification(
      '📝 PR Ready for Review',
      `Agent **${task.id}** created PR #${prNumber}`,
      {
        color: 0x5865F2, // Blurple
        taskId: task.id,
        fields: [
          { name: 'PR', value: `[#${prNumber}](${prUrl})`, inline: true },
          { name: 'Branch', value: `\`${task.branch}\``, inline: true },
        ],
      },
    );
  },

  /**
   * CI passed
   */
  async ciPassed(task: Task, prNumber: number): Promise<void> {
    await sendNotification(
      '✅ CI Passed',
      `All checks passed for PR #${prNumber}`,
      {
        color: 0x57F287, // Green
        taskId: task.id,
        fields: [
          { name: 'PR', value: `#${prNumber}`, inline: true },
        ],
      },
    );
  },

  /**
   * CI failed
   */
  async ciFailed(task: Task, prNumber: number, logs?: string): Promise<void> {
    await sendNotification(
      '❌ CI Failed',
      `Checks failed for PR #${prNumber}`,
      {
        color: 0xED4245, // Red
        taskId: task.id,
        fields: [
          { name: 'PR', value: `#${prNumber}`, inline: true },
          { name: 'Action', value: 'Use `/steer` to fix issues', inline: true },
        ],
      },
    );
  },

  /**
   * Agent completed successfully
   */
  async agentCompleted(task: Task): Promise<void> {
    await sendNotification(
      '🎉 Agent Completed',
      `Task **${task.id}** completed successfully`,
      {
        color: 0x57F287, // Green
        taskId: task.id,
        fields: [
          { name: 'Agent', value: task.agent, inline: true },
          { name: 'PR', value: task.checks.prNumber ? `#${task.checks.prNumber}` : 'N/A', inline: true },
        ],
      },
    );
  },

  /**
   * Agent failed
   */
  async agentFailed(task: Task, error: string): Promise<void> {
    await sendNotification(
      '🔴 Agent Failed',
      `Task **${task.id}** encountered an error`,
      {
        color: 0xED4245, // Red
        taskId: task.id,
        fields: [
          { name: 'Error', value: error.slice(0, 200), inline: false },
          { name: 'Attempt', value: `${task.attempt}/${task.maxAttempts}`, inline: true },
        ],
      },
    );
  },

  /**
   * Review completed
   */
  async reviewCompleted(task: Task, results: { model: string; passed: boolean }[]): Promise<void> {
    const allPassed = results.every(r => r.passed);
    const summary = results.map(r => `${r.passed ? '✅' : '❌'} ${r.model}`).join('\n');
    
    await sendNotification(
      allPassed ? '👀 Reviews Passed' : '⚠️ Review Issues',
      `Code review for task **${task.id}**`,
      {
        color: allPassed ? 0x57F287 : 0xFEE75C,
        taskId: task.id,
        fields: [
          { name: 'Results', value: summary, inline: false },
        ],
      },
    );
  },
};

/**
 * Close the notification client
 */
export async function closeNotificationClient(): Promise<void> {
  if (_client) {
    await _client.destroy();
    _client = null;
  }
}