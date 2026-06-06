# app

A new Flutter project.

## WhatsApp Animated Stickers Integration Notes

To support animated stickers, local modifications were made to the `whatsapp_stickers_injector-1.1.3` package in the `.pub-cache`. If you clean your pub cache or build on a different machine, these changes will need to be applied again.

Here is a summary of the edits required in the package:

### 1. Dart API Changes (`lib/whatsapp_stickers.dart`)
- Added `final bool animatedStickerPack;` to `WhatsappStickers` class.
- Added `this.animatedStickerPack = false` to the constructor.
- Added `payload['animatedStickerPack'] = animatedStickerPack;` inside the `sendToWhatsApp()` method.

### 2. Android Config Changes (`android/.../ConfigFileManager.java`)
- Retrieved `animatedStickerPack` argument in `fromMethodCall` and called `newStickerPack.setAnimatedStickerPack(animatedStickerPack)`.
- Added `obj.put("animated_sticker_pack", s.animatedStickerPack);` inside `updateConfigFile` method.

### 3. Android Parser Changes (`android/.../ContentFileParser.java`)
- Read `"animated_sticker_pack"` from JSON configuration:
  ```java
  case "animated_sticker_pack":
      animatedStickerPack = reader.nextBoolean();
      break;
  ```
- Called `stickerPack.setAnimatedStickerPack(animatedStickerPack);` when returning the `StickerPack` instance.

### 4. Android Provider Changes (`android/.../StickerContentProvider.java`)
- Declared: `public static final String ANIMATED_STICKER_PACK = "animated_sticker_pack";`
- Appended `ANIMATED_STICKER_PACK` column to the matrix cursor projection list in `getStickerPackInfo`.
- Appended `builder.add(stickerPack.animatedStickerPack ? 1 : 0);` to populate the cursor row.

### 5. Android Validation Changes (`android/.../StickerPackValidator.java`)
- Increased `STICKER_FILE_SIZE_LIMIT_KB` from `100` to `500` to allow larger animated WebP sticker files.

---

## Publishing Your Own Forked Package (Permanent Fix)

To make these changes permanent and avoid losing them when you clean your pub cache, you can publish your own fork:

1. **Fork the Original Repository:**
   Go to the package's source code repository and fork it on GitHub.
2. **Rename the Package:**
   In the forked package's `pubspec.yaml`, rename it to something unique (e.g., `whatsapp_stickers_injector_animated`).
3. **Commit the Changes:**
   Commit all 5 changes detailed above to your fork.
4. **Publish to Pub.dev:**
   Run `flutter pub publish` in your forked package root to upload it under your pub.dev publisher account.
5. **Use it in your App:**
   In your app's `pubspec.yaml`, replace the dependency:
   ```yaml
   dependencies:
     whatsapp_stickers_injector_animated: ^1.0.0 # Or your published version
   ```

Alternatively, you can save the modified files locally in a directory (like `packages/whatsapp_stickers_injector`) and add it as a path dependency in your `pubspec.yaml`:
```yaml
dependencies:
  whatsapp_stickers_injector:
    path: ./packages/whatsapp_stickers_injector
```

---

## Future iOS Compatibility Steps

If you need to support iOS animated stickers in the future, apply these changes to the package's iOS directory:

1. **Increase File Size Limit (`ios/Classes/Limits.swift`):**
   Increase `MaxStickerFileSize` from `100 * 1024` to `500 * 1024` to match WhatsApp's 500 KB limit for animations.
2. **Add Animated Flag to Model (`ios/Classes/StickerPack.swift`):**
   - Add `let animatedStickerPack: Bool` property to `StickerPack` class.
   - Update its initializer to accept `animatedStickerPack` from the plugin method call.
   - In `sendToWhatsApp()`, add the key-value pair to the dictionary:
     ```swift
     json["animated_sticker_pack"] = self.animatedStickerPack
     ```
3. **Update Plugin Bridge (`ios/Classes/SwiftWhatsappStickersPlugin.swift`):**
   Extract `animatedStickerPack` from the Flutter `MethodCall` arguments, and pass it when constructing the `StickerPack` object.

---

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
