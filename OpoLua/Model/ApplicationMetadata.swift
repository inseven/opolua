// Copyright (c) 2021-2024 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

fileprivate let appInfoCache = FileMetadataCache<ApplicationMetadata>()
fileprivate let fileTypeCache = FileMetadataCache<PsiLuaState.FileType>()

struct ApplicationMetadata {

    let appInfoUrl: URL  // On-disk location of the app info (useful for keying caches)
    let appInfo: PsiLuaState.AppInfo  // Contents of the app info

    var captions: [PsiLuaState.LocalizedString] {
        return appInfo.captions
    }

    var caption: String {
        for language in Locale.preferredLanguages {
            if let caption = captions.first(where: { $0.locale.languageCode == language }) {
                return caption.value
            }
        }
        return captions.first?.value ?? "Unknown"
    }

    var uid3: UInt32 {
        return appInfo.uid3
    }

    var icons: [Graphics.MaskedBitmap] {
        return appInfo.icons
    }

    func icon() -> Icon? {
        guard let appIcon = image(for: .icon) else {
            return nil
        }
        return Icon(grayscaleImage: appIcon, colorImage: appIcon)
    }

    private func image(for size: Graphics.Size) -> UIImage? {
        var bitmap: Graphics.MaskedBitmap? = nil
        for icon in icons {
            guard icon.bitmap.size <= size && (icon.mask == nil || icon.bitmap.size == icon.mask?.size) else {
                continue
            }
            guard let currentBitmap = bitmap else {
                bitmap = icon
                continue
            }
            if icon.bitmap.size > currentBitmap.bitmap.size {
                bitmap = icon
            }
        }
        guard let bitmap = bitmap else {
            return nil
        }
        if let cgImg = bitmap.cgImage {
            return UIImage(cgImage: cgImg)
        }
        return nil
    }

}

fileprivate let applicationMetadataIconCache = FileMetadataCache<Icon>()

extension ApplicationMetadata {

    func cachedIcon() -> Icon? {
        if let icon = applicationMetadataIconCache.metadata(for: appInfoUrl) {
            return icon
        }
        guard let icon = icon() else {
            return nil
        }
        applicationMetadataIconCache.setMetadata(icon, for: appInfoUrl)
        return icon
    }

}
