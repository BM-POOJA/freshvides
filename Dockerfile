FROM google/dart:latest AS build
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
RUN dart_frog build

FROM google/dart:latest
WORKDIR /app
COPY --from=build /app/build ./build
COPY --from=build /app/.dart_tool ./.dart_tool

EXPOSE 8080
ENV PORT=8080
CMD ["dart", "build/bin/server.dart"]
