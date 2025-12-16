# Synce - PDF Synchronization App

A cross-platform PDF synchronization application that enables seamless file syncing across devices. Built with Flutter for the client and NestJS for the backend.

## Features

- **User Authentication** - Secure registration and login system with JWT tokens
- **PDF Synchronization** - Real-time sync of PDF files across multiple devices
- **Offline Support** - Local SQLite database for offline file access
- **Cross-Platform** - Supports Android, Windows, and other Flutter platforms
- **File Management** - Upload, download, and manage PDF files efficiently
- **Conflict Resolution** - Smart handling of file version conflicts

## Tech Stack

### Client (Flutter)
- **Framework**: Flutter/Dart
- **State Management**: Provider pattern
- **Local Database**: SQLite (sqflite)
- **HTTP Client**: http package
- **File Handling**: path_provider, file_picker

### Server (NestJS)
- **Framework**: NestJS (Node.js)
- **Database**: PostgreSQL with Prisma ORM
- **Authentication**: JWT (JSON Web Tokens)
- **File Storage**: Local file system
- **API**: RESTful endpoints

## Project Structure

```
synce/
├── client/              # Flutter mobile/desktop app
│   ├── lib/
│   │   ├── data/       # API client & database
│   │   ├── logic/      # Providers & business logic
│   │   ├── pages/      # UI screens
│   │   └── main.dart   # App entry point
│   └── pubspec.yaml
├── server/             # NestJS backend
│   ├── src/
│   │   ├── auth/       # Authentication module
│   │   ├── files/      # File management
│   │   ├── sync/       # Sync logic
│   │   └── prisma/     # Database client
│   └── package.json
└── docker-compose.yml  # PostgreSQL container
```

## Setup Instructions

### Prerequisites

- **Flutter SDK** (latest stable version)
- **Node.js** (v18 or higher)
- **Docker** (for PostgreSQL)
- **Git**

### Server Setup

1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start PostgreSQL with Docker:
   ```bash
   cd ..
   docker-compose up -d
   ```

4. Set up environment variables (create `.env` in server directory):
   ```env
   DATABASE_URL="postgresql://user:password@localhost:5432/syncdb"
   JWT_SECRET="your-secret-key-here"
   ```

5. Run database migrations:
   ```bash
   npx prisma migrate dev
   ```

6. Start the server:
   ```bash
   npm run start:dev
   ```

Server will run on `http://localhost:3000`

### Client Setup

1. Navigate to the client directory:
   ```bash
   cd client
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Update API endpoint in `lib/data/api_client.dart` if needed:
   ```dart
   static const String baseUrl = 'http://localhost:3000';
   ```

4. Run the app:
   ```bash
   # For Windows
   flutter run -d windows
   
   # For Android
   flutter run -d android
   ```

## Usage

1. **Register**: Create a new account using the registration screen
2. **Login**: Sign in with your credentials
3. **Sync Files**: Upload PDFs from your device
4. **Access Anywhere**: Files automatically sync across all your devices
5. **Offline Access**: View previously synced files without internet connection

## API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get JWT token

### Files
- `GET /sync/files` - Get all user files
- `POST /sync/upload` - Upload a new file
- `GET /sync/download/:id` - Download a file
- `DELETE /sync/files/:id` - Delete a file
- `PUT /sync/files/:id` - Update file metadata

## Development

### Running Tests

**Server:**
```bash
cd server
npm run test
```

**Client:**
```bash
cd client
flutter test
```

### Database Management

View database with Prisma Studio:
```bash
cd server
npx prisma studio
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please open an issue on the GitHub repository.


