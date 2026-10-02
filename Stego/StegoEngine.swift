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
    
    var errorDescription: String? {
        switch self {
        case .invalidImageFormat: return "Не удалось обработать формат изображения."
        case .imageTooSmall(let req, let avail): return "Изображение слишком мало. Требуется байт: \(req), доступно: \(avail)."
        case .extractionFailed: return "Не удалось извлечь данные. Возможно, они отсутствуют или повреждены."
        case .encodingFailed: return "Ошибка при конвертации текста в байты."
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

// MARK: - обработка изображения
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
        let bytesPerPixel = 4 // RGBA
        let totalBytes = width * height * bytesPerPixel
        
        var rawBytes = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
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
        let bytesPerPixel = 4
        
        // Копируем данные, чтобы CoreGraphics мог безопасно ими управлять
        let data = Data(buffer.bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  width: buffer.width,
                  height: buffer.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
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
        var buffer = try ImageProcessor.getPixelBuffer(from: image)
        
        guard var payloadBytes = payload.data(using: .utf8).map({ [UInt8]($0) }) else {
            throw StegoError.encodingFailed
        }
        payloadBytes.append(0) // Терминатор \0
        
        // Теперь нам доступно только 3 байта из 4 в каждом пикселе
        let usableBytes = (buffer.bytes.count / 4) * 3
        let requiredBits = payloadBytes.count * 8
        
        if requiredBits > usableBytes {
            throw StegoError.imageTooSmall(required: requiredBits, available: usableBytes)
        }
        
        var byteIndex = 0
        var bitIndex = 0
        
        for i in 0..<buffer.bytes.count {
            // Пропускаем Альфа-канал (каждый 4-й байт)
            if (i + 1) % 4 == 0 { continue }
            
            let targetBit = (payloadBytes[byteIndex] >> (7 - bitIndex)) & 1
            buffer.bytes[i] = (buffer.bytes[i] & 0xFE) | targetBit
            
            bitIndex += 1
            if bitIndex == 8 {
                bitIndex = 0
                byteIndex += 1
            }
            
            // Если записали все сообщение — выходим из цикла
            if byteIndex >= payloadBytes.count {
                break
            }
        }
        
        return try ImageProcessor.createCGImage(from: buffer)
    }
    
    func extract(from image: CGImage) throws -> String {
        let buffer = try ImageProcessor.getPixelBuffer(from: image)
        
        var extractedBytes: [UInt8] = []
        var currentByte: UInt8 = 0
        var bitIndex = 0
        
        for i in 0..<buffer.bytes.count {
            // Пропускаем Альфа-канал при чтении
            if (i + 1) % 4 == 0 { continue }
            
            let extractedBit = buffer.bytes[i] & 1
            currentByte = (currentByte << 1) | extractedBit
            
            bitIndex += 1
            
            if bitIndex == 8 {
                if currentByte == 0 {
                    break // Нашли терминатор
                }
                extractedBytes.append(currentByte)
                currentByte = 0
                bitIndex = 0
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
