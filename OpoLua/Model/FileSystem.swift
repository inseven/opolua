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

import Foundation

protocol FileSystem {

    func prepare() throws
    func set(sharedDrive: String, url: URL, readonly: Bool)
    func hostUrl(for path: String) -> (URL, Bool)? // The bool is whether this is a readonly location
    func guestPath(for url: URL) -> String?

}

extension FileSystem {

    func perform(_ operation: Fs.Operation) -> Fs.Result {
        guard let (nativePath, readonly) = hostUrl(for: operation.path) else {
            return .err(.notReady)
        }
        if readonly && !operation.isReadonlyOperation() {
            return .err(.accessDenied)
        }
        let path = nativePath.path
        let fileManager = FileManager.default
        switch operation.type {
        case .exists:
            let exists = fileManager.fileExists(atPath: path)
            return .err(exists ? .none : .notFound)
        case .stat:
            if let attribs = try? fileManager.attributesOfItem(atPath: path) as NSDictionary {
                let mod = attribs.fileModificationDate() ?? Date(timeIntervalSince1970: 0)
                let size = attribs.fileSize()
                return .stat(Fs.Stat(size: size, lastModified: mod))
            } else {
                return .err(.notFound)
            }
        case .isdir:
            let exists = fileManager.directoryExists(atPath: path)
            return .err(exists ? .none : .notFound)
        case .delete:
            print("DELETE '\(operation.path)'")
            // Note, should not support wildcards or deleting directories
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // The logic here seems to be "there isn't a *file* with this name"
                    return .err(.notFound)
                }
            } else {
                return .err(.notFound)
            }
            do {
                try fileManager.removeItem(atPath: path)
                return .err(.none)
            } catch {
                return .err(.notReady)
            }
        case .mkdir:
            print("MKDIR '\(operation.path)'")
            /*
             Usage: MKDIR name$ Creates a new folder/directory.
             Series 5: For example, MKDIR “C:\MINE\TEMP” creates a C:\MINE\TEMP folder, also creating C:\MINE if it is
                       not already there.
             Series 3: For example, MKDIR “M:\MINE\TEMP” creates a M:\MINE\TEMP directory, also creating M:\MINE if it
                       is not already there.
             */
            // TODO: Return the correct errors.
            if fileManager.fileExists(atPath: path, isDirectory: nil) {
                return .err(.alreadyExists)
            }
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
                return .err(.none)
            } catch {
                return .err(.notReady)
            }
        case .rmdir:
            print("RMDIR '\(operation.path)'")
            /*
             Usage: RMDIR str$
             Removes the directory given by str$. You can only remove empty directories.
             */
            var isDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                return .err(.notFound)
            }
            if !isDirectory.boolValue {
                return .err(.pathNotFound)
            }
            do {
                if try fileManager.contentsOfDirectory(atPath: path).count > 0 {
                    return .err(.inUse)
                }
                try fileManager.removeItem(atPath: path)
            } catch {
                return .err(.notReady)
            }
        case .write(let data):
            print("fsop write '\(operation.path)'")
            // OPL seems to ensure the directory exists on our behalf?
            // TODO: Ensure this is contained within our root.
            // TODO: We need to handle case coersion when creating our directories.
            let directory = path.deletingLastPathComponent
            if !fileManager.fileExists(atPath: directory, isDirectory: nil) {
                print("Attempting to write a file without creating the intermediate directories (\(directory))")
                do {
                    print("Attempting to create directories on behalf of the app...")
                    try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create intermediate path with error \(error).")
                    return .err(.notReady)
                }
            }
            let ok = fileManager.createFile(atPath: path, contents: data)
            return .err(ok ? .none : .notReady)
        case .read:
            if let result = fileManager.contents(atPath: nativePath.path) {
                return .data(result)
            } else if !fileManager.fileExists(atPath: path) {
                return .err(.notFound)
            } else {
                return .err(.notReady)
            }
        case .dir:
            if let names = try? fileManager.contentsOfDirectory(atPath: path) {
                var paths: [String] = []
                for name in names {
                    paths.append(operation.path + name)
                }
                return .strings(paths)
            }
        case .rename(let dest):
            guard let (nativeDestUrl, destReadonly) = hostUrl(for: dest) else {
                return .err(.notReady)
            }
            if destReadonly {
                return .err(.accessDenied)
            }
            let nativeDest = nativeDestUrl.path
            if fileManager.fileExists(atPath: nativeDest) {
                return .err(.alreadyExists)
            } else if !fileManager.fileExists(atPath: path) {
                return .err(.notFound)
            }
            do {
                try fileManager.moveItem(atPath: path, toPath: nativeDest)
                return .err(.none)
            } catch {
                return .err(.notReady)
            }
        }
        return .err(.notReady)
    }
}
