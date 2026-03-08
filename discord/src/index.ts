import {
  Client,
  GatewayIntentBits,
  Events,
  ChatInputCommandInteraction,
  EmbedBuilder,
} from 'discord.js';
import { loadDiscordCredentials } from './config.js';
import { commands, registerCommands, getCommandNames } from './commands.js';
import {
  handleSpawn,
  handleStatus,
  handleSteer,
  handleList,
  handleKill,
  handleReview,
  handleCleanup,
} from './handlers.js';

const credentials = loadDiscordCredentials();

// Create client with necessary intents
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
  ],
});

// Bot ready event
client.once(Events.ClientReady, (readyClient) => {
  console.log(`✅ Bot logged in as ${readyClient.user.tag}`);
  console.log(`📋 Commands available: ${getCommandNames().join(', ')}`);
});

// Handle interactions
client.on(Events.InteractionCreate, async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  const { commandName } = interaction;
  
  // Defer reply for potentially long operations
  await interaction.deferReply();

  try {
    switch (commandName) {
      case 'spawn': {
        const taskId = interaction.options.getString('task-id', true);
        const prompt = interaction.options.getString('prompt', true);
        const agent = interaction.options.getString('agent') || 'opencode';
        const model = interaction.options.getString('model') || undefined;
        const priority = interaction.options.getString('priority') || 'normal';
        const repo = interaction.options.getString('repo') || undefined;
        
        const result = handleSpawn(taskId, prompt, agent, model, priority, repo);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'status': {
        const taskId = interaction.options.getString('task-id') || undefined;
        const result = handleStatus(taskId);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'steer': {
        const taskId = interaction.options.getString('task-id', true);
        const message = interaction.options.getString('message', true);
        const result = handleSteer(taskId, message);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'list': {
        const status = interaction.options.getString('status') || undefined;
        const result = handleList(status);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'kill': {
        const taskId = interaction.options.getString('task-id', true);
        const cleanup = interaction.options.getBoolean('cleanup') || false;
        const result = handleKill(taskId, cleanup);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'review': {
        const prNumber = interaction.options.getInteger('pr-number', true);
        const models = interaction.options.getString('models') || undefined;
        const result = handleReview(prNumber, models);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      case 'cleanup': {
        const ageDays = interaction.options.getInteger('age-days') || undefined;
        const dryRun = interaction.options.getBoolean('dry-run') || false;
        const result = handleCleanup(ageDays, dryRun);
        await interaction.editReply({
          content: result.message,
        });
        break;
      }

      default:
        await interaction.editReply({
          content: `❓ Unknown command: ${commandName}`,
        });
    }
  } catch (error) {
    console.error('Command error:', error);
    await interaction.editReply({
      content: `❌ Error executing command: ${error instanceof Error ? error.message : 'Unknown error'}`,
    });
  }
});

// Error handling
client.on(Events.Error, (error) => {
  console.error('Discord client error:', error);
});

// Start the bot
async function main() {
  console.log('🤖 Starting Agent Swarm Discord Bot...');
  console.log(`📡 Connecting to Discord...`);
  
  try {
    await client.login(credentials.botToken);
  } catch (error) {
    console.error('Failed to login:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n👋 Shutting down...');
  client.destroy();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n👋 Shutting down...');
  client.destroy();
  process.exit(0);
});

main();