// This file was autogenerated by some hot garbage in the `uniffi` crate.
// Trust me, you don't want to mess with it!

// swiftlint:disable all
import Foundation

// Depending on the consumer's build setup, the low-level FFI code
// might be in a separate module, or it might be compiled inline into
// this module. This is a bit of light hackery to work with both.
#if canImport(celestia_protoFFI)
import celestia_protoFFI
#endif

fileprivate extension RustBuffer {
    // Allocate a new buffer, copying the contents of a `UInt8` array.
    init(bytes: [UInt8]) {
        let rbuf = bytes.withUnsafeBufferPointer { ptr in
            RustBuffer.from(ptr)
        }
        self.init(capacity: rbuf.capacity, len: rbuf.len, data: rbuf.data)
    }

    static func empty() -> RustBuffer {
        RustBuffer(capacity: 0, len:0, data: nil)
    }

    static func from(_ ptr: UnsafeBufferPointer<UInt8>) -> RustBuffer {
        try! rustCall { ffi_celestia_proto_rustbuffer_from_bytes(ForeignBytes(bufferPointer: ptr), $0) }
    }

    // Frees the buffer in place.
    // The buffer must not be used after this is called.
    func deallocate() {
        try! rustCall { ffi_celestia_proto_rustbuffer_free(self, $0) }
    }
}

fileprivate extension ForeignBytes {
    init(bufferPointer: UnsafeBufferPointer<UInt8>) {
        self.init(len: Int32(bufferPointer.count), data: bufferPointer.baseAddress)
    }
}

// For every type used in the interface, we provide helper methods for conveniently
// lifting and lowering that type from C-compatible data, and for reading and writing
// values of that type in a buffer.

// Helper classes/extensions that don't change.
// Someday, this will be in a library of its own.

fileprivate extension Data {
    init(rustBuffer: RustBuffer) {
        self.init(
            bytesNoCopy: rustBuffer.data!,
            count: Int(rustBuffer.len),
            deallocator: .none
        )
    }
}

// Define reader functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.
//
// With external types, one swift source file needs to be able to call the read
// method on another source file's FfiConverter, but then what visibility
// should Reader have?
// - If Reader is fileprivate, then this means the read() must also
//   be fileprivate, which doesn't work with external types.
// - If Reader is internal/public, we'll get compile errors since both source
//   files will try define the same type.
//
// Instead, the read() method and these helper functions input a tuple of data

fileprivate func createReader(data: Data) -> (data: Data, offset: Data.Index) {
    (data: data, offset: 0)
}

// Reads an integer at the current offset, in big-endian order, and advances
// the offset on success. Throws if reading the integer would move the
// offset past the end of the buffer.
fileprivate func readInt<T: FixedWidthInteger>(_ reader: inout (data: Data, offset: Data.Index)) throws -> T {
    let range = reader.offset..<reader.offset + MemoryLayout<T>.size
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    if T.self == UInt8.self {
        let value = reader.data[reader.offset]
        reader.offset += 1
        return value as! T
    }
    var value: T = 0
    let _ = withUnsafeMutableBytes(of: &value, { reader.data.copyBytes(to: $0, from: range)})
    reader.offset = range.upperBound
    return value.bigEndian
}

// Reads an arbitrary number of bytes, to be used to read
// raw bytes, this is useful when lifting strings
fileprivate func readBytes(_ reader: inout (data: Data, offset: Data.Index), count: Int) throws -> Array<UInt8> {
    let range = reader.offset..<(reader.offset+count)
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    var value = [UInt8](repeating: 0, count: count)
    value.withUnsafeMutableBufferPointer({ buffer in
        reader.data.copyBytes(to: buffer, from: range)
    })
    reader.offset = range.upperBound
    return value
}

// Reads a float at the current offset.
fileprivate func readFloat(_ reader: inout (data: Data, offset: Data.Index)) throws -> Float {
    return Float(bitPattern: try readInt(&reader))
}

// Reads a float at the current offset.
fileprivate func readDouble(_ reader: inout (data: Data, offset: Data.Index)) throws -> Double {
    return Double(bitPattern: try readInt(&reader))
}

// Indicates if the offset has reached the end of the buffer.
fileprivate func hasRemaining(_ reader: (data: Data, offset: Data.Index)) -> Bool {
    return reader.offset < reader.data.count
}

