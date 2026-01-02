# Use official Dart image
FROM google/dart:latest

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./

# Get dependencies
RUN dart pub get

# Copy project files
COPY . .

# Build Dart Frog for production
RUN dart_frog build

# Expose port (Vercel will override this)
EXPOSE 8080

# Run the app with PORT from environment
CMD ["dart", "build/bin/server.dart", "--port", "${PORT:-8080}"]
