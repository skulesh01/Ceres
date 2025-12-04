# Dockerfile for Taiga front (Angular) with optional Gantt plugin
# Base image with Node.js for building the Angular app
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci --silent

# Copy the rest of the source code
COPY . ./

# Build the Angular application (production)
RUN npm run build --prod

# ---------- Runtime image ----------
FROM nginx:stable-alpine

# Copy built assets from builder stage
COPY --from=builder /app/dist/taiga-front /usr/share/nginx/html

# Expose HTTP port (Traefik will handle TLS)
EXPOSE 80

# Default command runs nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
