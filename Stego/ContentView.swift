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
import ImageIO

// MARK: - ViewModel (Связующее звено)
@MainActor
class StegoViewModel: ObservableObject {
    @Published var inputImage: NSImage?
    @Published var outputCGImage: CGImage?
    @Published var secretText: String = ""
    @Published var statusMessage: String = "Перетащите картинку (PNG/BMP) или кликните для выбора"
    @Published var isError = false
    @Published var isProcessing = false
    
    private let engine = LSBEngine() // Инициализация ядра из файла StegoEngine.swift
    private var inputCGImage: CGImage? // Исходные пиксели без пересчёта размера
    
    private func setStatus(_ message: String, isError: Bool = false) {
        statusMessage = message
        self.isError = isError
    }
    
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
        // CGImageSource отдаёт реальные пиксели файла (на Retina NSImage.size — в пунктах)
        guard let image = NSImage(contentsOf: url),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            setStatus("Ошибка загрузки файла.", isError: true)
            return
        }
        inputImage = image
        inputCGImage = cgImage
        outputCGImage = nil
        secretText = ""
        setStatus("Изображение загружено. Введите текст.")
    }
    
    // Процесс сокрытия текста (тяжёлая работа — вне главного потока)
    func embedText() {
        guard let cgImage = inputCGImage, !secretText.isEmpty else {
            setStatus("Ошибка: нет картинки или пустое сообщение.", isError: true)
            return
        }
        
        let engine = engine
        let text = secretText
        isProcessing = true
        setStatus("Обработка…")
        
        Task {
            let result = await Task.detached { Result { try engine.embed(payload: text, into: cgImage) } }.value
            isProcessing = false
            switch result {
            case .success(let image):
                outputCGImage = image
                setStatus("Текст успешно скрыт! Нажмите «Сохранить результат».")
            case .failure(let error):
                setStatus("Ошибка: \(error.localizedDescription)", isError: true)
            }
        }
    }
    
    // Процесс извлечения текста
    func extractText() {
        guard let cgImage = inputCGImage else {
            setStatus("Ошибка: сначала загрузите картинку с секретом.", isError: true)
            return
        }
        
        let engine = engine
        isProcessing = true
        setStatus("Обработка…")
        
        Task {
            let result = await Task.detached { Result { try engine.extract(from: cgImage) } }.value
            isProcessing = false
            switch result {
            case .success(let text):
                secretText = text
                setStatus("Текст успешно извлечен!")
            case .failure(let error):
                setStatus("Ошибка извлечения: \(error.localizedDescription)", isError: true)
            }
        }
    }
    
    // Сохранение готового файла (строго в PNG без потери данных)
    func saveImage() {
        guard let cgImage = outputCGImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "stego_result.png"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        // CGImageDestination пишет пиксели как есть, в том же sRGB-пространстве
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            setStatus("Ошибка при записи файла на диск.", isError: true)
            return
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        if CGImageDestinationFinalize(destination) {
            setStatus("Файл успешно сохранен!")
        } else {
            setStatus("Ошибка при записи файла на диск.", isError: true)
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
                .foregroundColor(viewModel.isError ? .red : .green)
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
                .disabled(viewModel.inputImage == nil || viewModel.secretText.isEmpty || viewModel.isProcessing)
                
                Button("Извлечь текст") {
                    viewModel.extractText()
                }
                .disabled(viewModel.inputImage == nil || viewModel.isProcessing)
                
                Spacer()
                
                Button("Сохранить результат") {
                    viewModel.saveImage()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.outputCGImage == nil || viewModel.isProcessing)
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 600)
    }
}