// Define writer functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.  See the above discussion on Readers for details.

fileprivate func createWriter() -> [UInt8] {
    return []
}

fileprivate func writeBytes<S>(_ writer: inout [UInt8], _ byteArr: S) where S: Sequence, S.Element == UInt8 {
    writer.append(contentsOf: byteArr)
}

// Writes an integer in big-endian order.
//
// Warning: make sure what you are trying to write
// is in the correct type!
fileprivate func writeInt<T: FixedWidthInteger>(_ writer: inout [UInt8], _ value: T) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { writer.append(contentsOf: $0) }
}

fileprivate func writeFloat(_ writer: inout [UInt8], _ value: Float) {
    writeInt(&writer, value.bitPattern)
}

fileprivate func writeDouble(_ writer: inout [UInt8], _ value: Double) {
    writeInt(&writer, value.bitPattern)
}

// Protocol for types that transfer other types across the FFI. This is
// analogous to the Rust trait of the same name.
fileprivate protocol FfiConverter {
    associatedtype FfiType
    associatedtype SwiftType

    static func lift(_ value: FfiType) throws -> SwiftType
    static func lower(_ value: SwiftType) -> FfiType
    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType
    static func write(_ value: SwiftType, into buf: inout [UInt8])
}

// Types conforming to `Primitive` pass themselves directly over the FFI.
fileprivate protocol FfiConverterPrimitive: FfiConverter where FfiType == SwiftType { }

extension FfiConverterPrimitive {
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lift(_ value: FfiType) throws -> SwiftType {
        return value
    }

#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lower(_ value: SwiftType) -> FfiType {
        return value
    }
}

// Types conforming to `FfiConverterRustBuffer` lift and lower into a `RustBuffer`.
// Used for complex types where it's hard to write a custom lift/lower.
fileprivate protocol FfiConverterRustBuffer: FfiConverter where FfiType == RustBuffer {}

extension FfiConverterRustBuffer {
#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lift(_ buf: RustBuffer) throws -> SwiftType {
        var reader = createReader(data: Data(rustBuffer: buf))
        let value = try read(from: &reader)
        if hasRemaining(reader) {
            throw UniffiInternalError.incompleteData
        }
        buf.deallocate()
        return value
    }

#if swift(>=5.8)
    @_documentation(visibility: private)
#endif
    public static func lower(_ value: SwiftType) -> RustBuffer {
          var writer = createWriter()
          write(value, into: &writer)
          return RustBuffer(bytes: writer)
    }
}
// An error type for FFI errors. These errors occur at the UniFFI level, not
// the library level.
fileprivate enum UniffiInternalError: LocalizedError {
    case bufferOverflow
    case incompleteData
    case unexpectedOptionalTag
    case unexpectedEnumCase
    case unexpectedNullPointer
    case unexpectedRustCallStatusCode
    case unexpectedRustCallError
    case unexpectedStaleHandle
    case rustPanic(_ message: String)

    public var errorDescription: String? {
        switch self {
        case .bufferOverflow: return "Reading the requested value would read past the end of the buffer"
        case .incompleteData: return "The buffer still has data after lifting its containing value"
        case .unexpectedOptionalTag: return "Unexpected optional tag; should be 0 or 1"
        case .unexpectedEnumCase: return "Raw enum value doesn't match any cases"
        case .unexpectedNullPointer: return "Raw pointer value was null"
        case .unexpectedRustCallStatusCode: return "Unexpected RustCallStatus code"
        case .unexpectedRustCallError: return "CALL_ERROR but no errorClass specified"
        case .unexpectedStaleHandle: return "The object in the handle map has been dropped already"
        case let .rustPanic(message): return message
        }
    }
}

fileprivate extension NSLock {
    func withLock<T>(f: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try f()
    }
}

fileprivate let CALL_SUCCESS: Int8 = 0
fileprivate let CALL_ERROR: Int8 = 1
fileprivate let CALL_UNEXPECTED_ERROR: Int8 = 2
fileprivate let CALL_CANCELLED: Int8 = 3

