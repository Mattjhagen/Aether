import Foundation
import zlib

public struct ZipFileEntry {
    public let fileName: String
    public let compressionMethod: UInt16
    public let compressedSize: Int
    public let uncompressedSize: Int
    public let localHeaderOffset: Int
}

public class ZipArchive {
    private let data: Data
    private var entries: [String: ZipFileEntry] = [:]
    
    public init?(data: Data) {
        self.data = data
        guard parseCentralDirectory() else { return nil }
    }
    
    public init?(url: URL) {
        do {
            self.data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard parseCentralDirectory() else { return nil }
        } catch {
            print("Failed to read zip data: \(error)")
            return nil
        }
    }
    
    public var fileNames: [String] {
        return Array(entries.keys)
    }
    
    public func extract(fileName: String) -> Data? {
        guard let entry = entries[fileName] else { return nil }
        
        let offset = entry.localHeaderOffset
        guard offset + 30 <= data.count else { return nil }
        
        // Read Local File Header
        let signature = readUInt32(offset: offset)
        guard signature == 0x04034b50 else {
            print("Invalid local header signature for \(fileName) at offset \(offset)")
            return nil
        }
        
        let nameLen = Int(readUInt16(offset: offset + 26))
        let extraLen = Int(readUInt16(offset: offset + 28))
        
        let dataOffset = offset + 30 + nameLen + extraLen
        guard dataOffset + entry.compressedSize <= data.count else { return nil }
        
        let compressedData = data.subdata(in: dataOffset..<(dataOffset + entry.compressedSize))
        
        if entry.compressionMethod == 0 {
            // Stored (no compression)
            return compressedData
        } else if entry.compressionMethod == 8 {
            // Deflated
            return decompressDeflate(compressedData: compressedData, uncompressedSize: entry.uncompressedSize)
        } else {
            print("Unsupported compression method \(entry.compressionMethod) for \(fileName)")
            return nil
        }
    }
    
    private func parseCentralDirectory() -> Bool {
        guard let eocdOffset = findEOCDOffset() else {
            print("Could not find End of Central Directory (EOCD)")
            return false
        }
        
        let cdEntriesCount = Int(readUInt16(offset: eocdOffset + 10)) // total number of central dir entries
        let cdSize = Int(readUInt32(offset: eocdOffset + 12))
        let cdOffset = Int(readUInt32(offset: eocdOffset + 16))
        
        var currentOffset = cdOffset
        guard currentOffset + cdSize <= data.count else {
            print("Central Directory offset/size extends beyond data bounds")
            return false
        }
        
        for _ in 0..<cdEntriesCount {
            guard currentOffset + 46 <= data.count else { break }
            
            let signature = readUInt32(offset: currentOffset)
            guard signature == 0x02014b50 else {
                print("Invalid Central Directory header signature at offset \(currentOffset)")
                return false
            }
            
            let compressionMethod = readUInt16(offset: currentOffset + 10)
            let compressedSize = Int(readUInt32(offset: currentOffset + 20))
            let uncompressedSize = Int(readUInt32(offset: currentOffset + 24))
            let nameLen = Int(readUInt16(offset: currentOffset + 28))
            let extraLen = Int(readUInt16(offset: currentOffset + 30))
            let commentLen = Int(readUInt16(offset: currentOffset + 32))
            let localHeaderOffset = Int(readUInt32(offset: currentOffset + 42))
            
            guard currentOffset + 46 + nameLen <= data.count else { return false }
            
            let nameData = data.subdata(in: (currentOffset + 46)..<(currentOffset + 46 + nameLen))
            guard let name = String(data: nameData, encoding: .utf8) else { continue }
            
            let entry = ZipFileEntry(
                fileName: name,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localHeaderOffset
            )
            entries[name] = entry
            
            currentOffset += 46 + nameLen + extraLen + commentLen
        }
        
        return true
    }
    
    private func findEOCDOffset() -> Int? {
        let maxSearchLength = min(data.count, 65536 + 22)
        let end = data.count
        let start = max(0, end - maxSearchLength)
        
        // Search backwards for signature 0x06054b50
        for offset in stride(from: end - 22, to: start - 1, by: -1) {
            if readUInt32(offset: offset) == 0x06054b50 {
                return offset
            }
        }
        return nil
    }
    
    private func decompressDeflate(compressedData: Data, uncompressedSize: Int) -> Data? {
        guard uncompressedSize > 0 else { return Data() }
        
        var decompressedData = Data(count: uncompressedSize)
        
        let success = decompressedData.withUnsafeMutableBytes { (destBuffer: UnsafeMutableRawBufferPointer) -> Bool in
            guard let destBytes = destBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return false }
            
            return compressedData.withUnsafeBytes { (srcBuffer: UnsafeRawBufferPointer) -> Bool in
                guard let srcBytes = srcBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return false }
                
                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBytes)
                stream.avail_in = uInt(compressedData.count)
                stream.next_out = destBytes
                stream.avail_out = uInt(uncompressedSize)
                
                // -15 for windowBits specifies raw deflate format (no zlib or gzip headers)
                let initStatus = inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard initStatus == Z_OK else {
                    print("zlib inflateInit2 failed: \(initStatus)")
                    return false
                }
                
                defer {
                    inflateEnd(&stream)
                }
                
                let status = inflate(&stream, Z_FINISH)
                guard status == Z_STREAM_END else {
                    print("zlib inflate failed: \(status)")
                    return false
                }
                
                return true
            }
        }
        
        return success ? decompressedData : nil
    }
    
    // Helpers to read little endian values
    private func readUInt32(offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt32.self).littleEndian
        }
    }
    
    private func readUInt16(offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt16.self).littleEndian
        }
    }
}
