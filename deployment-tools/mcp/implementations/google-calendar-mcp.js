#!/usr/bin/env node

/**
 * Google Calendar MCP Server
 * Provides calendar operations via Model Context Protocol
 *
 * Tools:
 * - createEvent: Create a new calendar event
 * - listEvents: List upcoming events
 * - updateEvent: Update an existing event
 * - deleteEvent: Delete an event
 * - searchCalendar: Search for events by query
 * - getAvailability: Check availability for a time range
 */

const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const { google } = require('googleapis');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const CREDENTIALS_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
                        path.join(process.env.HOME, '.openclaw', 'google-calendar-credentials.json');
const TOKEN_PATH = path.join(process.env.HOME, '.openclaw', 'google-calendar-token.json');
const SCOPES = ['https://www.googleapis.com/auth/calendar'];

class GoogleCalendarMCP {
  constructor() {
    this.server = new Server(
      {
        name: 'google-calendar-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.auth = null;
    this.calendar = null;

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
          name: 'createEvent',
          description: 'Create a new calendar event',
          inputSchema: {
            type: 'object',
            properties: {
              summary: { type: 'string', description: 'Event title' },
              description: { type: 'string', description: 'Event description (optional)' },
              location: { type: 'string', description: 'Event location (optional)' },
              startTime: { type: 'string', description: 'Start time in ISO 8601 format' },
              endTime: { type: 'string', description: 'End time in ISO 8601 format' },
              attendees: {
                type: 'array',
                items: { type: 'string' },
                description: 'Email addresses of attendees (optional)'
              },
              timezone: { type: 'string', description: 'Timezone (optional, e.g., America/Los_Angeles)' },
            },
            required: ['summary', 'startTime', 'endTime'],
          },
        },
        {
          name: 'listEvents',
          description: 'List upcoming calendar events',
          inputSchema: {
            type: 'object',
            properties: {
              maxResults: { type: 'number', description: 'Maximum number of events to return (default: 10)' },
              timeMin: { type: 'string', description: 'Start time for event search (ISO 8601, optional)' },
              timeMax: { type: 'string', description: 'End time for event search (ISO 8601, optional)' },
              calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            },
          },
        },
        {
          name: 'updateEvent',
          description: 'Update an existing calendar event',
          inputSchema: {
            type: 'object',
            properties: {
              eventId: { type: 'string', description: 'Event ID to update' },
              summary: { type: 'string', description: 'New event title (optional)' },
              description: { type: 'string', description: 'New event description (optional)' },
              location: { type: 'string', description: 'New event location (optional)' },
              startTime: { type: 'string', description: 'New start time in ISO 8601 format (optional)' },
              endTime: { type: 'string', description: 'New end time in ISO 8601 format (optional)' },
              calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            },
            required: ['eventId'],
          },
        },
        {
          name: 'deleteEvent',
          description: 'Delete a calendar event',
          inputSchema: {
            type: 'object',
            properties: {
              eventId: { type: 'string', description: 'Event ID to delete' },
              calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            },
            required: ['eventId'],
          },
        },
        {
          name: 'searchCalendar',
          description: 'Search for events by query string',
          inputSchema: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'Search query' },
              maxResults: { type: 'number', description: 'Maximum number of results (default: 10)' },
              calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            },
            required: ['query'],
          },
        },
        {
          name: 'getAvailability',
          description: 'Check availability (free/busy) for a time range',
          inputSchema: {
            type: 'object',
            properties: {
              timeMin: { type: 'string', description: 'Start time in ISO 8601 format' },
              timeMax: { type: 'string', description: 'End time in ISO 8601 format' },
              calendarId: { type: 'string', description: 'Calendar ID (default: primary)' },
            },
            required: ['timeMin', 'timeMax'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        if (!this.calendar) {
          await this.initializeCalendar();
        }

        switch (request.params.name) {
          case 'createEvent':
            return await this.createEvent(request.params.arguments);
          case 'listEvents':
            return await this.listEvents(request.params.arguments);
          case 'updateEvent':
            return await this.updateEvent(request.params.arguments);
          case 'deleteEvent':
            return await this.deleteEvent(request.params.arguments);
          case 'searchCalendar':
            return await this.searchCalendar(request.params.arguments);
          case 'getAvailability':
            return await this.getAvailability(request.params.arguments);
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

  async initializeCalendar() {
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
          `Visit: https://developers.google.com/calendar/api/quickstart/nodejs\n` +
          `Token should be saved to: ${TOKEN_PATH}`
        );
      }

      this.auth = oAuth2Client;
      this.calendar = google.calendar({ version: 'v3', auth: oAuth2Client });

      console.error('[Calendar] Initialized successfully');
    } catch (error) {
      console.error('[Calendar] Initialization error:', error.message);
      throw error;
    }
  }

  async createEvent(args) {
    const { summary, description, location, startTime, endTime, attendees, timezone, calendarId = 'primary' } = args;

    const event = {
      summary,
      description,
      location,
      start: {
        dateTime: startTime,
        timeZone: timezone || 'UTC',
      },
      end: {
        dateTime: endTime,
        timeZone: timezone || 'UTC',
      },
    };

    if (attendees && attendees.length > 0) {
      event.attendees = attendees.map(email => ({ email }));
    }

    const response = await this.calendar.events.insert({
      calendarId,
      resource: event,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            eventId: response.data.id,
            htmlLink: response.data.htmlLink,
            summary: response.data.summary,
            start: response.data.start,
            end: response.data.end,
          }, null, 2),
        },
      ],
    };
  }

  async listEvents(args) {
    const { maxResults = 10, timeMin, timeMax, calendarId = 'primary' } = args;

    const options = {
      calendarId,
      timeMin: timeMin || new Date().toISOString(),
      timeMax,
      maxResults,
      singleEvents: true,
      orderBy: 'startTime',
    };

    const response = await this.calendar.events.list(options);
    const events = response.data.items || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            count: events.length,
            events: events.map(event => ({
              id: event.id,
              summary: event.summary,
              start: event.start.dateTime || event.start.date,
              end: event.end.dateTime || event.end.date,
              location: event.location,
              htmlLink: event.htmlLink,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async updateEvent(args) {
    const { eventId, summary, description, location, startTime, endTime, calendarId = 'primary' } = args;

    // First, get the existing event
    const existing = await this.calendar.events.get({
      calendarId,
      eventId,
    });

    // Update only provided fields
    const event = { ...existing.data };
    if (summary) event.summary = summary;
    if (description) event.description = description;
    if (location) event.location = location;
    if (startTime) event.start = { ...event.start, dateTime: startTime };
    if (endTime) event.end = { ...event.end, dateTime: endTime };

    const response = await this.calendar.events.update({
      calendarId,
      eventId,
      resource: event,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            eventId: response.data.id,
            summary: response.data.summary,
            updated: response.data.updated,
          }, null, 2),
        },
      ],
    };
  }

  async deleteEvent(args) {
    const { eventId, calendarId = 'primary' } = args;

    await this.calendar.events.delete({
      calendarId,
      eventId,
    });

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            success: true,
            eventId,
            message: 'Event deleted successfully',
          }, null, 2),
        },
      ],
    };
  }

  async searchCalendar(args) {
    const { query, maxResults = 10, calendarId = 'primary' } = args;

    const response = await this.calendar.events.list({
      calendarId,
      q: query,
      maxResults,
      singleEvents: true,
      orderBy: 'startTime',
    });

    const events = response.data.items || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            query,
            count: events.length,
            events: events.map(event => ({
              id: event.id,
              summary: event.summary,
              start: event.start.dateTime || event.start.date,
              end: event.end.dateTime || event.end.date,
              location: event.location,
              htmlLink: event.htmlLink,
            })),
          }, null, 2),
        },
      ],
    };
  }

  async getAvailability(args) {
    const { timeMin, timeMax, calendarId = 'primary' } = args;

    const response = await this.calendar.freebusy.query({
      resource: {
        timeMin,
        timeMax,
        items: [{ id: calendarId }],
      },
    });

    const busySlots = response.data.calendars[calendarId].busy || [];

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify({
            timeMin,
            timeMax,
            busySlots,
            isFree: busySlots.length === 0,
          }, null, 2),
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('[Calendar MCP] Server running on stdio');
  }
}

// Start server
const server = new GoogleCalendarMCP();
server.run().catch(console.error);
