//
//  StegoEngine.swift
//  Stego
//
//  Created by Сергей Андрианов on 18.09.2026.
//

import Foundation
import CoreGraphics

// MARK: - ошибки
enum StegoError: Error, LocalizedError {
    case invalidImageFormat
    case imageTooSmall(required: Int, available: Int)
    case extractionFailed
    case encodingFailed
    
    // MARK: - Способ 1: Динамическая обфускация строк (String Obfuscation)
    // Строки скрыты в виде байтовых массивов и расшифровываются на лету через _0xObf._s
    private static let _obfKey: UInt8 = 0x7E
    private static let _msgInvalidImage: [UInt8] = [174, 226, 172, 200, 90, 170, 251, 169, 194, 167, 196, 165, 201, 163, 206, 160, 239, 190, 224, 77, 186, 213, 184, 216, 183, 231, 180, 213, 178, 210, 176, 223, 143, 221, 140, 237, 139, 217, 137, 213, 118, 134, 208, 133, 236, 130, 208, 129, 242, 159, 252, 156, 200, 107, 152, 241, 150, 240, 148, 251, 146, 242, 145, 193, 238, 143, 236, 139, 234, 142, 232, 132, 230, 143, 229, 186, 28]
    private static let _msgTooSmallPrefix: [UInt8] = [174, 231, 172, 202, 170, 197, 168, 200, 167, 247, 164, 197, 162, 197, 160, 196, 190, 210, 188, 213, 186, 222, 72, 184, 231, 183, 223, 181, 218, 178, 232, 177, 228, 143, 226, 141, 230, 123, 136, 229, 134, 231, 132, 238, 130, 237, 126, 113, 158, 237, 157, 205, 154, 254, 152, 248, 151, 196, 148, 240, 147, 193, 145, 192, 239, 176, 28, 237, 139, 235, 136, 233, 143, 230, 182, 15, 18]
    private static let _msgTooSmallMid: [UInt8] = [82, 95, 172, 201, 170, 197, 169, 248, 167, 245, 165, 246, 162, 204, 160, 204, 190, 209, 86, 77]
    private static let _msgDot: [UInt8] = [80]
    private static let _msgExtractionFailed: [UInt8] = [174, 226, 172, 200, 90, 170, 251, 169, 194, 167, 196, 165, 201, 163, 206, 160, 239, 190, 224, 77, 186, 211, 184, 222, 182, 213, 180, 222, 178, 214, 177, 230, 143, 211, 124, 141, 238, 139, 232, 137, 235, 135, 233, 132, 217, 131, 229, 127, 110, 159, 222, 157, 244, 155, 255, 153, 250, 151, 250, 149, 244, 147, 253, 145, 128, 19, 28, 237, 132, 235, 133, 233, 142, 23, 228, 139, 227, 177, 225, 176, 255, 172, 253, 175, 251, 170, 249, 171, 246, 149, 245, 166, 243, 173, 241, 163, 62, 207, 164, 205, 161, 203, 160, 57, 198, 168, 196, 171, 194, 161, 193, 145, 222, 186, 220, 187, 218, 191, 216, 188, 214, 186, 213, 142, 44]
    private static let _msgEncodingFailed: [UInt8] = [174, 225, 173, 245, 170, 195, 168, 200, 166, 205, 164, 197, 82, 163, 207, 160, 238, 191, 212, 77, 186, 209, 184, 215, 182, 218, 180, 215, 178, 214, 177, 225, 143, 221, 140, 237, 139, 221, 136, 225, 134, 239, 116, 132, 208, 131, 229, 129, 244, 158, 205, 156, 200, 155, 248, 105, 150, 245, 100, 149, 243, 147, 240, 145, 135, 238, 190, 236, 177, 21]
    
    var errorDescription: String? {
        switch self {
        case .invalidImageFormat:
            return _0xObf._s(Self._msgInvalidImage, key: Self._obfKey)
        case .imageTooSmall(let req, let avail):
            return "\(_0xObf._s(Self._msgTooSmallPrefix, key: Self._obfKey))\(req)\(_0xObf._s(Self._msgTooSmallMid, key: Self._obfKey))\(avail)\(_0xObf._s(Self._msgDot, key: Self._obfKey))"
        case .extractionFailed:
            return _0xObf._s(Self._msgExtractionFailed, key: Self._obfKey)
        case .encodingFailed:
            return _0xObf._s(Self._msgEncodingFailed, key: Self._obfKey)
        }
    }
}

// MARK: - интерфейсы
protocol StegoCodec {
    /// Внедряет секретную строку в исходное изображение
    func embed(payload: String, into image: CGImage) throws -> CGImage
    /// Извлекает секретную строку из модифицированного изображения
    func extract(from image: CGImage) throws -> String
}

// MARK: - обработка изображения
/// Класс отвечает исключительно за трансформацию CGImage в массив байтов и обратно
class ImageProcessor {
    
    struct PixelBuffer {
        var bytes: [UInt8]
        let width: Int
        let height: Int
    }
    
