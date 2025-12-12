# =============================================================================
# Starbucks React Application - Production Dockerfile
# Multi-stage build for optimized production deployment
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Stage
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Install dependencies first (better layer caching)
COPY app/package.json app/package-lock.json ./

# Install all dependencies including devDependencies for build
RUN npm ci --legacy-peer-deps

# Copy source code from app directory
COPY app/ .

# Build the production application
RUN npm run build

# -----------------------------------------------------------------------------
# Stage 2: Production Stage
# -----------------------------------------------------------------------------
FROM nginx:1.25-alpine AS production

# Add non-root user for security
RUN addgroup -g 1001 -S starbucks && \
    adduser -u 1001 -S starbucks -G starbucks

# Remove default nginx config
RUN rm -rf /etc/nginx/conf.d/default.conf

# Copy custom nginx configuration
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

# Copy built application from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Set proper permissions
RUN chown -R starbucks:starbucks /usr/share/nginx/html && \
    chown -R starbucks:starbucks /var/cache/nginx && \
    chown -R starbucks:starbucks /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R starbucks:starbucks /var/run/nginx.pid

# Switch to non-root user
USER starbucks

# Expose port 8080 (non-privileged port)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
