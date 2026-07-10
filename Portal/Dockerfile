# Use Node.js 26 Alpine for smaller image size
FROM node:26-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies) for TypeScript build
RUN npm ci

# Copy TypeScript config and source
COPY tsconfig.json ./
COPY src ./src

# Build TypeScript using local compiler, then remove devDependencies
RUN npm run build && \
  npm prune --omit=dev

# Copy views and public assets
COPY views ./views
COPY public ./public

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/').on('error', () => process.exit(1))"

# Start application
CMD ["npm", "start"]
