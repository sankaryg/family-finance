class ApiConfig {
  static String get baseUrl {
    const codespaceName = String.fromEnvironment('CODESPACE_NAME');
    
    if (codespaceName.isNotEmpty) {
      return 'https://$codespaceName-8080.preview.app.github.dev/api';
    }
    
    return 'http://localhost:8080/api';
  }
}
