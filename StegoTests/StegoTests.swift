//
//  StegoTests.swift
//  StegoTests
//
//  Created by Сергей Андрианов on 18.09.2026.
//

import Testing
import Foundation
import CoreGraphics
@testable import Stego

struct StegoTests {

    // MARK: - 1. Тестирование обфускации строк
    @Test func testStringObfuscation() {
        let originalText = "Тестовая строка для проверки обфускации"
        let key: UInt8 = 0x42
        let encoded = _0xObf.encodeForSource(originalText, key: key)
        let decoded = _0xObf._s(encoded, key: key)
        
        #expect(decoded == originalText)
        
        // Проверка ошибок StegoError (все строки расшифровываются корректно)
        #expect(StegoError.invalidImageFormat.errorDescription == "Не удалось обработать формат изображения.")
        #expect(StegoError.imageTooSmall(required: 10, available: 5).errorDescription == "Изображение слишком мало. Требуется байт: 10, доступно: 5.")
        #expect(StegoError.extractionFailed.errorDescription == "Не удалось извлечь данные. Возможно, они отсутствуют или повреждены.")
        #expect(StegoError.encodingFailed.errorDescription == "Ошибка при конвертации текста в байты.")
    }

    // MARK: - 2. Тестирование непрозрачных предикатов (Control Flow)
    @Test func testOpaquePredicates() {
        for seed in [-1000, -1, 0, 1, 2, 42, 100, 99999] {
            #expect(_0xObf._t(seed) == true)
            #expect(_0xObf._f(seed) == false)
        }
    }

    // MARK: - 3. Тестирование обфускации констант
    @Test func testConstantObfuscation() {
        #expect(_0xObf._c0() == 0)
        #expect(_0xObf._c1() == 1)
        #expect(_0xObf._c3() == 3)
        #expect(_0xObf._c4() == 4)
        #expect(_0xObf._c7() == 7)
        #expect(_0xObf._c8() == 8)
        #expect(_0xObf._maskFE() == 0xFE)
    }

    // MARK: - 4. Интеграционное тестирование LSB стеганографии
    @Test func testEmbedAndExtract() throws {
        // Создаем тестовое изображение 20x20 пикселей (RGBA)
        let width = 20
        let height = 20
        let bytesPerPixel = 4
        let totalBytes = width * height * bytesPerPixel
        var pixelData = [UInt8](repeating: 128, count: totalBytes)
        
        // Заполняем альфа-канал непрозрачностью 255
        for i in stride(from: 3, to: totalBytes, by: 4) {
            pixelData[i] = 255
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: Data(pixelData) as CFData)!
        let testImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        
        let engine = LSBEngine()
        let secretMessage = "Секретный пароль 12345! Secret Obfuscated Stego 🔐"
        
        // Внедрение
        let stegoImage = try engine.embed(payload: secretMessage, into: testImage)
        #expect(stegoImage.width == width)
        #expect(stegoImage.height == height)
        
        // Извлечение
        let extractedMessage = try engine.extract(from: stegoImage)
        #expect(extractedMessage == secretMessage)
    }
}
