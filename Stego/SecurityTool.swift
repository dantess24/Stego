//
//  SecurityTool.swift
//  Stego
//
//  Created by Сергей Андрианов on 18.09.2026.
//

import Foundation

class SecurityTool {
    
    // MARK: - 1. Анти-отладка (Anti-Debugging)
    static func disableDebugging() {
        let handle = dlopen(nil, RTLD_GLOBAL)
        let ptracePtr = dlsym(handle, "ptrace")
        
        if let ptracePtr = ptracePtr {
            typealias PtraceType = @convention(c) (Int32, pid_t, UnsafeMutableRawPointer?, Int32) -> Int32
            let ptrace = unsafeBitCast(ptracePtr, to: PtraceType.self)
            
            let PT_DENY_ATTACH: Int32 = 31
            _ = ptrace(PT_DENY_ATTACH, 0, nil, 0)
        }
        
        dlclose(handle)
    }
    
    // MARK: - 2. Обфускация констант (String Obfuscation)
    static func obfuscate(string: String, key: UInt8 = 0xAA) -> [UInt8] {
        return string.utf8.map { $0 ^ key }
    }
    
    static func deobfuscate(bytes: [UInt8], key: UInt8 = 0xAA) -> String {
        let decrypted = bytes.map { $0 ^ key }
        return String(bytes: decrypted, encoding: .utf8) ?? ""
    }
}
