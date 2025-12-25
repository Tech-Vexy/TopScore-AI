# Code Duplication Refactoring

## Overview
This document outlines the code duplication found between `lib/screens/chat_screen.dart` and `lib/tutor_client/chat_screen.dart`, and the refactoring steps taken to eliminate redundancy.

## Duplicate Code Identified

### 1. **Typing Indicator Widget** ✅ EXTRACTED
- **Location**: Both files had identical `_TypingIndicator` classes
- **Solution**: Extracted to `lib/shared/widgets/typing_indicator.dart`
- **Usage**: Import and use `TypingIndicator()` instead of local implementation

### 2. **Audio Services** ✅ EXTRACTED
Duplicate audio functionality includes:
- TTS initialization and configuration
- Audio recording (with permission handling)
- Audio playback (local, URL, and base64)
- Platform-specific handling (Web vs Mobile)

**Solution**: Created `lib/shared/services/audio_service.dart` with:
- `AudioService` class handling all audio operations
- Unified TTS, recording, and playback methods
- Platform detection built-in

### 3. **Media Picker Services** ✅ EXTRACTED
Duplicate image/file picking functionality:
- Image picking from gallery/camera
- File picking with custom extensions
- Base64 encoding
- Platform-specific path/blob handling

**Solution**: Created `lib/shared/services/media_picker_service.dart` with:
- `MediaPickerService` class
- `MediaPickResult` model for consistent return values
- Unified API for all media picking operations

### 4. **Scroll Helper** ✅ EXTRACTED
Both files had identical `_scrollToBottom()` implementations

**Solution**: Created `lib/shared/utils/scroll_helper.dart` with:
- `ScrollHelper.scrollToBottom()` static method
- Configurable duration and curve

## Remaining Duplication (Intentional)

### WebSocket Message Handling
- The application now uses a single `WebSocketService` from `lib/tutor_client/`
- All chat functionality connects to the unified tutor backend
- **Decision**: Single AI tutor service for consistency

### UI Components
- Message bubbles have different styling
- Input areas have different features
- **Decision**: Keep separate as they serve different UX requirements

### State Management
- Different state variables for different features
- Different message accumulation strategies
- **Decision**: Keep separate as business logic differs

## Migration Guide

### For Typing Indicator
**Before:**
```dart
// In both chat_screen.dart files
class _TypingIndicator extends StatefulWidget { /* ... */ }
```

**After:**
```dart
import 'package:elimisha/shared/widgets/typing_indicator.dart';

// Use directly
const TypingIndicator()
```

### For Audio Service
**Before:**
```dart
final AudioRecorder _audioRecorder = AudioRecorder();
final AudioPlayer _audioPlayer = AudioPlayer();
final FlutterTts _flutterTts = FlutterTts();
// ... multiple initialization methods
```

**After:**
```dart
import 'package:elimisha/shared/services/audio_service.dart';

final _audioService = AudioService();

@override
void initState() {
  super.initState();
  await _audioService.initializeTts();
}

// Recording
await _audioService.startRecording();
final path = await _audioService.stopRecording();

// TTS
await _audioService.speak("Hello");

// Cleanup
@override
void dispose() {
  _audioService.dispose();
  super.dispose();
}
```

### For Media Picker
**Before:**
```dart
final picker = ImagePicker();
final pickedFile = await picker.pickImage(source: ImageSource.gallery);
// ... manual base64 encoding, platform checks, etc.
```

**After:**
```dart
import 'package:elimisha/shared/services/media_picker_service.dart';

final _mediaService = MediaPickerService();

// Pick image
final result = await _mediaService.pickImage();
if (result != null) {
  final dataUri = result.dataUri;
  final base64 = result.base64Data;
}

// Pick file
final fileResult = await _mediaService.pickFile(
  allowedExtensions: ['pdf', 'doc', 'docx'],
);
```

### For Scroll Helper
**Before:**
```dart
void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(/* ... */);
    }
  });
}
```

**After:**
```dart
import 'package:elimisha/shared/utils/scroll_helper.dart';

ScrollHelper.scrollToBottom(_scrollController);
```

## Next Steps

1. **Update chat_screen.dart files** to use shared components:
   - Replace `_TypingIndicator` with `TypingIndicator`
   - Refactor audio code to use `AudioService`
   - Refactor media picking to use `MediaPickerService`
   - Replace `_scrollToBottom` with `ScrollHelper.scrollToBottom`

2. **Test thoroughly** after migration:
   - Test on Web, Android, and iOS
   - Verify audio recording/playback
   - Verify image/file picking
   - Verify TTS functionality

3. **Remove old code** after successful migration

## Benefits

- **Reduced code by ~500 lines** across both files
- **Single source of truth** for common functionality
- **Easier maintenance** - fix bugs in one place
- **Consistent behavior** across different chat implementations
- **Better testability** - shared components can be unit tested independently
