#!/bin/bash

# CloudLAPS Portal - Installation Script
# This script sets up the Node.js version of CloudLAPS Portal

set -e

echo "=================================="
echo "CloudLAPS Portal - Setup Script"
echo "=================================="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    echo "Please install Node.js 26+ from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 26 ]; then
    echo "❌ Node.js version 26 or higher is required"
    echo "Current version: $(node --version)"
    exit 1
fi

echo "✓ Node.js $(node --version) detected"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi

echo "✓ npm $(npm --version) detected"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
npm install

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

echo "✓ Dependencies installed"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "✓ .env file created"
    echo ""
    echo "⚠️  IMPORTANT: Edit .env file and add your Azure credentials:"
    echo "   - APP_BASE_URL"
    echo "   - KEY_VAULT_URI"
    echo "   - LOG_ANALYTICS_WORKSPACE_ID"
    echo "   - LOG_ANALYTICS_SHARED_KEY"
    echo ""
else
    echo "✓ .env file already exists"
fi

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ Failed to build TypeScript"
    exit 1
fi

echo "✓ Build complete"
echo ""

# Check Azure CLI (optional)
if command -v az &> /dev/null; then
    echo "✓ Azure CLI detected (version: $(az --version | head -1))"
    echo "  You can use 'az login' for local development with Managed Identity"
else
    echo "ℹ️  Azure CLI not found (optional)"
    echo "   Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
fi

echo ""
echo "=================================="
echo "✅ Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your Azure credentials"
echo "2. Run 'npm run dev' to start development server"
echo "3. Open http://localhost:3000 in your browser"
echo ""
echo "For deployment instructions, see DEPLOYMENT.md"
echo "For quick start guide, see QUICKSTART.md"
echo ""
