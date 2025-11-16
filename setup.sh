#!/bin/bash
set -e

echo "🚀 Setting up FamilyFinance project structure..."

# Create directory structure
mkdir -p .devcontainer
mkdir -p .github/workflows
mkdir -p backend/src/main/java/com/familyfinance/{config,controller}
mkdir -p backend/src/main/resources
mkdir -p backend/src/test/java
mkdir -p flutter_app/lib/{core/config,presentation/screens}
mkdir -p flutter_app/test
mkdir -p scripts
mkdir -p logs

# Create .devcontainer/devcontainer.json
cat > .devcontainer/devcontainer.json << 'DEVCONTAINER_EOF'
{
  "name": "FamilyFinance - Full Stack",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "features": {
    "ghcr.io/devcontainers/features/java:1": {
      "version": "17",
      "installMaven": "true"
    },
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "vscjava.vscode-java-pack",
        "Dart-Code.flutter",
        "alexisvt.flutter-snippets"
      ],
      "settings": {
        "dart.flutterSdkPath": "/home/vscode/flutter"
      }
    }
  },
  "forwardPorts": [8080, 5000, 5432],
  "portsAttributes": {
    "8080": {
      "label": "Backend API",
      "onAutoForward": "notify"
    },
    "5000": {
      "label": "Flutter Web",
      "onAutoForward": "openBrowser"
    }
  },
  "postCreateCommand": "bash .devcontainer/setup.sh",
  "remoteUser": "vscode"
}
DEVCONTAINER_EOF

# Create .devcontainer/Dockerfile
cat > .devcontainer/Dockerfile << 'DOCKERFILE_EOF'
FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl git unzip xz-utils zip libglu1-mesa \
    clang cmake ninja-build pkg-config libgtk-3-dev

USER vscode
WORKDIR /home/vscode

RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 \
    && echo 'export PATH="$PATH:/home/vscode/flutter/bin"' >> ~/.bashrc

ENV PATH="${PATH}:/home/vscode/flutter/bin"
RUN flutter precache --web \
    && flutter config --enable-web \
    && flutter config --no-analytics \
    && yes | flutter doctor --android-licenses 2>/dev/null || true

USER root
DOCKERFILE_EOF

# Create .devcontainer/setup.sh
cat > .devcontainer/setup.sh << 'SETUP_EOF'
#!/bin/bash
set -e

echo "🚀 Setting up development environment..."

export PATH="$PATH:/home/vscode/flutter/bin"
mkdir -p /workspace/logs

echo "🗄️ Starting PostgreSQL..."
docker run -d --name postgres-dev --network host \
  -e POSTGRES_DB=familyfinance \
  -e POSTGRES_USER=dev \
  -e POSTGRES_PASSWORD=devpass \
  -p 5432:5432 postgres:15-alpine

echo "⏳ Waiting for PostgreSQL..."
timeout 60 bash -c 'until docker exec postgres-dev pg_isready 2>/dev/null; do sleep 2; done'

if [ -f "/workspace/backend/pom.xml" ]; then
  cd /workspace/backend && chmod +x mvnw && ./mvnw dependency:resolve -q
fi

if [ -f "/workspace/flutter_app/pubspec.yaml" ]; then
  cd /workspace/flutter_app && flutter pub get
fi