    static func getPixelBuffer(from image: CGImage) throws -> PixelBuffer {
        let width = image.width
        let height = image.height
        // MARK: - Способ 3: Обфускация числовых констант
        let bytesPerPixel = _0xObf._c4() // RGBA: 4 байта на пиксель
        let totalBytes = width * height * bytesPerPixel
        
        var rawBytes = [UInt8](repeating: UInt8(_0xObf._c0()), count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: _0xObf._c8(),
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw StegoError.invalidImageFormat
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelBuffer(bytes: rawBytes, width: width, height: height)
    }
    
    static func createCGImage(from buffer: PixelBuffer) throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = _0xObf._c4()
        
        // Копируем данные, чтобы CoreGraphics мог безопасно ими управлять
        let data = Data(buffer.bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  width: buffer.width,
                  height: buffer.height,
                  bitsPerComponent: _0xObf._c8(),
                  bitsPerPixel: _0xObf._c4() * _0xObf._c8(),
                  bytesPerRow: buffer.width * bytesPerPixel,
                  space: colorSpace,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            throw StegoError.invalidImageFormat
        }
        return cgImage
    }
}

// MARK: - алгоритм LSB
class LSBEngine: StegoCodec {
    
    func embed(payload: String, into image: CGImage) throws -> CGImage {
        // MARK: - Способ 2: Запутывание потока управления (Непрозрачные предикаты)
        // Ложная ветка ошибки, отбрасывание которой декомпилятор не может доказать на этапе анализа
        if _0xObf._f(image.width) {
            throw StegoError.extractionFailed
        }
        
        var buffer = try ImageProcessor.getPixelBuffer(from: image)
        
        // Фиктивный блок кода для усложнения анализа графа потока управления (CFG)
        if _0xObf._f(buffer.bytes.count) {
            _0xObf._dummyBranch(&buffer.bytes)
        }
        
        guard var payloadBytes = payload.data(using: .utf8).map({ [UInt8]($0) }) else {
            throw StegoError.encodingFailed
        }
        
        // MARK: - Способ 3: Обфускация констант и битовых операций
        payloadBytes.append(UInt8(_0xObf._c0())) // Терминатор \0
        
        // Доступно только 3 байта из 4 в каждом пикселе (без альфа-канала)
        let usableBytes = (buffer.bytes.count / _0xObf._c4()) * _0xObf._c3()
        let requiredBits = payloadBytes.count * _0xObf._c8()
        
        if requiredBits > usableBytes {
            throw StegoError.imageTooSmall(required: requiredBits, available: usableBytes)
        }
        
        var byteIndex = _0xObf._c0()
        var bitIndex = _0xObf._c0()
        let totalCount = buffer.bytes.count
        let alphaStrideMask = _0xObf._c4() - _0xObf._c1() // 4 - 1 = 3 (для быстрой маски mod 4)
        
        for i in 0..<totalCount {
            // Непрозрачный предикат: условие всегда истинно в рантайме,
            // но в ассемблере генерируется условный переход и мертвое тело else
            if _0xObf._t(i) {
                // Пропускаем Альфа-канал: замена (i + 1) % 4 == 0 на битовую маску
                if ((i + _0xObf._c1()) & alphaStrideMask) == _0xObf._c0() { 
                    continue 
                }
                
                let shift = _0xObf._c7() - bitIndex
                let targetBit = (payloadBytes[byteIndex] >> shift) & UInt8(_0xObf._c1())
                buffer.bytes[i] = (buffer.bytes[i] & _0xObf._maskFE()) | targetBit
                
                bitIndex += _0xObf._c1()
                if bitIndex == _0xObf._c8() {
                    bitIndex = _0xObf._c0()
                    byteIndex += _0xObf._c1()
                }
                
                // Если записали все сообщение — выходим из цикла
                if byteIndex >= payloadBytes.count {
                    break
                }
            } else {
                // Мертвый код (Dead Code), никогда не выполняется в рантайме
                buffer.bytes[i] ^= 0xFF
            }
        }
        
        return try ImageProcessor.createCGImage(from: buffer)
    }
    
    func extract(from image: CGImage) throws -> String {
        // MARK: - Способ 2: Запутывание потока управления
        if _0xObf._f(image.height) {
            throw StegoError.invalidImageFormat
        }
        
        let buffer = try ImageProcessor.getPixelBuffer(from: image)
        
        var extractedBytes: [UInt8] = []
        var currentByte: UInt8 = UInt8(_0xObf._c0())
        var bitIndex = _0xObf._c0()
        let totalCount = buffer.bytes.count
        let alphaStrideMask = _0xObf._c4() - _0xObf._c1()
        
        for i in 0..<totalCount {
            // Непрозрачный предикат
            if _0xObf._t(i) {
                // Пропускаем Альфа-канал при чтении
                if ((i + _0xObf._c1()) & alphaStrideMask) == _0xObf._c0() { 
                    continue 
                }
                
                let extractedBit = buffer.bytes[i] & UInt8(_0xObf._c1())
                currentByte = (currentByte << _0xObf._c1()) | extractedBit
                
                bitIndex += _0xObf._c1()
                
                if bitIndex == _0xObf._c8() {
                    if currentByte == UInt8(_0xObf._c0()) {
                        break // Нашли терминатор
                    }
                    extractedBytes.append(currentByte)
                    currentByte = UInt8(_0xObf._c0())
                    bitIndex = _0xObf._c0()
                }
            } else {
                // Мертвый код
                extractedBytes.append(0xFE)
            }
        }
        
        if extractedBytes.isEmpty {
            throw StegoError.extractionFailed
        }
        
        guard let resultString = String(bytes: extractedBytes, encoding: .utf8) else {
            throw StegoError.extractionFailed
        }
        
        return resultString
    }
}
