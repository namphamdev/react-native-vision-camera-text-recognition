# @solutionsmedias360/react-native-vision-camera-text-recognition

> ⚠️ This is a **fork** of [`gev2002/react-native-vision-camera-text-recognition`](https://github.com/gev2002/react-native-vision-camera-text-recognition) with a patch for Android build failures introduced in React Native 0.77+.

---

## Why this fork?

Starting from **React Native 0.77**, the original package fails to compile on Android due to changes in the Android Gradle and Kotlin toolchain compatibility.

This fork applies the fix proposed in the following upstream PR, which has not yet been merged:

- ✅ PR: [Fix Kotlin incompatibility for RN 0.77+](https://github.com/gev2002/react-native-vision-camera-text-recognition/pull/27)
- 🐛 Related Issue: [#25 - Android build fails on RN 0.77](https://github.com/gev2002/react-native-vision-camera-text-recognition/issues/25)

### Changes in this fork:

- Applied the Kotlin compatibility fix for RN 0.77+ (based on the above PR)
- Added MLX Embedding module for on-device text embeddings (iOS only)

---

## Embedding Module (iOS only)

This fork includes `VisionCameraEmbedding`, a native module for generating text embeddings on-device using MLX and the Nomic Text v1.5 model.

### Setup

1. Install the package:

```bash
npm install @solutionsmedias360/react-native-vision-camera-text-recognition
```

2. Add Swift Package dependencies in Xcode:
   - Open your iOS project in Xcode
   - Go to **File > Add Package Dependencies**
   - Add these packages:
     - `https://github.com/ml-explore/mlx-swift`
     - `https://github.com/ml-explore/mlx-swift-examples` (contains MLXEmbedders)

3. Run pod install:

```bash
cd ios && pod install
```

### Usage

```typescript
import { NativeModules } from 'react-native';

const { VisionCameraEmbedding } = NativeModules;

// Load the embedding model (downloads on first use)
await VisionCameraEmbedding.loadModel();

// Check status
const status = await VisionCameraEmbedding.getStatus();
// { isLoaded, isLoading, isDownloading, downloadProgress, loadingProgress, modelSize, formattedModelSize }

// Generate embedding for single text
const embedding: number[] = await VisionCameraEmbedding.embed('Hello world');

// Generate embeddings for multiple texts (batched for efficiency)
const embeddings: number[][] = await VisionCameraEmbedding.embedBatch(
  ['Hello', 'World', 'Test'],
  4 // batch size
);

// Generate embeddings sequentially (lower memory usage)
const embeddings: number[][] = await VisionCameraEmbedding.embedSequentially([
  'Hello',
  'World',
]);

// Unload model to free memory
await VisionCameraEmbedding.unloadModel();
```

### API

| Method                         | Parameters                           | Returns                                             | Description                        |
| ------------------------------ | ------------------------------------ | --------------------------------------------------- | ---------------------------------- |
| `loadModel()`                  | -                                    | `Promise<{success, modelSize, formattedModelSize}>` | Load the Nomic Text v1.5 model     |
| `unloadModel()`                | -                                    | `Promise<{success}>`                                | Unload model and free GPU memory   |
| `getStatus()`                  | -                                    | `Promise<Status>`                                   | Get current loading/model status   |
| `embed(text)`                  | `text: string`                       | `Promise<number[]>`                                 | Generate embedding for single text |
| `embedBatch(texts, batchSize)` | `texts: string[], batchSize: number` | `Promise<number[][]>`                               | Generate embeddings in batches     |
| `embedSequentially(texts)`     | `texts: string[]`                    | `Promise<number[][]>`                               | Generate embeddings one by one     |

### Status Object

```typescript
interface Status {
  isLoaded: boolean;
  isLoading: boolean;
  isDownloading: boolean;
  downloadProgress: number; // 0.0 - 1.0
  loadingProgress: string;
  modelSize: number; // bytes
  formattedModelSize: string; // e.g. "256 MB"
}
```

### Requirements

- iOS 15.0+
- Apple Silicon Mac or iPhone with Neural Engine
- ~500MB storage for model download