chmod +x /workspace/scripts/*.sh

echo "✅ Setup complete! Run: ./scripts/dev.sh"
SETUP_EOF

chmod +x .devcontainer/setup.sh

# Create backend files
cat > backend/pom.xml << 'POM_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    <groupId>com.familyfinance</groupId>
    <artifactId>backend</artifactId>
    <version>0.1.0</version>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>
</project>
POM_EOF

cat > backend/src/main/resources/application.yml << 'APP_YML_EOF'
spring:
  application:
    name: family-finance
  datasource:
    url: jdbc:postgresql://localhost:5432/familyfinance
    username: dev
    password: devpass
  jpa:
    hibernate:
      ddl-auto: create-drop
    show-sql: true

server:
  port: 8080
  servlet:
    context-path: /api

management:
  endpoints:
    web:
      exposure:
        include: health,info
APP_YML_EOF

cat > backend/src/main/java/com/familyfinance/FamilyFinanceApplication.java << 'MAIN_EOF'
package com.familyfinance;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class FamilyFinanceApplication {
    public static void main(String[] args) {
        SpringApplication.run(FamilyFinanceApplication.class, args);
    }
}
MAIN_EOF

cat > backend/src/main/java/com/familyfinance/config/CorsConfig.java << 'CORS_EOF'
package com.familyfinance.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;
import java.util.Arrays;

@Configuration
public class CorsConfig {
    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowCredentials(true);
        config.setAllowedOriginPatterns(Arrays.asList("*"));
        config.addAllowedHeader("*");
        config.addAllowedMethod("*");
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return new CorsFilter(source);
    }
}
CORS_EOF

cat > backend/src/main/java/com/familyfinance/controller/HealthController.java << 'HEALTH_EOF'
package com.familyfinance.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/health")
public class HealthController {
    @GetMapping
    public Map<String, Object> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now());
        response.put("message", "FamilyFinance API is running!");
        response.put("version", "0.1.0");
        return response;
    }
}
HEALTH_EOF

cat > backend/.gitignore << 'BACKEND_IGNORE_EOF'
target/
.idea/
*.iml
*.log
logs/
BACKEND_IGNORE_EOF

# Create Flutter files
cat > flutter_app/pubspec.yaml << 'PUBSPEC_EOF'
name: family_finance
description: Open source family expense tracker
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  http: ^1.1.0
  provider: ^6.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
PUBSPEC_EOF

cat > flutter_app/lib/main.dart << 'MAIN_DART_EOF'
import 'package:flutter/material.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  runApp(const FamilyFinanceApp());
}

class FamilyFinanceApp extends StatelessWidget {
  const FamilyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyFinance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
MAIN_DART_EOF

cat > flutter_app/lib/core/config/api_config.dart << 'API_CONFIG_EOF'
class ApiConfig {
  static String get baseUrl {
    const codespaceName = String.fromEnvironment('CODESPACE_NAME');
    
    if (codespaceName.isNotEmpty) {
      return 'https://$codespaceName-8080.preview.app.github.dev/api';
    }
    
    return 'http://localhost:8080/api';
  }
}
API_CONFIG_EOF

cat > flutter_app/lib/presentation/screens/home_screen.dart << 'HOME_SCREEN_EOF'
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _status = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
  }

  Future<void> _checkBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _status = 'Connected to Backend!\n${data['message']}';
          _isLoading = false;
        });
      } else {
        setState(() {
          _status = 'Backend returned: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyFinance'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet, size: 100, color: Colors.blue),
              const SizedBox(height: 32),
              const Text('Welcome to FamilyFinance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text('Open Source Family Expense Tracker', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Backend Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_status, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _checkBackendHealth();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
HOME_SCREEN_EOF

cat > flutter_app/.gitignore << 'FLUTTER_IGNORE_EOF'
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
*.log
FLUTTER_IGNORE_EOF

cat > flutter_app/analysis_options.yaml << 'ANALYSIS_EOF'
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_final_fields: true
ANALYSIS_EOF

# Create scripts
cat > scripts/dev.sh << 'DEV_EOF'
#!/bin/bash
set -e

echo "🚀 Starting FamilyFinance Development"
mkdir -p /workspace/logs

if ! docker ps | grep -q postgres-dev; then
  docker start postgres-dev 2>/dev/null || \
  docker run -d --name postgres-dev --network host \
    -e POSTGRES_DB=familyfinance -e POSTGRES_USER=dev -e POSTGRES_PASSWORD=devpass \
    -p 5432:5432 postgres:15-alpine
  sleep 5
fi

echo "🔧 Starting Backend..."
cd /workspace/backend
./mvnw spring-boot:run > /workspace/logs/backend.log 2>&1 &
BACKEND_PID=$!

echo "⏳ Waiting for backend..."
timeout 120 bash -c 'until curl -s http://localhost:8080/api/health > /dev/null; do sleep 2; done'
echo "✅ Backend ready!"

echo "🎨 Starting Flutter..."
cd /workspace/flutter_app
flutter run -d web-server --web-port=5000 --web-hostname=0.0.0.0 \
  --dart-define=CODESPACE_NAME="${CODESPACE_NAME:-}" > /workspace/logs/flutter.log 2>&1 &
FLUTTER_PID=$!

echo ""
echo "✅ All services started!"
echo ""
if [ -n "$CODESPACE_NAME" ]; then
  echo "📱 Backend: https://${CODESPACE_NAME}-8080.preview.app.github.dev/api"
  echo "📱 Flutter: https://${CODESPACE_NAME}-5000.preview.app.github.dev"
else
  echo "📱 Backend: http://localhost:8080/api"
  echo "📱 Flutter: http://localhost:5000"
fi
echo ""
echo "📝 Logs: tail -f logs/backend.log or logs/flutter.log"
echo "🛑 Stop: Press Ctrl+C"

trap "echo ''; echo 'Stopping...'; kill $BACKEND_PID $FLUTTER_PID 2>/dev/null; echo 'Stopped'; exit" INT
wait
DEV_EOF

chmod +x scripts/dev.sh

# Create root files
cat > README.md << 'README_EOF'
# 💰 FamilyFinance

Open source family expense tracker built with Flutter & Spring Boot.

## Quick Start

[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)

1. Create a Codespace
2. Run: `./scripts/dev.sh`
3. Access the URLs shown in terminal

## Features

- 👨‍👩‍👧‍👦 Multi-user families
- 💸 Track expenses
- 📊 Visual reports
- 🔒 Privacy-focused

## Tech Stack

- Backend: Spring Boot 3 + PostgreSQL
- Frontend: Flutter 3
- Deployment: Docker + GitHub Actions

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

## License

MIT
README_EOF

cat > CONTRIBUTING.md << 'CONTRIB_EOF'
# Contributing

## Getting Started

1. Fork the repository
2. Create a Codespace
3. Run `./scripts/dev.sh`
4. Make changes
5. Test locally
6. Submit PR

## Development

- Backend tests: `cd backend && ./mvnw test`
- Flutter tests: `cd flutter_app && flutter test`

## Questions?

Open an issue!
CONTRIB_EOF

cat > .gitignore << 'ROOT_IGNORE_EOF'
logs/
*.log
.DS_Store
.vscode/
ROOT_IGNORE_EOF

echo "✅ Project structure created!"
echo ""
echo "Next steps:"
echo "1. Commit all files: git add . && git commit -m 'Initial setup'"
echo "2. Push: git push"
echo "3. Rebuild Codespace (close and create new one)"
echo "4. Run: ./scripts/dev.sh"