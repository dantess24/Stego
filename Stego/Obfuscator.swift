//
//  Obfuscator.swift
//  Stego
//
//  Created by Сергей Андрианов on 14.10.2026.
//

import Foundation

enum _0xObf {
    
    // MARK: - 1. Динамическая расшифровка строк (XOR + сдвиг индекса)
    @inline(__always)
    static func _s(_ bytes: [UInt8], key: UInt8) -> String {
        let decoded = bytes.enumerated().map { index, byte in
            byte ^ key ^ UInt8( index & 0xFF )
        }
        return String(bytes: decoded, encoding: .utf8) ?? ""
    }
    
    // Вспомогательный метод: вызови его один раз в консоли, чтобы получить массив байтов для любой своей строки
    static func encodeForSource(_ text: String, key: UInt8) -> [UInt8] {
        return Array(text.utf8).enumerated().map { index, byte in
            byte ^ key ^ UInt8( index & 0xFF )
        }
    }
    
    // MARK: - 2. Непрозрачные предикаты (Opaque Predicates)
    // Математическое свойство: x * (x + 1) ВСЕГДА четное число для любого целого x.
    // Использование времени/памяти не дает оптимизатору LLVM вырезать проверку на этапе компиляции.
    private static let _obj = NSObject()

    @inline(never)
    static func _t(_ seed: Int) -> Bool {
        let x = seed ^ Int(bitPattern: Unmanaged.passUnretained(_obj).toOpaque())
        return ((x &* (x &+ 1)) & 1) == 0 // Всегда возвращает true
    }
    
    // Всегда возвращает false, но выглядит для декомпилятора как сложная проверка
    @inline(never)
    static func _f(_ seed: Int) -> Bool {
        let x = (seed | 1)
        return ((x &* x) & 3) == 2 // Квадрат нечетного числа по модулю 4 всегда равен 1, никогда 2
    }
    
    // Фиктивная ветка для запутывания декомпилятора (dead code)
    @inline(never)
    static func _dummyBranch(_ buffer: inout [UInt8]) {
        for idx in 0..<buffer.count {
            buffer[idx] = buffer[idx] ^ 0xAA
        }
    }
    
    // MARK: - 3. Вычисление констант на лету (скрываем магические числа 0, 1, 3, 4, 7, 8, 0xFE)
    @inline(__always)
    static func _c0() -> Int {
        return (0x7F ^ 0x7F) // 0
    }
    
    @inline(__always)
    static func _c1() -> Int {
        return (0x6C ^ 0x6D) // 1
    }
    
    @inline(__always)
    static func _c3() -> Int {
        return (0x4E ^ 0x4D) // 3
    }
    
    @inline(__always)
    static func _c4() -> Int {
        return (0x5A ^ 0x5E) // 4
    }
    
    @inline(__always)
    static func _c7() -> Int {
        return (0x2A ^ 0x2D) // 7
    }
    
    @inline(__always)
    static func _c8() -> Int {
        return (0x33 ^ 0x3B) // 8
    }
    
    @inline(__always)
    static func _maskFE() -> UInt8 {
        return UInt8(0xAA ^ 0x54) // 0xFE (254)
    }
}
