// Proyecto: Clasificador de Imágenes - Perros vs Gatos
// Autor original: Azamsharp (https://github.com/azamsharp)
// Mejoras realizadas: Estilización, comentarios adicionales, y ajustes de UI por solicitud.

import SwiftUI
import CoreML

// Extensión para convertir UIImage a CVPixelBuffer
extension UIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(self.size.width),
                                         Int(self.size.height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                 width: Int(self.size.width),
                                 height: Int(self.size.height),
                                 bitsPerComponent: 8,
                                 bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                 space: rgbColorSpace,
                                 bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }

    func resize(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

// ContentView
struct ContentView: View {
    let images = ["cat545", "cat456", "cat547", "dog443", "dog444", "dog445"]
    var imageClassifier: CatDogImageClassifier?
    @State private var currentIndex = 0
    @State private var classLabel: String = ""
    @State private var isPredicting = false

    init() {
        do {
            imageClassifier = try CatDogImageClassifier(configuration: MLModelConfiguration())
        } catch {
            print("Error al cargar el modelo: \(error)")
        }
    }

    var body: some View {
         ZStack {
             // Fondo con gradiente
             LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.white]), startPoint: .top, endPoint: .bottom)
                 .ignoresSafeArea()

             VStack(spacing: 20) {
                 // Título
                 Text("Predicción de Imágenes")
                     .font(.largeTitle)
                     .fontWeight(.bold)
                     .foregroundColor(.white)
                     .padding(.top, 50)

                 // Imagen con un borde azul alrededor
                 Image(images[currentIndex])
                     .resizable()
                     .scaledToFit()
                     .frame(width: 250, height: 250)
                     .clipShape(Circle())
                     

                 if isPredicting {
                     ProgressView("Analizando...")
                         .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                         .padding()
                 }

                 // Resultado de la predicción
                 Text("Predicción: \(classLabel)")
                     .font(.title2)
                     .foregroundColor(.white)
                     .padding()

                 // Botón Predecir
                 Button(action: {
                     predict()
                 }) {
                     Text("Predecir")
                         .font(.headline)
                         .padding()
                         .frame(maxWidth: .infinity)
                         .background(Color.white)
                         .foregroundColor(Color.blue)
                         .cornerRadius(10)
                         .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
                 }
                 .padding(.horizontal)

                 // Botones Anterior y Siguiente
                 HStack {
                     Button(action: {
                         currentIndex = max(currentIndex - 1, 0)
                         classLabel = ""
                     }) {
                         Text("Anterior")
                             .fontWeight(.semibold)
                             .padding()
                             .frame(maxWidth: .infinity)
                             .background(Color.white)
                             .foregroundColor(Color.blue)
                             .cornerRadius(10)
                             .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
                     }
                     .disabled(currentIndex == 0)

                     Button(action: {
                         currentIndex = min(currentIndex + 1, images.count - 1)
                         classLabel = ""
                     }) {
                         Text("Siguiente")
                             .fontWeight(.semibold)
                             .padding()
                             .frame(maxWidth: .infinity)
                             .background(Color.white)
                             .foregroundColor(Color.blue)
                             .cornerRadius(10)
                             .shadow(color: .gray.opacity(0.5), radius: 5, x: 0, y: 5)
                     }
                     .disabled(currentIndex == images.count - 1)
                 }
                 .padding(.horizontal)
             }
             .padding()
         }
     }

    // Función para realizar la predicción
    private func predict() {
        guard let uiImage = UIImage(named: images[currentIndex]) else {
            print("No se pudo cargar la imagen")
            classLabel = "Error al cargar imagen"
            return
        }

        guard let resizedImage = uiImage.resize(to: CGSize(width: 224, height: 224)) else {
            print("Error al redimensionar la imagen")
            classLabel = "Error al procesar imagen"
            return
        }

        guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
            print("Error al convertir la imagen a CVPixelBuffer")
            classLabel = "Error al procesar imagen"
            return
        }

        isPredicting = true

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.imageClassifier?.prediction(image: pixelBuffer)
                DispatchQueue.main.async {
                    self.classLabel = result?.classLabel ?? "Sin etiqueta"
                    self.isPredicting = false
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error al predecir: \(error.localizedDescription)")
                    self.classLabel = "Error en predicción"
                    self.isPredicting = false
                }
            }
        }
    }
}

// Vista Previa
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
