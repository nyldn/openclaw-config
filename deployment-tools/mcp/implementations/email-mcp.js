#!/usr/bin/env node

/**
 * Email MCP Server
 * Provides email operations via Model Context Protocol
 * Supports IMAP (reading) and SMTP (sending)
 *
 * Tools:
 * - listEmails: List emails from inbox or folder
 * - readEmail: Read a specific email by ID
 * - sendEmail: Send a new email
 * - replyToEmail: Reply to an email
 * - searchEmail: Search emails by criteria
 * - moveToFolder: Move email to another folder
 * - markAsRead: Mark email as read
 * - markAsUnread: Mark email as unread
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const Imap = require('imap');
const { simpleParser } = require('mailparser');
const nodemailer = require('nodemailer');

// Configuration from environment variables
const EMAIL_CONFIG = {
  imap: {
    user: process.env.EMAIL_USERNAME,
    password: process.env.EMAIL_PASSWORD,
    host: process.env.EMAIL_IMAP_HOST || 'imap.gmail.com',
    port: parseInt(process.env.EMAIL_IMAP_PORT) || 993,
    tls: true,
    tlsOptions: { rejectUnauthorized: false },
  },
  smtp: {
    host: process.env.EMAIL_SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.EMAIL_SMTP_PORT) || 587,
    secure: false, // use STARTTLS
    auth: {
      user: process.env.EMAIL_USERNAME,
      pass: process.env.EMAIL_PASSWORD,
    },
  },
};

class EmailMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'email-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

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
          name: 'listEmails',
          description: 'List emails from inbox or a specific folder',
          inputSchema: {
            type: 'object',
            properties: {
              folder: { type: 'string', description: 'Folder name (default: INBOX)' },
              limit: { type: 'number', description: 'Maximum number of emails to return (default: 20)' },
              unreadOnly: { type: 'boolean', description: 'Only show unread emails (default: false)' },
            },
          },
        },
        {
          name: 'readEmail',
          description: 'Read a specific email by UID',
          inputSchema: {
            type: 'object',
            properties: {
              uid: { type: 'number', description: 'Email UID' },
              folder: { type: 'string', description: 'Folder name (default: INBOX)' },
              markAsRead: { type: 'boolean', description: 'Mark email as read (default: false)' },
            },
            required: ['uid'],
          },
        },
        {
          name: 'sendEmail',
          description: 'Send a new email',
          inputSchema: {
            type: 'object',
            properties: {
              to: { type: 'string', description: 'Recipient email address (comma-separated for multiple)' },
              subject: { type: 'string', description: 'Email subject' },
              text: { type: 'string', description: 'Plain text email body' },
              html: { type: 'string', description: 'HTML email body (optional)' },
              cc: { type: 'string', description: 'CC recipients (comma-separated, optional)' },
              bcc: { type: 'string', description: 'BCC recipients (comma-separated, optional)' },
            },
            required: ['to', 'subject', 'text'],
          },
        },
        {
          name: 'replyToEmail',
          description: 'Reply to an email',
          inputSchema: {
            type: 'object',
            properties: {
              uid: { type: 'number', description: 'Original email UID' },
              text: { type: 'string', description: 'Reply message' },
              html: { type: 'string', description: 'HTML reply message (optional)' },
              replyAll: { type: 'boolean', description: 'Reply to all recipients (default: false)' },
            },
            required: ['uid', 'text'],
          },
        },
        {
          name: 'searchEmail',
          description: 'Search emails by criteria',
          inputSchema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query (from, subject, body keywords)' },
              folder: { type: 'string', description: 'Folder to search in (default: INBOX)' },
              limit: { type: 'number', description: 'Maximum results (default: 20)' },
            },
            required: ['query'],
          },
        },
        {
          name: 'moveToFolder',
          description: 'Move an email to another folder',
          inputSchema: {
            type: 'object',
            properties: {
              uid: { type: 'number', description: 'Email UID' },
              sourceFolder: { type: 'string', description: 'Source folder (default: INBOX)' },
              destinationFolder: { type: 'string', description: 'Destination folder' },
            },
            required: ['uid', 'destinationFolder'],
          },
        },
        {
          name: 'markAsRead',
          description: 'Mark an email as read',
          inputSchema: {
            type: 'object',
            properties: {
              uid: { type: 'number', description: 'Email UID' },
              folder: { type: 'string', description: 'Folder name (default: INBOX)' },
            },
            required: ['uid'],
          },
        },
        {
          name: 'markAsUnread',
          description: 'Mark an email as unread',
          inputSchema: {
            type: 'object',
            properties: {
              uid: { type: 'number', description: 'Email UID' },
              folder: { type: 'string', description: 'Folder name (default: INBOX)' },
            },
            required: ['uid'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        switch (request.params.name) {
          case 'listEmails':
            return await this.listEmails(request.params.arguments);
          case 'readEmail':
            return await this.readEmail(request.params.arguments);
          case 'sendEmail':
            return await this.sendEmail(request.params.arguments);
          case 'replyToEmail':
            return await this.replyToEmail(request.params.arguments);
          case 'searchEmail':
            return await this.searchEmail(request.params.arguments);
          case 'moveToFolder':
            return await this.moveToFolder(request.params.arguments);
          case 'markAsRead':
            return await this.markAsRead(request.params.arguments);
          case 'markAsUnread':
            return await this.markAsUnread(request.params.arguments);
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

  connectIMAP(folder = 'INBOX') {
    return new Promise((resolve, reject) => {
      const imap = new Imap(EMAIL_CONFIG.imap);

      imap.once('ready', () => {
        imap.openBox(folder, false, (err) => {
          if (err) reject(err);
          else resolve(imap);
        });
      });

      imap.once('error', reject);
      imap.connect();
    });
  }

  async listEmails(args) {
    const { folder = 'INBOX', limit = 20, unreadOnly = false } = args;

    const imap = await this.connectIMAP(folder);

    return new Promise((resolve, reject) => {
      const criteria = unreadOnly ? ['UNSEEN'] : ['ALL'];

      imap.search(criteria, (err, results) => {
        if (err) {
          imap.end();
          return reject(err);
        }

        if (!results || results.length === 0) {
          imap.end();
          return resolve({
            content: [{ type: 'text', text: JSON.stringify({ count: 0, emails: [] }, null, 2) }],
          });
        }

        // Get most recent emails first
        const uids = results.slice(-limit).reverse();
        const fetch = imap.fetch(uids, { bodies: 'HEADER.FIELDS (FROM TO SUBJECT DATE)', struct: true });
        const emails = [];

        fetch.on('message', (msg, seqno) => {
          const email = { uid: seqno };

          msg.on('body', (stream) => {
            simpleParser(stream, (err, parsed) => {
              if (!err) {
                email.from = parsed.from?.text;
                email.to = parsed.to?.text;
                email.subject = parsed.subject;
                email.date = parsed.date;
              }
            });
          });

          msg.once('attributes', (attrs) => {
            email.flags = attrs.flags;
            email.size = attrs.size;
          });

          msg.once('end', () => {
            emails.push(email);
          });
        });

        fetch.once('error', reject);

        fetch.once('end', () => {
          imap.end();
          resolve({
            content: [
              {
                type: 'text',
                text: JSON.stringify({ count: emails.length, emails }, null, 2),
              },
            ],
          });
        });
      });
    });
  }

  async readEmail(args) {
    const { uid, folder = 'INBOX', markAsRead = false } = args;

    const imap = await this.connectIMAP(folder);

    return new Promise((resolve, reject) => {
      const fetch = imap.fetch([uid], { bodies: '' });
      let email = null;

      fetch.on('message', (msg) => {
        msg.on('body', (stream) => {
          simpleParser(stream, (err, parsed) => {
            if (err) return reject(err);

            email = {
              uid,
              from: parsed.from?.text,
              to: parsed.to?.text,
              cc: parsed.cc?.text,
              subject: parsed.subject,
              date: parsed.date,
              text: parsed.text,
              html: parsed.html,
              attachments: parsed.attachments?.map(a => ({ filename: a.filename, size: a.size })),
            };
          });
        });

        msg.once('attributes', (attrs) => {
          if (email) email.flags = attrs.flags;
        });
      });

      fetch.once('error', reject);

      fetch.once('end', () => {
        if (markAsRead) {
          imap.addFlags(uid, ['\\Seen'], (err) => {
            imap.end();
            if (err) return reject(err);
            resolve({ content: [{ type: 'text', text: JSON.stringify(email, null, 2) }] });
          });
        } else {
          imap.end();
          resolve({ content: [{ type: 'text', text: JSON.stringify(email, null, 2) }] });
        }
      });
    });
  }

  async sendEmail(args) {
    const { to, subject, text, html, cc, bcc } = args;

    const transporter = nodemailer.createTransport(EMAIL_CONFIG.smtp);

    const mailOptions = {
      from: EMAIL_CONFIG.smtp.auth.user,
      to,
      subject,
      text,
      html,
      cc,
      bcc,
    };

    const info = await transporter.sendMail(mailOptions);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            messageId: info.messageId,
            to,
            subject,
          }, null, 2),
        },
      ],
    };
  }

  async replyToEmail(args) {
    const { uid, text, html, replyAll = false } = args;

    // First, read the original email
    const original = await this.readEmail({ uid });
    const originalData = JSON.parse(original.content[0].text);

    // Extract reply-to or from address
    const replyTo = originalData.from;

    // Prepare reply
    const mailOptions = {
      to: replyTo,
      subject: `Re: ${originalData.subject}`,
      text,
      html,
    };

    if (replyAll && originalData.cc) {
      mailOptions.cc = originalData.cc;
    }

    return await this.sendEmail(mailOptions);
  }

  async searchEmail(args) {
    const { query, folder = 'INBOX', limit = 20 } = args;

    const imap = await this.connectIMAP(folder);

    return new Promise((resolve, reject) => {
      // Simple search by subject or body
      const criteria = [['OR', ['SUBJECT', query], ['BODY', query]]];

      imap.search(criteria, (err, results) => {
        if (err) {
          imap.end();
          return reject(err);
        }

        if (!results || results.length === 0) {
          imap.end();
          return resolve({
            content: [{ type: 'text', text: JSON.stringify({ query, count: 0, emails: [] }, null, 2) }],
          });
        }

        const uids = results.slice(-limit).reverse();
        const fetch = imap.fetch(uids, { bodies: 'HEADER.FIELDS (FROM TO SUBJECT DATE)' });
        const emails = [];

        fetch.on('message', (msg, seqno) => {
          const email = { uid: seqno };

          msg.on('body', (stream) => {
            simpleParser(stream, (err, parsed) => {
              if (!err) {
                email.from = parsed.from?.text;
                email.subject = parsed.subject;
                email.date = parsed.date;
              }
            });
          });

          msg.once('end', () => {
            emails.push(email);
          });
        });

        fetch.once('end', () => {
          imap.end();
          resolve({
            content: [{ type: 'text', text: JSON.stringify({ query, count: emails.length, emails }, null, 2) }],
          });
        });
      });
    });
  }

  async markAsRead(args) {
    const { uid, folder = 'INBOX' } = args;
    const imap = await this.connectIMAP(folder);

    return new Promise((resolve, reject) => {
      imap.addFlags(uid, ['\\Seen'], (err) => {
        imap.end();
        if (err) return reject(err);
        resolve({ content: [{ type: 'text', text: JSON.stringify({ success: true, uid }, null, 2) }] });
      });
    });
  }

  async markAsUnread(args) {
    const { uid, folder = 'INBOX' } = args;
    const imap = await this.connectIMAP(folder);

    return new Promise((resolve, reject) => {
      imap.delFlags(uid, ['\\Seen'], (err) => {
        imap.end();
        if (err) return reject(err);
        resolve({ content: [{ type: 'text', text: JSON.stringify({ success: true, uid }, null, 2) }] });
      });
    });
  }

  async moveToFolder(args) {
    const { uid, sourceFolder = 'INBOX', destinationFolder } = args;
    const imap = await this.connectIMAP(sourceFolder);

    return new Promise((resolve, reject) => {
      imap.move(uid, destinationFolder, (err) => {
        imap.end();
        if (err) return reject(err);
        resolve({
          content: [
            {
              type: 'text',
              text: JSON.stringify({ success: true, uid, moved: `${sourceFolder} -> ${destinationFolder}` }, null, 2),
            },
          ],
        });
      });
    });
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Email MCP] Server running on stdio');
  }
}

// Start server
const server = new EmailMCP();
server.run().catch(console.error);
