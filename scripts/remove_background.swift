import Foundation
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Limit optional color cleanup to a narrow band next to the transparent region.
// Never classify pale pixels deep inside the subject as background.
func cleanLightFringe(mask: CIImage, original: CIImage, context: CIContext) throws -> CIImage {
    let width = Int(original.extent.width), height = Int(original.extent.height)
    let count = width * height
    var pixels = [UInt8](repeating: 0, count: count * 4)
    var matte = [UInt8](repeating: 0, count: count * 4)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    context.render(original, toBitmap: &pixels, rowBytes: width * 4, bounds: original.extent, format: .RGBA8, colorSpace: colorSpace)
    context.render(mask, toBitmap: &matte, rowBytes: width * 4, bounds: original.extent, format: .RGBA8, colorSpace: colorSpace)
    var distance = [UInt8](repeating: 255, count: count)
    var queue = [Int]()
    func neighbors(_ i: Int) -> [Int] {
        var result = [Int]()
        if i % width > 0 { result.append(i - 1) }
        if i % width < width - 1 { result.append(i + 1) }
        if i >= width { result.append(i - width) }
        if i < count - width { result.append(i + width) }
        return result
    }
    for i in 0..<count where matte[i * 4] <= 2 {
        distance[i] = 0
        if neighbors(i).contains(where: { matte[$0 * 4] > 2 }) { queue.append(i) }
    }
    var head = 0
    while head < queue.count {
        let i = queue[head]; head += 1
        if distance[i] >= 12 { continue }
        for n in neighbors(i) where distance[n] == 255 {
            distance[n] = distance[i] + 1
            queue.append(n)
        }
    }
    var keepFactors = [Double](repeating: 1, count: count)
    var edgeConnected = [Bool](repeating: false, count: count)
    queue.removeAll(keepingCapacity: true)
    for i in 0..<count {
        if distance[i] <= 12 {
            let r = Double(pixels[i * 4]), g = Double(pixels[i * 4 + 1]), b = Double(pixels[i * 4 + 2])
            let lo = min(r, min(g, b)), hi = max(r, max(g, b))
            let keep = min(1, max(0, max((hi - lo - 6) / 10, (242 - lo) / 20)))
            keepFactors[i] = keep
            if keep < 1 && distance[i] <= 1 {
                edgeConnected[i] = true
                queue.append(i)
            }
        }
    }
    head = 0
    while head < queue.count {
        let i = queue[head]; head += 1
        for n in neighbors(i) where !edgeConnected[n] && keepFactors[n] < 1 {
            edgeConnected[n] = true
            queue.append(n)
        }
    }
    // Preserve isolated highlights even when they fall inside the distance band.
    var gray = [UInt8](repeating: 0, count: count)
    for i in 0..<count {
        let value = Double(matte[i * 4]) * (edgeConnected[i] ? keepFactors[i] : 1)
        gray[i] = UInt8(max(0, min(255, value)))
    }
    // A pale subject can be indistinguishable from a fringe by color alone.
    // Reject destructive cleanup per connected region, so a small white subject
    // cannot disappear unnoticed beside a much larger colored one.
    var visited = [Bool](repeating: false, count: count)
    for seed in 0..<count where !visited[seed] && matte[seed * 4] > 2 {
        queue.removeAll(keepingCapacity: true)
        queue.append(seed)
        visited[seed] = true
        head = 0
        var before = 0.0, after = 0.0
        while head < queue.count {
            let i = queue[head]; head += 1
            before += Double(matte[i * 4])
            after += Double(gray[i])
            for n in neighbors(i) where !visited[n] && matte[n * 4] > 2 {
                visited[n] = true
                queue.append(n)
            }
        }
        if before >= 64 * 255 && after < before * 0.85 {
            throw NSError(domain: "Playseed", code: 8, userInfo: [NSLocalizedDescriptionKey: "浅色残边清理可能误删白色主体或细毛，已停止保存。请关闭“清理浅色残边”后重试，原稿保持不变。"])
        }
    }
    let provider = CGDataProvider(data: Data(gray) as CFData)!
    let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    return CIImage(cgImage: cg)
}

