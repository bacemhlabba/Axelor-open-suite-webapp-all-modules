# =============================================
# Axelor Open Suite Docker Build
# Multi-stage build: Gradle + Tomcat
# =============================================

# Build stage - compile the application
FROM eclipse-temurin:21-jdk AS builder

# Install dos2unix for line ending conversion
RUN apt-get update && apt-get install -y dos2unix && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gradle wrapper and build files first (for caching)
COPY gradlew gradlew.bat ./
COPY gradle ./gradle
COPY build.gradle settings.gradle gradle.properties ./
COPY buildSrc ./buildSrc

# Copy source code and modules
COPY src ./src
COPY modules ./modules

# Fix line endings, make gradlew executable, and build
RUN dos2unix ./gradlew && \
    chmod +x ./gradlew && \
    ./gradlew clean build -x test --no-daemon -Pstyle.skipCompileStyle=true -Dorg.gradle.jvmargs=-Xmx3g

# =============================================
# Runtime stage - minimal Tomcat deployment
# =============================================
FROM tomcat:10.1-jdk21-temurin

# Install curl for health check
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy the built WAR file
COPY --from=builder /app/build/libs/*.war /usr/local/tomcat/webapps/ROOT.war

# Create data directories
RUN mkdir -p /opt/axelor/data /opt/axelor/logs /opt/axelor/reports && \
    chmod -R 755 /opt/axelor

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Start Tomcat
CMD ["catalina.sh", "run"]
