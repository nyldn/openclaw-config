#!/usr/bin/env node

/**
 * Slack MCP Server
 * Provides team messaging operations via Model Context Protocol
 *
 * Tools:
 * - sendMessage: Send a message to a channel or DM
 * - listChannels: List all channels
 * - readMessages: Read recent messages from a channel
 * - searchMessages: Search messages across workspace
 * - createChannel: Create a new channel
 * - inviteUser: Invite a user to a channel
 * - uploadFile: Upload a file to a channel
 * - addReaction: Add emoji reaction to a message
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { WebClient } = require('@slack/web-api');

// Configuration
const SLACK_BOT_TOKEN = process.env.SLACK_BOT_TOKEN;
const SLACK_APP_TOKEN = process.env.SLACK_APP_TOKEN;

class SlackMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'slack-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.client = null;

    this.setupHandlers();
    this.setupErrorHandling();
  }

  setupErrorHandling() {
    this.server.onerror = (error) => {
      console.error('[MCP Error]', error);
    };

    process.on('SIGINT', async () => {
      await this.server.close();
      process.exit(0);
    });
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'sendMessage',
          description: 'Send a message to a Slack channel or user',
          inputSchema: {
            type: 'object',
            properties: {
              channel: { type: 'string', description: 'Channel ID or name (e.g., "#general" or user ID for DM)' },
              text: { type: 'string', description: 'Message text' },
              threadTs: { type: 'string', description: 'Thread timestamp to reply in thread (optional)' },
              blocks: { type: 'array', description: 'Rich message blocks (optional, advanced)' },
            },
            required: ['channel', 'text'],
          },
        },
        {
          name: 'listChannels',
          description: 'List all channels in the workspace',
          inputSchema: {
            type: 'object',
            properties: {
              types: { type: 'string', description: 'Channel types: "public_channel", "private_channel", "im", "mpim" (comma-separated, optional)' },
              limit: { type: 'number', description: 'Maximum number of channels to return (default: 100)' },
            },
          },
        },
        {
          name: 'readMessages',
          description: 'Read recent messages from a channel',
          inputSchema: {
            type: 'object',
            properties: {
              channel: { type: 'string', description: 'Channel ID or name' },
              limit: { type: 'number', description: 'Number of messages to retrieve (default: 10, max: 100)' },
              oldest: { type: 'string', description: 'Start of time range (timestamp, optional)' },
              latest: { type: 'string', description: 'End of time range (timestamp, optional)' },
            },
            required: ['channel'],
          },
        },
        {
          name: 'searchMessages',
          description: 'Search messages across the workspace',
          inputSchema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              count: { type: 'number', description: 'Number of results (default: 20, max: 100)' },
              sort: { type: 'string', description: 'Sort by "score" or "timestamp" (default: score)' },
            },
            required: ['query'],
          },
        },
        {
          name: 'createChannel',
          description: 'Create a new channel',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Channel name (lowercase, no spaces)' },
              isPrivate: { type: 'boolean', description: 'Create as private channel (default: false)' },
            },
            required: ['name'],
          },
        },
        {
          name: 'inviteUser',
          description: 'Invite a user to a channel',
          inputSchema: {
            type: 'object',
            properties: {
              channel: { type: 'string', description: 'Channel ID' },
              users: { type: 'string', description: 'User ID or comma-separated user IDs' },
            },
            required: ['channel', 'users'],
          },
        },
        {
          name: 'uploadFile',
          description: 'Upload a file to a channel',
          inputSchema: {
            type: 'object',
            properties: {
              channel: { type: 'string', description: 'Channel ID or name' },
              filePath: { type: 'string', description: 'Path to file on local filesystem' },
              title: { type: 'string', description: 'File title (optional)' },
              initialComment: { type: 'string', description: 'Initial comment with file (optional)' },
            },
            required: ['channel', 'filePath'],
          },
        },
        {
          name: 'addReaction',
          description: 'Add emoji reaction to a message',
          inputSchema: {
            type: 'object',
            properties: {
              channel: { type: 'string', description: 'Channel ID' },
              timestamp: { type: 'string', description: 'Message timestamp' },
              emoji: { type: 'string', description: 'Emoji name (without colons, e.g., "thumbsup")' },
            },
            required: ['channel', 'timestamp', 'emoji'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        if (!this.client) {
          this.initializeClient();
        }

        switch (request.params.name) {
          case 'sendMessage':
            return await this.sendMessage(request.params.arguments);
          case 'listChannels':
            return await this.listChannels(request.params.arguments);
          case 'readMessages':
            return await this.readMessages(request.params.arguments);
          case 'searchMessages':
            return await this.searchMessages(request.params.arguments);
          case 'createChannel':
            return await this.createChannel(request.params.arguments);
          case 'inviteUser':
            return await this.inviteUser(request.params.arguments);
          case 'uploadFile':
            return await this.uploadFile(request.params.arguments);
          case 'addReaction':
            return await this.addReaction(request.params.arguments);
          default:
            throw new Error(`Unknown tool: ${request.params.name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  initializeClient() {
    if (!SLACK_BOT_TOKEN) {
      throw new Error(
        'SLACK_BOT_TOKEN environment variable is required.\n' +
        'Get your token from: https://api.slack.com/apps'
      );
    }

    this.client = new WebClient(SLACK_BOT_TOKEN);
    console.error('[Slack] Client initialized');
  }

  async sendMessage(args) {
    const { channel, text, threadTs, blocks } = args;

    const result = await this.client.chat.postMessage({
      channel,
      text,
      thread_ts: threadTs,
      blocks,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            channel: result.channel,
            timestamp: result.ts,
            message: result.message.text,
          }, null, 2),
        },
      ],
    };
  }

  async listChannels(args) {
    const { types = 'public_channel,private_channel', limit = 100 } = args;

    const result = await this.client.conversations.list({
      types,
      limit,
    });

    const channels = result.channels.map(channel => ({
      id: channel.id,
      name: channel.name,
      isPrivate: channel.is_private,
      isMember: channel.is_member,
      numMembers: channel.num_members,
      topic: channel.topic?.value,
      purpose: channel.purpose?.value,
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: channels.length,
            channels,
          }, null, 2),
        },
      ],
    };
  }

  async readMessages(args) {
    const { channel, limit = 10, oldest, latest } = args;

    const result = await this.client.conversations.history({
      channel,
      limit: Math.min(limit, 100),
      oldest,
      latest,
    });

    const messages = result.messages.map(msg => ({
      type: msg.type,
      user: msg.user,
      text: msg.text,
      timestamp: msg.ts,
      threadTs: msg.thread_ts,
      reactions: msg.reactions?.map(r => ({
        name: r.name,
        count: r.count,
      })),
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            channel,
            count: messages.length,
            messages,
          }, null, 2),
        },
      ],
    };
  }

  async searchMessages(args) {
    const { query, count = 20, sort = 'score' } = args;

    const result = await this.client.search.messages({
      query,
      count: Math.min(count, 100),
      sort,
    });

    const messages = result.messages.matches.map(msg => ({
      user: msg.user,
      username: msg.username,
      text: msg.text,
      channel: msg.channel?.name,
      timestamp: msg.ts,
      permalink: msg.permalink,
    }));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            total: result.messages.total,
            count: messages.length,
            messages,
          }, null, 2),
        },
      ],
    };
  }

  async createChannel(args) {
    const { name, isPrivate = false } = args;

    const result = await this.client.conversations.create({
      name,
      is_private: isPrivate,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            channelId: result.channel.id,
            name: result.channel.name,
            isPrivate: result.channel.is_private,
          }, null, 2),
        },
      ],
    };
  }

  async inviteUser(args) {
    const { channel, users } = args;

    const result = await this.client.conversations.invite({
      channel,
      users,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            channel: result.channel.id,
            channelName: result.channel.name,
          }, null, 2),
        },
      ],
    };
  }

  async uploadFile(args) {
    const { channel, filePath, title, initialComment } = args;
    const fs = require('fs');

    const result = await this.client.files.uploadV2({
      channel_id: channel,
      file: fs.createReadStream(filePath),
      filename: filePath.split('/').pop(),
      title,
      initial_comment: initialComment,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            fileId: result.file.id,
            title: result.file.title,
            permalink: result.file.permalink,
          }, null, 2),
        },
      ],
    };
  }

  async addReaction(args) {
    const { channel, timestamp, emoji } = args;

    await this.client.reactions.add({
      channel,
      timestamp,
      name: emoji,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            emoji,
            message: 'Reaction added successfully',
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Slack MCP] Server running on stdio');
  }
}

// Start server
const server = new SlackMCP();
server.run().catch(console.error);
