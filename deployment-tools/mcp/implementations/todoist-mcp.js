#!/usr/bin/env node

/**
 * Todoist MCP Server
 * Provides task management operations via Model Context Protocol
 *
 * Tools:
 * - createTask: Create a new task
 * - listTasks: List tasks with filters
 * - updateTask: Update an existing task
 * - completeTask: Mark a task as completed
 * - deleteTask: Delete a task
 * - getProjects: List all projects
 * - createProject: Create a new project
 * - addComment: Add a comment to a task
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { TodoistApi } = require('@doist/todoist-api-typescript');

// Configuration
const TODOIST_API_TOKEN = process.env.TODOIST_API_TOKEN;

class TodoistMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'todoist-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.api = null;

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
          name: 'createTask',
          description: 'Create a new task in Todoist',
          inputSchema: {
            type: 'object',
            properties: {
              content: { type: 'string', description: 'Task content/title' },
              description: { type: 'string', description: 'Task description (optional)' },
              projectId: { type: 'string', description: 'Project ID (optional)' },
              dueString: { type: 'string', description: 'Due date in natural language (e.g., "tomorrow", "next Monday", optional)' },
              dueDate: { type: 'string', description: 'Due date in YYYY-MM-DD format (optional)' },
              priority: { type: 'number', description: 'Priority: 1 (normal) to 4 (urgent), default: 1' },
              labels: {
                type: 'array',
                items: { type: 'string' },
                description: 'Label names (optional)'
              },
            },
            required: ['content'],
          },
        },
        {
          name: 'listTasks',
          description: 'List tasks with optional filters',
          inputSchema: {
            type: 'object',
            properties: {
              projectId: { type: 'string', description: 'Filter by project ID (optional)' },
              filter: { type: 'string', description: 'Filter string (e.g., "today", "overdue", optional)' },
              label: { type: 'string', description: 'Filter by label (optional)' },
            },
          },
        },
        {
          name: 'updateTask',
          description: 'Update an existing task',
          inputSchema: {
            type: 'object',
            properties: {
              taskId: { type: 'string', description: 'Task ID to update' },
              content: { type: 'string', description: 'New task content (optional)' },
              description: { type: 'string', description: 'New description (optional)' },
              dueString: { type: 'string', description: 'New due date in natural language (optional)' },
              priority: { type: 'number', description: 'New priority 1-4 (optional)' },
              labels: {
                type: 'array',
                items: { type: 'string' },
                description: 'New labels (optional)'
              },
            },
            required: ['taskId'],
          },
        },
        {
          name: 'completeTask',
          description: 'Mark a task as completed',
          inputSchema: {
            type: 'object',
            properties: {
              taskId: { type: 'string', description: 'Task ID to complete' },
            },
            required: ['taskId'],
          },
        },
        {
          name: 'deleteTask',
          description: 'Delete a task',
          inputSchema: {
            type: 'object',
            properties: {
              taskId: { type: 'string', description: 'Task ID to delete' },
            },
            required: ['taskId'],
          },
        },
        {
          name: 'getProjects',
          description: 'List all projects',
          inputSchema: {
            type: 'object',
            properties: {},
          },
        },
        {
          name: 'createProject',
          description: 'Create a new project',
          inputSchema: {
            type: 'object',
            properties: {
              name: { type: 'string', description: 'Project name' },
              color: { type: 'string', description: 'Project color (optional, e.g., "red", "blue")' },
              favorite: { type: 'boolean', description: 'Mark as favorite (optional)' },
            },
            required: ['name'],
          },
        },
        {
          name: 'addComment',
          description: 'Add a comment to a task',
          inputSchema: {
            type: 'object',
            properties: {
              taskId: { type: 'string', description: 'Task ID' },
              content: { type: 'string', description: 'Comment content' },
            },
            required: ['taskId', 'content'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        if (!this.api) {
          this.initializeAPI();
        }

        switch (request.params.name) {
          case 'createTask':
            return await this.createTask(request.params.arguments);
          case 'listTasks':
            return await this.listTasks(request.params.arguments);
          case 'updateTask':
            return await this.updateTask(request.params.arguments);
          case 'completeTask':
            return await this.completeTask(request.params.arguments);
          case 'deleteTask':
            return await this.deleteTask(request.params.arguments);
          case 'getProjects':
            return await this.getProjects(request.params.arguments);
          case 'createProject':
            return await this.createProject(request.params.arguments);
          case 'addComment':
            return await this.addComment(request.params.arguments);
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

  initializeAPI() {
    if (!TODOIST_API_TOKEN) {
      throw new Error(
        'TODOIST_API_TOKEN environment variable is required.\n' +
        'Get your token from: https://todoist.com/prefs/integrations'
      );
    }

    this.api = new TodoistApi(TODOIST_API_TOKEN);
    console.error('[Todoist] API initialized');
  }

  async createTask(args) {
    const { content, description, projectId, dueString, dueDate, priority = 1, labels = [] } = args;

    const taskData = {
      content,
      description,
      projectId,
      priority,
      labels,
    };

    // Add due date if provided
    if (dueString) {
      taskData.dueString = dueString;
    } else if (dueDate) {
      taskData.dueDate = dueDate;
    }

    const task = await this.api.addTask(taskData);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            taskId: task.id,
            content: task.content,
            url: task.url,
            created: task.createdAt,
            priority: task.priority,
            due: task.due,
          }, null, 2),
        },
      ],
    };
  }

  async listTasks(args) {
    const { projectId, filter, label } = args;

    let tasks;

    if (projectId) {
      tasks = await this.api.getTasks({ projectId });
    } else if (filter) {
      tasks = await this.api.getTasks({ filter });
    } else if (label) {
      tasks = await this.api.getTasks({ label });
    } else {
      tasks = await this.api.getTasks();
    }

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: tasks.length,
            tasks: tasks.map(task => ({
              id: task.id,
              content: task.content,
              description: task.description,
              projectId: task.projectId,
              priority: task.priority,
              due: task.due,
              labels: task.labels,
              completed: task.isCompleted,
              url: task.url,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async updateTask(args) {
    const { taskId, content, description, dueString, priority, labels } = args;

    const updateData = {};
    if (content !== undefined) updateData.content = content;
    if (description !== undefined) updateData.description = description;
    if (dueString !== undefined) updateData.dueString = dueString;
    if (priority !== undefined) updateData.priority = priority;
    if (labels !== undefined) updateData.labels = labels;

    const task = await this.api.updateTask(taskId, updateData);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            taskId: task.id,
            content: task.content,
            updated: new Date().toISOString(),
          }, null, 2),
        },
      ],
    };
  }

  async completeTask(args) {
    const { taskId } = args;

    const result = await this.api.closeTask(taskId);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            taskId,
            completed: true,
            message: 'Task marked as completed',
          }, null, 2),
        },
      ],
    };
  }

  async deleteTask(args) {
    const { taskId } = args;

    const result = await this.api.deleteTask(taskId);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            taskId,
            deleted: true,
            message: 'Task deleted successfully',
          }, null, 2),
        },
      ],
    };
  }

  async getProjects(args) {
    const projects = await this.api.getProjects();

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: projects.length,
            projects: projects.map(project => ({
              id: project.id,
              name: project.name,
              color: project.color,
              favorite: project.isFavorite,
              commentCount: project.commentCount,
              url: project.url,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async createProject(args) {
    const { name, color, favorite } = args;

    const projectData = { name };
    if (color) projectData.color = color;
    if (favorite !== undefined) projectData.isFavorite = favorite;

    const project = await this.api.addProject(projectData);

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            projectId: project.id,
            name: project.name,
            url: project.url,
          }, null, 2),
        },
      ],
    };
  }

  async addComment(args) {
    const { taskId, content } = args;

    const comment = await this.api.addComment({
      taskId,
      content,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            commentId: comment.id,
            taskId,
            content: comment.content,
            posted: comment.postedAt,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Todoist MCP] Server running on stdio');
  }
}

// Start server
const server = new TodoistMCP();
server.run().catch(console.error);
