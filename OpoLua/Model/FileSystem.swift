// Copyright (c) 2021 Jason Morley, Tom Sutcliffe
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

    func hostUrl(for path: String) -> URL?
    func guestPath(for url: URL) -> String?

}

extension FileSystem {

    func perform(_ operation: Fs.Operation) -> Fs.Result {
        guard let nativePath = hostUrl(for: operation.path) else {
            return .err(.notReady)
        }
        let path = nativePath.path
        let fileManager = FileManager.default
        switch operation.type {
        case .exists:
            let exists = fileManager.fileExists(atPath: path)
            return .err(exists ? .alreadyExists : .notFound)
        case .isdir:
            let exists = fileManager.directoryExists(atPath: path)
            return .err(exists ? .alreadyExists : .notFound)
        case .delete:
            /*
             Usage: DELETE filename$ Deletes any type of file.
               Series 5: You can use wildcards for example,to delete all the files in D:\OPL
                         DELETE “D:\OPL\*”
               Series 3: You can use wildcards for example, to delete all the OPL files in B:\OPL
                         DELETE “B:\OPL\*.OPL”
             The file type extensions are listed in the User Guide. See also RMDIR.
             */
            // TODO: Support wildcard deletion.
            // TODO: Check to see whether directory deletion is permitted.
            // TODO: Return the correct errors.
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
                return .err(.alreadyExists)
            }
            do {
                try fileManager.removeItem(atPath: path)
                return .err(.none)
            } catch {
                return .err(.notReady)
            }
        case .mkdir:
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
            /*
             Usage: RMDIR str$
             Removes the directory given by str$. You can only remove empty directories.
             */
            // TODO: Double check whether non-directory deletion is permitted.
            // TODO: Return the correct errors.
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue {
                return .err(.alreadyExists)
            }
            do {
                try fileManager.removeItem(atPath: path)
            } catch {
                return .err(.notReady)
            }
        case .write(let data):
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
        }
        return .err(.notReady)
    }
}