fileprivate extension RustCallStatus {
    init() {
        self.init(
            code: CALL_SUCCESS,
            errorBuf: RustBuffer.init(
                capacity: 0,
                len: 0,
                data: nil
            )
        )
    }
}

private func rustCall<T>(_ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    let neverThrow: ((RustBuffer) throws -> Never)? = nil
    return try makeRustCall(callback, errorHandler: neverThrow)
}

private func rustCallWithError<T, E: Swift.Error>(
    _ errorHandler: @escaping (RustBuffer) throws -> E,
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    try makeRustCall(callback, errorHandler: errorHandler)
}

private func makeRustCall<T, E: Swift.Error>(
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T,
    errorHandler: ((RustBuffer) throws -> E)?
) throws -> T {
    uniffiEnsureCelestiaProtoInitialized()
    var callStatus = RustCallStatus.init()
    let returnedVal = callback(&callStatus)
    try uniffiCheckCallStatus(callStatus: callStatus, errorHandler: errorHandler)
    return returnedVal
}

private func uniffiCheckCallStatus<E: Swift.Error>(
    callStatus: RustCallStatus,
    errorHandler: ((RustBuffer) throws -> E)?
) throws {
    switch callStatus.code {
        case CALL_SUCCESS:
            return

        case CALL_ERROR:
            if let errorHandler = errorHandler {
                throw try errorHandler(callStatus.errorBuf)
            } else {
                callStatus.errorBuf.deallocate()
                throw UniffiInternalError.unexpectedRustCallError
            }

        case CALL_UNEXPECTED_ERROR:
            // When the rust code sees a panic, it tries to construct a RustBuffer
            // with the message.  But if that code panics, then it just sends back
            // an empty buffer.
            if callStatus.errorBuf.len > 0 {
                throw UniffiInternalError.rustPanic(try FfiConverterString.lift(callStatus.errorBuf))
            } else {
                callStatus.errorBuf.deallocate()
                throw UniffiInternalError.rustPanic("Rust panic")
            }

        case CALL_CANCELLED:
            fatalError("Cancellation not supported yet")

        default:
            throw UniffiInternalError.unexpectedRustCallStatusCode
    }
}