// The host passes a verified draft snapshot and a new job-local output path.
func run() throws {
    guard [4, 5].contains(CommandLine.arguments.count) else { throw NSError(domain: "Playseed", code: 1, userInfo: [NSLocalizedDescriptionKey: "缺少图片路径。"])}
    guard let inset = Double(CommandLine.arguments[3]), inset >= 0, inset <= 8 else { throw NSError(domain: "Playseed", code: 5, userInfo: [NSLocalizedDescriptionKey: "收边程度无效。"])}
    let cleanup = CommandLine.arguments.count == 5 && CommandLine.arguments[4] == "true"
    if CommandLine.arguments.count == 5 && !["true", "false"].contains(CommandLine.arguments[4]) { throw NSError(domain: "Playseed", code: 7) }
    let input = URL(fileURLWithPath: CommandLine.arguments[1])
    let output = URL(fileURLWithPath: CommandLine.arguments[2])
    guard !FileManager.default.fileExists(atPath: output.path) else { throw NSError(domain: "Playseed", code: 2, userInfo: [NSLocalizedDescriptionKey: "输出已存在，不会覆盖。"])}
    guard let original = CIImage(contentsOf: input) else { throw NSError(domain: "Playseed", code: 6) }
    let context = CIContext()
    let width = Int(original.extent.width), height = Int(original.extent.height)
    var rgba = [UInt8](repeating: 0, count: width * height * 4)
    context.render(original, toBitmap: &rgba, rowBytes: width * 4, bounds: original.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    let hasTransparency = stride(from: 3, to: rgba.count, by: 4).contains { rgba[$0] < 255 }
    if hasTransparency && inset == 0 && !cleanup {
        try FileManager.default.copyItem(at: input, to: output)
        print("PLAYSEED_CUTOUT_OK")
        return
    }
    var sourceMask: CIImage
    if hasTransparency {
        sourceMask = original.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0,y: 0,z: 0,w: 1), "inputGVector": CIVector(x: 0,y: 0,z: 0,w: 1), "inputBVector": CIVector(x: 0,y: 0,z: 0,w: 1), "inputAVector": CIVector(x: 0,y: 0,z: 0,w: 0), "inputBiasVector": CIVector(x: 0,y: 0,z: 0,w: 1)])
    } else if #available(macOS 14.0, *) {
        let handler = VNImageRequestHandler(url: input, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let result = request.results?.first, !result.allInstances.isEmpty else { throw NSError(domain: "Playseed", code: 3, userInfo: [NSLocalizedDescriptionKey: "没有识别到可分离的主体。"])}
        let buffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        sourceMask = CIImage(cvPixelBuffer: buffer)
    } else {
        throw NSError(domain: "Playseed", code: 4, userInfo: [NSLocalizedDescriptionKey: "本机去背景需要 macOS 14 或更新版本。"])
    }
    var mask = sourceMask.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": inset])
    if cleanup { mask = try cleanLightFringe(mask: mask, original: original, context: context) }
    let clear = CIImage(color: .clear).cropped(to: original.extent)
    let color = original.unpremultiplyingAlpha().settingAlphaOne(in: original.extent)
    let image = color.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: clear, kCIInputMaskImageKey: mask]).cropped(to: original.extent)
    try context.writePNGRepresentation(of: image, to: output, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    print("PLAYSEED_CUTOUT_OK")
}
do { try run() } catch {
    if (error as NSError).domain == "Playseed" && (error as NSError).code == 8 {
        fputs("PLAYSEED_CUTOUT_DETAIL_LOSS\n", stderr)
    }
    fputs("本机去背景未完成：\(error.localizedDescription)\n", stderr)
    exit(1)
}
