//
//  ContentView.swift
//  Stego
//
//  Created by Сергей Андрианов on 18.09.2026.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

// MARK: - ViewModel (Связующее звено)
class StegoViewModel: ObservableObject {
    @Published var inputImage: NSImage?
    @Published var outputCGImage: CGImage?
    @Published var secretText: String = ""
    @Published var statusMessage: String = "Перетащите картинку (PNG/BMP) или кликните для выбора"
    
    private let engine = LSBEngine() // Инициализация ядра из файла StegoEngine.swift
    
    // Открытие файла через системное окно Finder
    func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .bmp]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            loadImage(from: url)
        }
    }
    
    func loadImage(from url: URL) {
        if let image = NSImage(contentsOf: url) {
            self.inputImage = image
            self.outputCGImage = nil
            self.secretText = ""
            self.statusMessage = "Изображение загружено. Введите текст."
        } else {
            self.statusMessage = "Ошибка загрузки файла."
        }
    }
    
    // Процесс сокрытия текста
    func embedText() {
        guard let input = inputImage, !secretText.isEmpty else {
            statusMessage = "Ошибка: нет картинки или пустое сообщение."
            return
        }
        
        // Получаем CGImage из NSImage (стандартная процедура AppKit)
        var rect = CGRect(x: 0, y: 0, width: input.size.width, height: input.size.height)
        guard let cgImage = input.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            statusMessage = "Ошибка чтения пикселей изображения."
            return
        }
        
        do {
            let resultImage = try engine.embed(payload: secretText, into: cgImage)
            self.outputCGImage = resultImage
            self.statusMessage = "Текст успешно скрыт! Нажмите «Сохранить результат»."
        } catch let error as StegoError {
            self.statusMessage = "Ошибка: \(error.localizedDescription)"
        } catch {
            self.statusMessage = "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
    
    // Процесс извлечения текста
    func extractText() {
        guard let input = inputImage else {
            statusMessage = "Ошибка: сначала загрузите картинку с секретом."
            return
        }
        
        var rect = CGRect(x: 0, y: 0, width: input.size.width, height: input.size.height)
        guard let cgImage = input.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
        
        do {
            let extracted = try engine.extract(from: cgImage)
            self.secretText = extracted
            self.statusMessage = "Текст успешно извлечен!"
        } catch let error as StegoError {
            self.statusMessage = "Ошибка извлечения: \(error.localizedDescription)"
        } catch {
            self.statusMessage = "Неизвестная ошибка."
        }
    }
    
    // Сохранение готового файла (строго в PNG без потери данных)
    func saveImage() {
        guard let cgImage = outputCGImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "stego_result.png"
        
        if panel.runModal() == .OK, let url = panel.url {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: url)
                    statusMessage = "Файл успешно сохранен!"
                } catch {
                    statusMessage = "Ошибка при записи файла на диск."
                }
            }
        }
    }
}

// MARK: - View (Интерфейс пользователя)
struct ContentView: View {
    @StateObject private var viewModel = StegoViewModel()
    @State private var isTargeted = false // Для анимации Drag-and-Drop
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Зона загрузки изображения (Drag & Drop + Клик)
            ZStack {
                // фон при закидывании
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTargeted ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .frame(height: 260)
                
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isTargeted ? Color.blue : Color.gray.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                
                if let image = viewModel.inputImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 240)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Перетащите PNG файл сюда\nили нажмите для выбора")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                // Обработка перетаскивания файла из Finder
                if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            DispatchQueue.main.async { viewModel.loadImage(from: url) }
                        }
                    }
                    return true
                }
                return false
            }
            .onTapGesture {
                viewModel.selectImage()
            }
            
            // Статусная строка
            Text(viewModel.statusMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(viewModel.statusMessage.contains("Ошибка") ? .red : .green)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Поле для ввода/вывода секретного сообщения
            TextEditor(text: $viewModel.secretText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            
            // Панель кнопок
            HStack(spacing: 16) {
                Button("Скрыть текст") {
                    viewModel.embedText()
                }
                .disabled(viewModel.inputImage == nil || viewModel.secretText.isEmpty)
                
                Button("Извлечь текст") {
                    viewModel.extractText()
                }
                .disabled(viewModel.inputImage == nil)
                
                Spacer()
                
                Button("Сохранить результат") {
                    viewModel.saveImage()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.outputCGImage == nil)
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 600)
    }
}
