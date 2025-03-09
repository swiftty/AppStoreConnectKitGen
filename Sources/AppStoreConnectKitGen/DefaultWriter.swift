public import Foundation
public import System

public struct DefaultWriter: AppStoreConnectKitGen.Writer {
    var fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func mkdir(_ path: FilePath, force: Bool) throws {
        func checkNeedsDirectory(_ path: FilePath) throws -> Bool {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: path.string, isDirectory: &isDirectory) {
                return true
            }
            if force, isDirectory.boolValue {
                try fileManager.removeItem(atPath: path.string)
                return true
            }
            return !isDirectory.boolValue
        }

        if try checkNeedsDirectory(path) {
            try fileManager.createDirectory(atPath: path.string, withIntermediateDirectories: true)
        }
    }

    public func write(_ content: String, to path: FilePath) throws {
        try content.write(to: URL(filePath: path)!, atomically: true, encoding: .utf8)
    }
}
