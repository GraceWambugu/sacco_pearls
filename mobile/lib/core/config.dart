/// Where the FastAPI backend lives.
///
/// Set it when starting the app, for example:
///   flutter run --dart-define=API_BASE=http://192.168.1.20:8000
/// Without it, the app uses 10.0.2.2, which is how the Android Emulator
/// reaches the laptop it runs on.
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:8000',
);
