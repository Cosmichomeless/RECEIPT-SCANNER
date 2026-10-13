import Foundation

/// Builds a ZIP file in memory. Entries are stored without compression: receipt images are
/// already JPEG or HEIC, so compressing them again gains nothing.
public enum ZipArchive {
    public struct Entry: Sendable {
        public let name: String
        public let data: Data
        public init(name: String, data: Data) {
            self.name = name
            self.data = data
        }
    }

    public enum ZipError: Error, Equatable {
        /// More than 65,535 entries or more than 4 GB, which this writer does not support.
        case tooLarge
    }

    /// `modified` is stored in MS-DOS format (2-second resolution, years 1980–2107).
    public static func make(_ entries: [Entry], modified: Date = Date(), calendar: Calendar = .current) throws -> Data {
        guard entries.count <= Int(UInt16.max) else { throw ZipError.tooLarge }
        let (dosTime, dosDate) = dosStamp(modified, calendar: calendar)

        var archive = Data()
        var directory = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = CRC32.checksum(entry.data)
            guard entry.data.count < Int(UInt32.max), archive.count < Int(UInt32.max) - 1 << 20,
                  name.count <= Int(UInt16.max)
            else { throw ZipError.tooLarge }
            let offset = UInt32(archive.count)
            let size = UInt32(entry.data.count)
            let utf8Flag: UInt16 = 1 << 11

            // Local file header
            archive.append(le32: 0x0403_4B50)
            archive.append(le16: 20)
            archive.append(le16: utf8Flag)
            archive.append(le16: 0)              // stored
            archive.append(le16: dosTime)
            archive.append(le16: dosDate)
            archive.append(le32: crc)
            archive.append(le32: size)
            archive.append(le32: size)
            archive.append(le16: UInt16(name.count))
            archive.append(le16: 0)
            archive.append(name)
            archive.append(entry.data)

            // Central directory header
            directory.append(le32: 0x0201_4B50)
            directory.append(le16: 20)
            directory.append(le16: 20)
            directory.append(le16: utf8Flag)
            directory.append(le16: 0)
            directory.append(le16: dosTime)
            directory.append(le16: dosDate)
            directory.append(le32: crc)
            directory.append(le32: size)
            directory.append(le32: size)
            directory.append(le16: UInt16(name.count))
            directory.append(le16: 0)            // extra
            directory.append(le16: 0)            // comment
            directory.append(le16: 0)            // disk
            directory.append(le16: 0)            // internal attributes
            directory.append(le32: 0)            // external attributes
            directory.append(le32: offset)
            directory.append(name)
        }

        guard archive.count + directory.count < Int(UInt32.max) - 22 else { throw ZipError.tooLarge }
        let directoryOffset = UInt32(archive.count)
        archive.append(directory)
        archive.append(le32: 0x0605_4B50)        // end of central directory
        archive.append(le16: 0)
        archive.append(le16: 0)
        archive.append(le16: UInt16(entries.count))
        archive.append(le16: UInt16(entries.count))
        archive.append(le32: UInt32(directory.count))
        archive.append(le32: directoryOffset)
        archive.append(le16: 0)
        return archive
    }

    private static func dosStamp(_ date: Date, calendar: Calendar) -> (time: UInt16, date: UInt16) {
        let p = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(max((p.year ?? 1980) - 1980, 0), 127)
        let time = ((p.hour ?? 0) << 11) | ((p.minute ?? 0) << 5) | ((p.second ?? 0) / 2)
        let day = (year << 9) | ((p.month ?? 1) << 5) | (p.day ?? 1)
        return (UInt16(time), UInt16(day))
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func append(le16 value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func append(le32 value: UInt32) {
        append(le16: UInt16(truncatingIfNeeded: value))
        append(le16: UInt16(truncatingIfNeeded: value >> 16))
    }
}