private func uniffiTraitInterfaceCall<T>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> ()
) {
    do {
        try writeReturn(makeCall())
    } catch let error {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}

private func uniffiTraitInterfaceCallWithError<T, E>(
    callStatus: UnsafeMutablePointer<RustCallStatus>,
    makeCall: () throws -> T,
    writeReturn: (T) -> (),
    lowerError: (E) -> RustBuffer
) {
    do {
        try writeReturn(makeCall())
    } catch let error as E {
        callStatus.pointee.code = CALL_ERROR
        callStatus.pointee.errorBuf = lowerError(error)
    } catch {
        callStatus.pointee.code = CALL_UNEXPECTED_ERROR
        callStatus.pointee.errorBuf = FfiConverterString.lower(String(describing: error))
    }
}
fileprivate final class UniffiHandleMap<T>: @unchecked Sendable {
    // All mutation happens with this lock held, which is why we implement @unchecked Sendable.
    private let lock = NSLock()
    private var map: [UInt64: T] = [:]
    private var currentHandle: UInt64 = 1

    func insert(obj: T) -> UInt64 {
        lock.withLock {
            let handle = currentHandle
            currentHandle += 1
            map[handle] = obj
            return handle
        }
    }

     func get(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map[handle] else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

    @discardableResult
    func remove(handle: UInt64) throws -> T {
        try lock.withLock {
            guard let obj = map.removeValue(forKey: handle) else {
                throw UniffiInternalError.unexpectedStaleHandle
            }
            return obj
        }
    }

    var count: Int {
        get {
            map.count
        }
    }
}


// Public interface members begin here.


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterUInt32: FfiConverterPrimitive {
    typealias FfiType = UInt32
    typealias SwiftType = UInt32

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt32 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterUInt64: FfiConverterPrimitive {
    typealias FfiType = UInt64
    typealias SwiftType = UInt64

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt64 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterString: FfiConverter {
    typealias SwiftType = String
    typealias FfiType = RustBuffer

    public static func lift(_ value: RustBuffer) throws -> String {
        defer {
            value.deallocate()
        }
        if value.data == nil {
            return String()
        }
        let bytes = UnsafeBufferPointer<UInt8>(start: value.data!, count: Int(value.len))
        return String(bytes: bytes, encoding: String.Encoding.utf8)!
    }

    public static func lower(_ value: String) -> RustBuffer {
        return value.utf8CString.withUnsafeBufferPointer { ptr in
            // The swift string gives us int8_t, we want uint8_t.
            ptr.withMemoryRebound(to: UInt8.self) { ptr in
                // The swift string gives us a trailing null byte, we don't want it.
                let buf = UnsafeBufferPointer(rebasing: ptr.prefix(upTo: ptr.count - 1))
                return RustBuffer.from(buf)
            }
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> String {
        let len: Int32 = try readInt(&buf)
        return String(bytes: try readBytes(&buf, count: Int(len)), encoding: String.Encoding.utf8)!
    }

    public static func write(_ value: String, into buf: inout [UInt8]) {
        let len = Int32(value.utf8.count)
        writeInt(&buf, len)
        writeBytes(&buf, value.utf8)
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterData: FfiConverterRustBuffer {
    typealias SwiftType = Data

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Data {
        let len: Int32 = try readInt(&buf)
        return Data(try readBytes(&buf, count: Int(len)))
    }

    public static func write(_ value: Data, into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        writeBytes(&buf, value)
    }
}


/**
 * ABCIMessageLog defines a structure containing an indexed tx ABCI message log.
 */
public struct AbciMessageLog {
    public var msgIndex: UInt32
    public var log: String
    /**
     * Events contains a slice of Event objects that were emitted during some
     * execution.
     */
    public var events: [StringEvent]

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(msgIndex: UInt32, log: String, 
        /**
         * Events contains a slice of Event objects that were emitted during some
         * execution.
         */events: [StringEvent]) {
        self.msgIndex = msgIndex
        self.log = log
        self.events = events
    }
}

#if compiler(>=6)
extension AbciMessageLog: Sendable {}
#endif


extension AbciMessageLog: Equatable, Hashable {
    public static func ==(lhs: AbciMessageLog, rhs: AbciMessageLog) -> Bool {
        if lhs.msgIndex != rhs.msgIndex {
            return false
        }
        if lhs.log != rhs.log {
            return false
        }
        if lhs.events != rhs.events {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(msgIndex)
        hasher.combine(log)
        hasher.combine(events)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeAbciMessageLog: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> AbciMessageLog {
        return
            try AbciMessageLog(
                msgIndex: FfiConverterUInt32.read(from: &buf), 
                log: FfiConverterString.read(from: &buf), 
                events: FfiConverterSequenceTypeStringEvent.read(from: &buf)
        )
    }

    public static func write(_ value: AbciMessageLog, into buf: inout [UInt8]) {
        FfiConverterUInt32.write(value.msgIndex, into: &buf)
        FfiConverterString.write(value.log, into: &buf)
        FfiConverterSequenceTypeStringEvent.write(value.events, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeAbciMessageLog_lift(_ buf: RustBuffer) throws -> AbciMessageLog {
    return try FfiConverterTypeAbciMessageLog.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeAbciMessageLog_lower(_ value: AbciMessageLog) -> RustBuffer {
    return FfiConverterTypeAbciMessageLog.lower(value)
}


/**
 * Attribute defines an attribute wrapper where the key and value are
 * strings instead of raw bytes.
 */
public struct Attribute {
    public var key: String
    public var value: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

#if compiler(>=6)
extension Attribute: Sendable {}
#endif


extension Attribute: Equatable, Hashable {
    public static func ==(lhs: Attribute, rhs: Attribute) -> Bool {
        if lhs.key != rhs.key {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeAttribute: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Attribute {
        return
            try Attribute(
                key: FfiConverterString.read(from: &buf), 
                value: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: Attribute, into buf: inout [UInt8]) {
        FfiConverterString.write(value.key, into: &buf)
        FfiConverterString.write(value.value, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeAttribute_lift(_ buf: RustBuffer) throws -> Attribute {
    return try FfiConverterTypeAttribute.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeAttribute_lower(_ value: Attribute) -> RustBuffer {
    return FfiConverterTypeAttribute.lower(value)
}


/**
 * GasInfo defines tx execution gas context.
 */
public struct GasInfo {
    /**
     * GasWanted is the maximum units of work we allow this tx to perform.
     */
    public var gasWanted: UInt64
    /**
     * GasUsed is the amount of gas actually consumed.
     */
    public var gasUsed: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(
        /**
         * GasWanted is the maximum units of work we allow this tx to perform.
         */gasWanted: UInt64, 
        /**
         * GasUsed is the amount of gas actually consumed.
         */gasUsed: UInt64) {
        self.gasWanted = gasWanted
        self.gasUsed = gasUsed
    }
}

#if compiler(>=6)
extension GasInfo: Sendable {}
#endif


extension GasInfo: Equatable, Hashable {
    public static func ==(lhs: GasInfo, rhs: GasInfo) -> Bool {
        if lhs.gasWanted != rhs.gasWanted {
            return false
        }
        if lhs.gasUsed != rhs.gasUsed {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(gasWanted)
        hasher.combine(gasUsed)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeGasInfo: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> GasInfo {
        return
            try GasInfo(
                gasWanted: FfiConverterUInt64.read(from: &buf), 
                gasUsed: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: GasInfo, into buf: inout [UInt8]) {
        FfiConverterUInt64.write(value.gasWanted, into: &buf)
        FfiConverterUInt64.write(value.gasUsed, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeGasInfo_lift(_ buf: RustBuffer) throws -> GasInfo {
    return try FfiConverterTypeGasInfo.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeGasInfo_lower(_ value: GasInfo) -> RustBuffer {
    return FfiConverterTypeGasInfo.lower(value)
}


/**
 * Params defines the parameters for the auth module.
 */
public struct Params {
    public var maxMemoCharacters: UInt64
    public var txSigLimit: UInt64
    public var txSizeCostPerByte: UInt64
    public var sigVerifyCostEd25519: UInt64
    public var sigVerifyCostSecp256k1: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(maxMemoCharacters: UInt64, txSigLimit: UInt64, txSizeCostPerByte: UInt64, sigVerifyCostEd25519: UInt64, sigVerifyCostSecp256k1: UInt64) {
        self.maxMemoCharacters = maxMemoCharacters
        self.txSigLimit = txSigLimit
        self.txSizeCostPerByte = txSizeCostPerByte
        self.sigVerifyCostEd25519 = sigVerifyCostEd25519
        self.sigVerifyCostSecp256k1 = sigVerifyCostSecp256k1
    }
}

#if compiler(>=6)
extension Params: Sendable {}
#endif


extension Params: Equatable, Hashable {
    public static func ==(lhs: Params, rhs: Params) -> Bool {
        if lhs.maxMemoCharacters != rhs.maxMemoCharacters {
            return false
        }
        if lhs.txSigLimit != rhs.txSigLimit {
            return false
        }
        if lhs.txSizeCostPerByte != rhs.txSizeCostPerByte {
            return false
        }
        if lhs.sigVerifyCostEd25519 != rhs.sigVerifyCostEd25519 {
            return false
        }
        if lhs.sigVerifyCostSecp256k1 != rhs.sigVerifyCostSecp256k1 {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(maxMemoCharacters)
        hasher.combine(txSigLimit)
        hasher.combine(txSizeCostPerByte)
        hasher.combine(sigVerifyCostEd25519)
        hasher.combine(sigVerifyCostSecp256k1)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeParams: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Params {
        return
            try Params(
                maxMemoCharacters: FfiConverterUInt64.read(from: &buf), 
                txSigLimit: FfiConverterUInt64.read(from: &buf), 
                txSizeCostPerByte: FfiConverterUInt64.read(from: &buf), 
                sigVerifyCostEd25519: FfiConverterUInt64.read(from: &buf), 
                sigVerifyCostSecp256k1: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: Params, into buf: inout [UInt8]) {
        FfiConverterUInt64.write(value.maxMemoCharacters, into: &buf)
        FfiConverterUInt64.write(value.txSigLimit, into: &buf)
        FfiConverterUInt64.write(value.txSizeCostPerByte, into: &buf)
        FfiConverterUInt64.write(value.sigVerifyCostEd25519, into: &buf)
        FfiConverterUInt64.write(value.sigVerifyCostSecp256k1, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeParams_lift(_ buf: RustBuffer) throws -> Params {
    return try FfiConverterTypeParams.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeParams_lower(_ value: Params) -> RustBuffer {
    return FfiConverterTypeParams.lower(value)
}


/**
 * SignDoc is the type used for generating sign bytes for SIGN_MODE_DIRECT.
 */
public struct SignDoc {
    /**
     * body_bytes is protobuf serialization of a TxBody that matches the
     * representation in TxRaw.
     */
    public var bodyBytes: Data
    /**
     * auth_info_bytes is a protobuf serialization of an AuthInfo that matches the
     * representation in TxRaw.
     */
    public var authInfoBytes: Data
    /**
     * chain_id is the unique identifier of the chain this transaction targets.
     * It prevents signed transactions from being used on another chain by an
     * attacker
     */
    public var chainId: String
    /**
     * account_number is the account number of the account in state
     */
    public var accountNumber: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(
        /**
         * body_bytes is protobuf serialization of a TxBody that matches the
         * representation in TxRaw.
         */bodyBytes: Data, 
        /**
         * auth_info_bytes is a protobuf serialization of an AuthInfo that matches the
         * representation in TxRaw.
         */authInfoBytes: Data, 
        /**
         * chain_id is the unique identifier of the chain this transaction targets.
         * It prevents signed transactions from being used on another chain by an
         * attacker
         */chainId: String, 
        /**
         * account_number is the account number of the account in state
         */accountNumber: UInt64) {
        self.bodyBytes = bodyBytes
        self.authInfoBytes = authInfoBytes
        self.chainId = chainId
        self.accountNumber = accountNumber
    }
}

#if compiler(>=6)
extension SignDoc: Sendable {}
#endif


extension SignDoc: Equatable, Hashable {
    public static func ==(lhs: SignDoc, rhs: SignDoc) -> Bool {
        if lhs.bodyBytes != rhs.bodyBytes {
            return false
        }
        if lhs.authInfoBytes != rhs.authInfoBytes {
            return false
        }
        if lhs.chainId != rhs.chainId {
            return false
        }
        if lhs.accountNumber != rhs.accountNumber {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bodyBytes)
        hasher.combine(authInfoBytes)
        hasher.combine(chainId)
        hasher.combine(accountNumber)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeSignDoc: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SignDoc {
        return
            try SignDoc(
                bodyBytes: FfiConverterData.read(from: &buf), 
                authInfoBytes: FfiConverterData.read(from: &buf), 
                chainId: FfiConverterString.read(from: &buf), 
                accountNumber: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: SignDoc, into buf: inout [UInt8]) {
        FfiConverterData.write(value.bodyBytes, into: &buf)
        FfiConverterData.write(value.authInfoBytes, into: &buf)
        FfiConverterString.write(value.chainId, into: &buf)
        FfiConverterUInt64.write(value.accountNumber, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeSignDoc_lift(_ buf: RustBuffer) throws -> SignDoc {
    return try FfiConverterTypeSignDoc.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeSignDoc_lower(_ value: SignDoc) -> RustBuffer {
    return FfiConverterTypeSignDoc.lower(value)
}


/**
 * StringEvent defines en Event object wrapper where all the attributes
 * contain key/value pairs that are strings instead of raw bytes.
 */
public struct StringEvent {
    public var type: String
    public var attributes: [Attribute]

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(type: String, attributes: [Attribute]) {
        self.type = type
        self.attributes = attributes
    }
}

#if compiler(>=6)
extension StringEvent: Sendable {}
#endif


extension StringEvent: Equatable, Hashable {
    public static func ==(lhs: StringEvent, rhs: StringEvent) -> Bool {
        if lhs.type != rhs.type {
            return false
        }
        if lhs.attributes != rhs.attributes {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(attributes)
    }
}



#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeStringEvent: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> StringEvent {
        return
            try StringEvent(
                type: FfiConverterString.read(from: &buf), 
                attributes: FfiConverterSequenceTypeAttribute.read(from: &buf)
        )
    }

    public static func write(_ value: StringEvent, into buf: inout [UInt8]) {
        FfiConverterString.write(value.type, into: &buf)
        FfiConverterSequenceTypeAttribute.write(value.attributes, into: &buf)
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeStringEvent_lift(_ buf: RustBuffer) throws -> StringEvent {
    return try FfiConverterTypeStringEvent.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeStringEvent_lower(_ value: StringEvent) -> RustBuffer {
    return FfiConverterTypeStringEvent.lower(value)
}

// Note that we don't yet support `indirect` for enums.
// See https://github.com/mozilla/uniffi-rs/issues/396 for further discussion.
/**
 * BroadcastMode specifies the broadcast mode for the TxService.Broadcast RPC method.
 */

public enum BroadcastMode : Int32 {
    
    /**
     * zero-value for mode ordering
     */
    case unspecified = 0
    /**
     * BROADCAST_MODE_BLOCK defines a tx broadcasting mode where the client waits for
     * the tx to be committed in a block.
     */
    case block = 1
    /**
     * BROADCAST_MODE_SYNC defines a tx broadcasting mode where the client waits for
     * a CheckTx execution response only.
     */
    case sync = 2
    /**
     * BROADCAST_MODE_ASYNC defines a tx broadcasting mode where the client returns
     * immediately.
     */
    case async = 3
}


#if compiler(>=6)
extension BroadcastMode: Sendable {}
#endif

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public struct FfiConverterTypeBroadcastMode: FfiConverterRustBuffer {
    typealias SwiftType = BroadcastMode

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> BroadcastMode {
        let variant: Int32 = try readInt(&buf)
        switch variant {
        
        case 1: return .unspecified
        
        case 2: return .block
        
        case 3: return .sync
        
        case 4: return .async
        
        default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: BroadcastMode, into buf: inout [UInt8]) {
        switch value {
        
        
        case .unspecified:
            writeInt(&buf, Int32(1))
        
        
        case .block:
            writeInt(&buf, Int32(2))
        
        
        case .sync:
            writeInt(&buf, Int32(3))
        
        
        case .async:
            writeInt(&buf, Int32(4))
        
        }
    }
}


#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeBroadcastMode_lift(_ buf: RustBuffer) throws -> BroadcastMode {
    return try FfiConverterTypeBroadcastMode.lift(buf)
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
public func FfiConverterTypeBroadcastMode_lower(_ value: BroadcastMode) -> RustBuffer {
    return FfiConverterTypeBroadcastMode.lower(value)
}


extension BroadcastMode: Equatable, Hashable {}






#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterSequenceTypeAttribute: FfiConverterRustBuffer {
    typealias SwiftType = [Attribute]

    public static func write(_ value: [Attribute], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeAttribute.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [Attribute] {
        let len: Int32 = try readInt(&buf)
        var seq = [Attribute]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterTypeAttribute.read(from: &buf))
        }
        return seq
    }
}

#if swift(>=5.8)
@_documentation(visibility: private)
#endif
fileprivate struct FfiConverterSequenceTypeStringEvent: FfiConverterRustBuffer {
    typealias SwiftType = [StringEvent]

    public static func write(_ value: [StringEvent], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeStringEvent.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [StringEvent] {
        let len: Int32 = try readInt(&buf)
        var seq = [StringEvent]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterTypeStringEvent.read(from: &buf))
        }
        return seq
    }
}

private enum InitializationResult {
    case ok
    case contractVersionMismatch
    case apiChecksumMismatch
}
// Use a global variable to perform the versioning checks. Swift ensures that
// the code inside is only computed once.
private let initializationResult: InitializationResult = {
    // Get the bindings contract version from our ComponentInterface
    let bindings_contract_version = 29
    // Get the scaffolding contract version by calling the into the dylib
    let scaffolding_contract_version = ffi_celestia_proto_uniffi_contract_version()
    if bindings_contract_version != scaffolding_contract_version {
        return InitializationResult.contractVersionMismatch
    }

    return InitializationResult.ok
}()

// Make the ensure init function public so that other modules which have external type references to
// our types can call it.
public func uniffiEnsureCelestiaProtoInitialized() {
    switch initializationResult {
    case .ok:
        break
    case .contractVersionMismatch:
        fatalError("UniFFI contract version mismatch: try cleaning and rebuilding your project")
    case .apiChecksumMismatch:
        fatalError("UniFFI API checksum mismatch: try cleaning and rebuilding your project")
    }
}

// swiftlint:enable all