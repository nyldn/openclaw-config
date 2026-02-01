#!/bin/sh
# OpenClaw VM - Deployment Tools Installation Script
# Installs Vercel, Netlify, and Supabase CLIs for seamless deployment

set -e

echo "🚀 Installing deployment CLI tools..."

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Installing Node.js..."
    apk add --no-cache nodejs npm
fi

# Install Vercel CLI
echo "📦 Installing Vercel CLI..."
npm install -g vercel

# Install Netlify CLI
echo "📦 Installing Netlify CLI..."
npm install -g netlify-cli

# Install Supabase CLI
echo "📦 Installing Supabase CLI..."
npm install -g supabase

# Verify installations
echo ""
echo "✅ Installation complete! Versions:"
echo "   Vercel:   $(vercel --version 2>&1 | head -n1)"
echo "   Netlify:  $(netlify --version 2>&1 | head -n1)"
echo "   Supabase: $(supabase --version 2>&1 | head -n1)"
echo ""
echo "🎉 Deployment tools ready!"
echo ""
echo "Next steps:"
echo "  1. vercel login     - Authenticate with Vercel"
echo "  2. netlify login    - Authenticate with Netlify"
echo "  3. supabase login   - Authenticate with Supabase"
