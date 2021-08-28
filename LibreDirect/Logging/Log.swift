//
//  Log.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 28.07.21.
//

import Foundation
import os.log

public extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    //static let sensorLink = OSLog(subsystem: subsystem, category: "SensorLink")
    //static let sensor = OSLog(subsystem: subsystem, category: "Sensor")
    //static let sensorManager = OSLog(subsystem: subsystem, category: "SensorManager")
    //static let ui = OSLog(subsystem: subsystem, category: "UI")
}

public enum Log {
    private static let fileLogger = FileLogger()

    public static func debug(_ message: String, log: OSLog = .default, file: String = #fileID, line: Int = #line, function: String = #function) {
        Self.log(message: message, type: .debug, log: log, error: nil, file: file, line: line, function: function)
    }

    public static func info(_ message: String, log: OSLog = .default, file: String = #fileID, line: Int = #line, function: String = #function) {
        Self.log(message: message, type: .info, log: log, error: nil, file: file, line: line, function: function)
    }

    public static func warning(_ message: String, log: OSLog = .default, file: String = #fileID, line: Int = #line, function: String = #function) {
        Self.log(message: message, type: .default, log: log, error: nil, file: file, line: line, function: function)
    }

    public static func error(_ message: String, log: OSLog = .default, error: Error? = nil, file: String = #fileID, line: Int = #line, function: String = #function) {
        Self.log(message: message, type: .error, log: log, error: error, file: file, line: line, function: function)
    }
    
    public static func clear() {
        fileLogger.deleteLogs()
    }

    private static func log(message: String, type: OSLogType, log: OSLog, error: Error?, file: String, line: Int, function: String) {
        // Console logging
        let meta: String = "[\(file):\(line)]" // [\(function)]
        // obviously we have to disable swiftline here:
        // swiftlint:disable:next no_direct_oslog
        os_log("%{public}@ %{public}@", log: log, type: type, meta, message)

        // Save logs to File. This is used for viewing and exporting logs from debug menu.
        fileLogger.log(message, logType: type, file: file, line: line, function: function)
    }
}

extension OSLogType {
    var title: String {
        switch self {
        case .error:
            return "Error"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .default:
            return "Warning"
        default:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .error:
            return "❌"
        case .debug:
            return "🛠"
        case .info:
            return "ℹ️"
        case .default:
            return "⚠️"
        default:
            return ""
        }
    }

    var logFilePath: String {
        return "LibreDirectClient__\(self.title).log"
    }
}

struct FileLogger {
    enum Error: Swift.Error {
        case streamerInitError
    }

    // MARK: - Internal
    /// The directory where all logs are stored
    let logFileBaseURL: URL = {
        let fileManager = FileManager.default
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs")
    }()

    /// Path to a common log file for all log types combined
    let allLogsFileURL: URL = {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs")
        return baseURL.appendingPathComponent("LibreDirectClient__AllLogs.log")
    }()

    func log(_ logMessage: String, logType: OSLogType, file: String? = nil, line: Int? = nil, function: String? = nil) {
        var meta: String = ""
        if let file = file, let line = line, let function = function {
            meta = "[\(file):\(line)] [\(function)]\n"
        }
        let prefixedLogMessage = "\(logType.icon) \(logDateFormatter.string(from: Date()))\n\(meta)\(logMessage)\n\n"

        guard let fileHandle = makeWriteFileHandle(with: logType),
            let logMessageData = prefixedLogMessage.data(using: encoding) else {
            return
        }
        defer {
            fileHandle.closeFile()
        }

        fileHandle.seekToEndOfFile()
        fileHandle.write(logMessageData)

        guard let allLogsFileHandle = makeWriteFileHandle(with: allLogsFileURL) else {
            return
        }
        allLogsFileHandle.seekToEndOfFile()
        allLogsFileHandle.write(logMessageData)
    }


    /// `StreamReader` for a given log type
    /// - Parameter logType: the log type to read
    /// - Throws: `FileLogger.Error.streamerInitError` if Reader initialization fails
    /// - Returns: a `StreamReader`
    func logReader(for logType: OSLogType) throws -> StreamReader {
        let fileURL = logFileBaseURL.appendingPathComponent(logType.logFilePath)
        try createLogFile(for: fileURL)
        guard let reader = StreamReader(at: fileURL) else {
            throw Error.streamerInitError
        }
        return reader
    }

    /// `StreamReader` for all log types combined
    /// - Throws: `FileLogger.Error.streamerInitError` if Reader initialization fails
    /// - Returns: a `StreamReader`
    func logReader() throws -> StreamReader {
        let url = allLogsFileURL
        try createLogFile(for: url)
        guard let reader = StreamReader(at: url) else {
            throw Error.streamerInitError
        }
        return reader
    }

    func deleteLogs() {
        do {
            try FileManager.default.removeItem(at: logFileBaseURL)
        } catch {
            Log.error("Can't remove logs at \(logFileBaseURL)", log: .default, error: error)
        }
    }

    // MARK: - Private
    private let encoding: String.Encoding = .utf8
    private let logDateFormatter = ISO8601DateFormatter()

    private func createLogFile(for url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: logFileBaseURL, withIntermediateDirectories: true)
            fileManager.createFile(atPath: url.path, contents: Data())
        }
    }

    private func makeWriteFileHandle(with logType: OSLogType) -> FileHandle? {
        let logFileURL = logFileBaseURL.appendingPathComponent("LibreDirectClient__\(logType.title).log")
        return makeWriteFileHandle(with: logFileURL)
    }

    private func makeWriteFileHandle(with url: URL) -> FileHandle? {
        do {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: logFileBaseURL, withIntermediateDirectories: true)
                fileManager.createFile(atPath: url.path, contents: nil)
            }

            let fileHandle = try? FileHandle(forWritingTo: url)
            return fileHandle
        } catch {
            Log.error("File handle error", log: .default, error: error)
            return nil
        }
    }

    private func makeReadFileHandle(with logType: OSLogType) -> FileHandle? {
        let logFileURL = logFileBaseURL.appendingPathComponent("LibreDirectClient__\(logType.title).log")
        return makeReadFileHandle(with: logFileURL)
    }

    private func makeReadFileHandle(with url: URL) -> FileHandle? {
        do {
            return try FileHandle(forReadingFrom: url)
        } catch {
            Log.error("File handle error", log: .default, error: error)
            return nil
        }
    }
}
