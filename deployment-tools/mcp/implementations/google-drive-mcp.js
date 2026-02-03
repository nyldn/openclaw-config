#!/usr/bin/env node

/**
 * Google Drive MCP Server
 * Provides file storage and sharing operations via Model Context Protocol
 *
 * Tools:
 * - listFiles: List files and folders
 * - searchFiles: Search for files by name or content
 * - uploadFile: Upload a file to Drive
 * - downloadFile: Download a file from Drive
 * - createFolder: Create a new folder
 * - shareFile: Share a file with specific permissions
 * - getFileInfo: Get detailed file metadata
 * - deleteFile: Move a file to trash
 * - moveFile: Move a file to a different folder
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { google } = require('googleapis');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const CREDENTIALS_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
                        path.join(process.env.HOME, '.openclaw', 'google-drive-credentials.json');
const TOKEN_PATH = path.join(process.env.HOME, '.openclaw', 'google-drive-token.json');
const SCOPES = [
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/drive.metadata.readonly',
];

class GoogleDriveMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'google-drive-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.auth = null;
    this.drive = null;

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
          name: 'listFiles',
          description: 'List files and folders in Google Drive',
          inputSchema: {
            type: 'object',
            properties: {
              folderId: { type: 'string', description: 'Folder ID to list (default: root)' },
              maxResults: { type: 'number', description: 'Maximum number of files to return (default: 20)' },
              orderBy: { type: 'string', description: 'Sort order: name, modifiedTime, createdTime (default: modifiedTime desc)' },
              mimeType: { type: 'string', description: 'Filter by MIME type (e.g., "application/pdf", "image/jpeg")' },
            },
          },
        },
        {
          name: 'searchFiles',
          description: 'Search for files by name or content',
          inputSchema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query (searches file names and content)' },
              maxResults: { type: 'number', description: 'Maximum number of results (default: 20)' },
              mimeType: { type: 'string', description: 'Filter by MIME type (optional)' },
            },
            required: ['query'],
          },
        },
        {
          name: 'uploadFile',
          description: 'Upload a file to Google Drive',
          inputSchema: {
            type: 'object',
            properties: {
              localPath: { type: 'string', description: 'Local file path to upload' },
              fileName: { type: 'string', description: 'Name for the file in Drive (optional, uses local name if not provided)' },
              folderId: { type: 'string', description: 'Destination folder ID (optional, uploads to root if not provided)' },
              mimeType: { type: 'string', description: 'MIME type of the file (auto-detected if not provided)' },
            },
            required: ['localPath'],
          },
        },
        {
          name: 'downloadFile',
          description: 'Download a file from Google Drive',
          inputSchema: {
            type: 'object',
            properties: {
              fileId: { type: 'string', description: 'File ID to download' },
              localPath: { type: 'string', description: 'Local path to save the file' },
            },
            required: ['fileId', 'localPath'],
          },
        },
        {
          name: 'createFolder',
          description: 'Create a new folder in Google Drive',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Folder name' },
              parentId: { type: 'string', description: 'Parent folder ID (optional, creates in root if not provided)' },
            },
            required: ['name'],
          },
        },
        {
          name: 'shareFile',
          description: 'Share a file or folder with specific permissions',
          inputSchema: {
            type: 'object',
            properties: {
              fileId: { type: 'string', description: 'File or folder ID to share' },
              email: { type: 'string', description: 'Email address to share with (optional for "anyone" link)' },
              role: { type: 'string', description: 'Permission role: reader, commenter, writer, owner (default: reader)' },
              type: { type: 'string', description: 'Share type: user, group, domain, anyone (default: user if email provided, anyone otherwise)' },
              sendNotification: { type: 'boolean', description: 'Send notification email (default: true)' },
            },
            required: ['fileId'],
          },
        },
        {
          name: 'getFileInfo',
          description: 'Get detailed metadata for a file or folder',
          inputSchema: {
            type: 'object',
            properties: {
              fileId: { type: 'string', description: 'File or folder ID' },
            },
            required: ['fileId'],
          },
        },
        {
          name: 'deleteFile',
          description: 'Move a file or folder to trash',
          inputSchema: {
            type: 'object',
            properties: {
              fileId: { type: 'string', description: 'File or folder ID to delete' },
              permanent: { type: 'boolean', description: 'Permanently delete (skip trash)? Default: false' },
            },
            required: ['fileId'],
          },
        },
        {
          name: 'moveFile',
          description: 'Move a file to a different folder',
          inputSchema: {
            type: 'object',
            properties: {
              fileId: { type: 'string', description: 'File ID to move' },
              newFolderId: { type: 'string', description: 'Destination folder ID' },
            },
            required: ['fileId', 'newFolderId'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        if (!this.drive) {
          await this.initializeDrive();
        }

        switch (request.params.name) {
          case 'listFiles':
            return await this.listFiles(request.params.arguments);
          case 'searchFiles':
            return await this.searchFiles(request.params.arguments);
          case 'uploadFile':
            return await this.uploadFile(request.params.arguments);
          case 'downloadFile':
            return await this.downloadFile(request.params.arguments);
          case 'createFolder':
            return await this.createFolder(request.params.arguments);
          case 'shareFile':
            return await this.shareFile(request.params.arguments);
          case 'getFileInfo':
            return await this.getFileInfo(request.params.arguments);
          case 'deleteFile':
            return await this.deleteFile(request.params.arguments);
          case 'moveFile':
            return await this.moveFile(request.params.arguments);
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

  async initializeDrive() {
    try {
      // Load credentials
      const credentials = JSON.parse(await fs.readFile(CREDENTIALS_PATH, 'utf8'));

      // Create OAuth2 client
      const { client_secret, client_id, redirect_uris } = credentials.installed || credentials.web;
      const oAuth2Client = new google.auth.OAuth2(client_id, client_secret, redirect_uris[0]);

      // Load or request token
      try {
        const token = JSON.parse(await fs.readFile(TOKEN_PATH, 'utf8'));
        oAuth2Client.setCredentials(token);
      } catch (err) {
        throw new Error(
          `No token found. Please run the authentication flow first.\n` +
          `1. Run: node ${__filename} --auth\n` +
          `2. Or see setup guide: ~/.openclaw/productivity/google-drive-setup.md\n` +
          `Token should be saved to: ${TOKEN_PATH}`
        );
      }

      this.auth = oAuth2Client;
      this.drive = google.drive({ version: 'v3', auth: oAuth2Client });

      console.error('[Drive] Initialized successfully');
    } catch (error) {
      console.error('[Drive] Initialization error:', error.message);
      throw error;
    }
  }

  async listFiles(args) {
    const { folderId, maxResults = 20, orderBy = 'modifiedTime desc', mimeType } = args || {};

    let query = folderId ? `'${folderId}' in parents` : "'root' in parents";
    query += ' and trashed = false';

    if (mimeType) {
      query += ` and mimeType = '${mimeType}'`;
    }

    const response = await this.drive.files.list({
      q: query,
      pageSize: maxResults,
      orderBy,
      fields: 'files(id, name, mimeType, size, modifiedTime, createdTime, webViewLink, iconLink, parents)',
    });

    const files = response.data.files || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: files.length,
            files: files.map(file => ({
              id: file.id,
              name: file.name,
              mimeType: file.mimeType,
              size: file.size ? `${(parseInt(file.size) / 1024 / 1024).toFixed(2)} MB` : null,
              modifiedTime: file.modifiedTime,
              webViewLink: file.webViewLink,
              isFolder: file.mimeType === 'application/vnd.google-apps.folder',
            })),
          }, null, 2),
        },
      ],
    };
  }

  async searchFiles(args) {
    const { query, maxResults = 20, mimeType } = args;

    let driveQuery = `fullText contains '${query}' and trashed = false`;
    if (mimeType) {
      driveQuery += ` and mimeType = '${mimeType}'`;
    }

    const response = await this.drive.files.list({
      q: driveQuery,
      pageSize: maxResults,
      fields: 'files(id, name, mimeType, size, modifiedTime, webViewLink, parents)',
    });

    const files = response.data.files || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            count: files.length,
            files: files.map(file => ({
              id: file.id,
              name: file.name,
              mimeType: file.mimeType,
              size: file.size ? `${(parseInt(file.size) / 1024 / 1024).toFixed(2)} MB` : null,
              modifiedTime: file.modifiedTime,
              webViewLink: file.webViewLink,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async uploadFile(args) {
    const { localPath, fileName, folderId, mimeType } = args;

    // Read file content
    const fileContent = await fs.readFile(localPath);
    const finalName = fileName || path.basename(localPath);

    // Detect MIME type if not provided
    const finalMimeType = mimeType || this.detectMimeType(localPath);

    const fileMetadata = {
      name: finalName,
    };

    if (folderId) {
      fileMetadata.parents = [folderId];
    }

    const media = {
      mimeType: finalMimeType,
      body: require('stream').Readable.from(fileContent),
    };

    const response = await this.drive.files.create({
      resource: fileMetadata,
      media: media,
      fields: 'id, name, mimeType, size, webViewLink, webContentLink',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            fileId: response.data.id,
            name: response.data.name,
            mimeType: response.data.mimeType,
            webViewLink: response.data.webViewLink,
            webContentLink: response.data.webContentLink,
          }, null, 2),
        },
      ],
    };
  }

  async downloadFile(args) {
    const { fileId, localPath } = args;

    // Get file metadata first
    const fileInfo = await this.drive.files.get({
      fileId,
      fields: 'name, mimeType',
    });

    // Check if it's a Google Docs file (needs export)
    const googleDocTypes = {
      'application/vnd.google-apps.document': { mimeType: 'application/pdf', ext: '.pdf' },
      'application/vnd.google-apps.spreadsheet': { mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: '.xlsx' },
      'application/vnd.google-apps.presentation': { mimeType: 'application/pdf', ext: '.pdf' },
    };

    let response;
    let finalPath = localPath;

    if (googleDocTypes[fileInfo.data.mimeType]) {
      // Export Google Doc
      const exportType = googleDocTypes[fileInfo.data.mimeType];
      response = await this.drive.files.export({
        fileId,
        mimeType: exportType.mimeType,
      }, { responseType: 'arraybuffer' });
      
      if (!finalPath.includes('.')) {
        finalPath += exportType.ext;
      }
    } else {
      // Regular download
      response = await this.drive.files.get({
        fileId,
        alt: 'media',
      }, { responseType: 'arraybuffer' });
    }

    await fs.writeFile(finalPath, Buffer.from(response.data));

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            fileId,
            fileName: fileInfo.data.name,
            savedTo: finalPath,
            mimeType: fileInfo.data.mimeType,
          }, null, 2),
        },
      ],
    };
  }

  async createFolder(args) {
    const { name, parentId } = args;

    const fileMetadata = {
      name,
      mimeType: 'application/vnd.google-apps.folder',
    };

    if (parentId) {
      fileMetadata.parents = [parentId];
    }

    const response = await this.drive.files.create({
      resource: fileMetadata,
      fields: 'id, name, webViewLink',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            folderId: response.data.id,
            name: response.data.name,
            webViewLink: response.data.webViewLink,
          }, null, 2),
        },
      ],
    };
  }

  async shareFile(args) {
    const { fileId, email, role = 'reader', type, sendNotification = true } = args;

    const permission = {
      role,
      type: type || (email ? 'user' : 'anyone'),
    };

    if (email) {
      permission.emailAddress = email;
    }

    const response = await this.drive.permissions.create({
      fileId,
      resource: permission,
      sendNotificationEmail: sendNotification && !!email,
      fields: 'id, type, role, emailAddress',
    });

    // Get the shareable link
    const fileInfo = await this.drive.files.get({
      fileId,
      fields: 'webViewLink',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            permissionId: response.data.id,
            type: response.data.type,
            role: response.data.role,
            sharedWith: response.data.emailAddress || 'anyone with link',
            shareableLink: fileInfo.data.webViewLink,
          }, null, 2),
        },
      ],
    };
  }

  async getFileInfo(args) {
    const { fileId } = args;

    const response = await this.drive.files.get({
      fileId,
      fields: 'id, name, mimeType, size, createdTime, modifiedTime, owners, shared, webViewLink, webContentLink, parents, description',
    });

    const file = response.data;

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            id: file.id,
            name: file.name,
            mimeType: file.mimeType,
            size: file.size ? `${(parseInt(file.size) / 1024 / 1024).toFixed(2)} MB` : null,
            createdTime: file.createdTime,
            modifiedTime: file.modifiedTime,
            owners: file.owners?.map(o => o.emailAddress),
            shared: file.shared,
            description: file.description,
            webViewLink: file.webViewLink,
            webContentLink: file.webContentLink,
            isFolder: file.mimeType === 'application/vnd.google-apps.folder',
          }, null, 2),
        },
      ],
    };
  }

  async deleteFile(args) {
    const { fileId, permanent = false } = args;

    if (permanent) {
      await this.drive.files.delete({ fileId });
    } else {
      await this.drive.files.update({
        fileId,
        resource: { trashed: true },
      });
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            fileId,
            action: permanent ? 'permanently deleted' : 'moved to trash',
          }, null, 2),
        },
      ],
    };
  }

  async moveFile(args) {
    const { fileId, newFolderId } = args;

    // Get current parents
    const file = await this.drive.files.get({
      fileId,
      fields: 'parents',
    });

    const previousParents = file.data.parents?.join(',') || '';

    const response = await this.drive.files.update({
      fileId,
      addParents: newFolderId,
      removeParents: previousParents,
      fields: 'id, name, parents',
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            fileId: response.data.id,
            name: response.data.name,
            newParentId: newFolderId,
          }, null, 2),
        },
      ],
    };
  }

  detectMimeType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.zip': 'application/zip',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.svg': 'image/svg+xml',
      '.mp3': 'audio/mpeg',
      '.mp4': 'video/mp4',
      '.wav': 'audio/wav',
      '.md': 'text/markdown',
    };
    return mimeTypes[ext] || 'application/octet-stream';
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Drive MCP] Server running on stdio');
  }
}

// Start server
const server = new GoogleDriveMCP();
server.run().catch(console.error);
