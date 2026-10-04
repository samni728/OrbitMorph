import Darwin
import Foundation

public enum OutputNamer {
    private static func stem(for source: URL) -> String {
        source.lastPathComponent.lowercased().hasSuffix(".tar.gz")
            ? String(source.lastPathComponent.dropLast(".tar.gz".count))
            : source.deletingPathExtension().lastPathComponent
    }

    public static func outputURL(
        for source: URL,
        target: FormatID,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        let stem = stem(for: source)
        let ext = target.fileExtension
        let direct = directory.appendingPathComponent(stem).appendingPathExtension(ext)
        if !fileManager.fileExists(atPath: direct.path) { return direct }

        let converted = directory.appendingPathComponent("\(stem)-converted").appendingPathExtension(ext)
        if !fileManager.fileExists(atPath: converted.path) { return converted }

        var index = 2
        while true {
            let candidate = directory.appendingPathComponent("\(stem)-converted-\(index)").appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    public static func makeTemporaryOutput(for target: FormatID, in directory: URL) -> URL {
        directory.appendingPathComponent(".OrbitMorph-\(UUID().uuidString)").appendingPathExtension(target.fileExtension)
    }

    /// Uses an exclusive rename when supported by the destination filesystem.
    /// The copy fallback still reserves the final name with O_EXCL, so it cannot replace another file.
    public static func commitTemporaryOutput(
        _ temporary: URL,
        for source: URL,
        target: FormatID,
        in directory: URL
    ) throws -> URL {
        let stem = stem(for: source)
        var index = 0
        while true {
            let suffix = index == 0 ? "" : index == 1 ? "-converted" : "-converted-\(index)"
            let destination = directory.appendingPathComponent("\(stem)\(suffix)").appendingPathExtension(target.fileExtension)
            if Darwin.renameatx_np(AT_FDCWD, temporary.path, AT_FDCWD, destination.path, UInt32(RENAME_EXCL)) == 0 {
                return destination
            }
            let failure = errno
            if failure == EEXIST {
                index += 1
                continue
            }
            if failure == ENOTSUP || failure == EOPNOTSUPP || failure == EINVAL || failure == ENOSYS {
                if try exclusiveCopy(temporary, to: destination) { return destination }
                index += 1
                continue
            }
            throw posixError(failure, path: destination.path)
        }
    }

    private static func exclusiveCopy(_ source: URL, to destination: URL) throws -> Bool {
        let destinationFD = Darwin.open(destination.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o644))
        if destinationFD < 0 {
            if errno == EEXIST { return false }
            throw posixError(errno, path: destination.path)
        }
        var identity = stat()
        _ = Darwin.fstat(destinationFD, &identity)
        let sourceFD = Darwin.open(source.path, O_RDONLY)
        do {
            if sourceFD < 0 { throw posixError(errno, path: source.path) }
            defer { _ = Darwin.close(sourceFD) }
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while true {
                let count = buffer.withUnsafeMutableBytes { Darwin.read(sourceFD, $0.baseAddress, $0.count) }
                if count == 0 { break }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw posixError(errno, path: source.path)
                }
                var offset = 0
                while offset < count {
                    let written = buffer.withUnsafeBytes { bytes in
                        Darwin.write(destinationFD, bytes.baseAddress!.advanced(by: offset), count - offset)
                    }
                    if written < 0 {
                        if errno == EINTR { continue }
                        throw posixError(errno, path: destination.path)
                    }
                    offset += written
                }
            }
            if Darwin.fsync(destinationFD) != 0 { throw posixError(errno, path: destination.path) }
            _ = Darwin.close(destinationFD)
            try? FileManager.default.removeItem(at: source)
            return true
        } catch {
            _ = Darwin.close(destinationFD)
            var current = stat()
            if Darwin.lstat(destination.path, &current) == 0,
               current.st_dev == identity.st_dev, current.st_ino == identity.st_ino {
                _ = Darwin.unlink(destination.path)
            }
            throw error
        }
    }

    private static func posixError(_ code: Int32, path: String) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: path])
    }
}
