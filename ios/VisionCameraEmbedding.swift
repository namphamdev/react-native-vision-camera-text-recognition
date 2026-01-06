import Foundation
import MLX
import MLXEmbedders
import Tokenizers

@objc(VisionCameraEmbedding)
class VisionCameraEmbedding: NSObject {
    
    private var modelContainer: ModelContainer?
    private let modelConfiguration = ModelConfiguration.nomic_text_v1_5
    
    private var _isLoaded = false
    private var _isLoading = false
    private var _isDownloading = false
    private var _downloadProgress: Double = 0.0
    private var _loadingProgress: String = ""
    private var _modelSize: Int64 = 0
    
    // MARK: - Status
    
    @objc
    func getStatus(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        resolve([
            "isLoaded": _isLoaded,
            "isLoading": _isLoading,
            "isDownloading": _isDownloading,
            "downloadProgress": _downloadProgress,
            "loadingProgress": _loadingProgress,
            "modelSize": _modelSize,
            "formattedModelSize": formattedModelSize
        ])
    }
    
    private var formattedModelSize: String {
        guard _modelSize > 0 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: _modelSize)
    }
    
    // MARK: - Model Management
    
    @objc
    func loadModel(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !_isLoaded && !_isLoading else {
            resolve(["success": true, "message": "Model already loaded or loading"])
            return
        }
        
        _isLoading = true
        _loadingProgress = "Loading embedding model..."
        
        Task {
            do {
                MLX.GPU.clearCache()
                
                let container = try await MLXEmbedders.loadModelContainer(
                    configuration: self.modelConfiguration
                ) { [weak self] progress in
                    self?._isDownloading = true
                    self?._downloadProgress = progress.fractionCompleted
                    self?._loadingProgress = "Downloading embedding model: \(Int(progress.fractionCompleted * 100))%"
                }
                
                self.modelContainer = container
                self._isDownloading = false
                
                let size = await container.perform { (model: EmbeddingModel, tokenizer: Tokenizer, pooling: Pooling) -> Int in
                    model.numParameters()
                }
                
                MLX.GPU.clearCache()
                
                self._modelSize = Int64(size * 2)
                self._isLoaded = true
                self._isLoading = false
                self._loadingProgress = "Embedding model loaded"
                
                resolve([
                    "success": true,
                    "modelSize": self._modelSize,
                    "formattedModelSize": self.formattedModelSize
                ])
            } catch {
                self._isLoading = false
                self._isDownloading = false
                self._loadingProgress = "Failed to load model"
                reject("LOAD_ERROR", "Failed to load embedding model: \(error.localizedDescription)", error)
            }
        }
    }
    
    @objc
    func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        modelContainer = nil
        MLX.GPU.clearCache()
        _isLoaded = false
        resolve(["success": true])
    }
    
    // MARK: - Embedding
    
    @objc
    func embed(_ text: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let modelContainer = modelContainer else {
            reject("MODEL_NOT_LOADED", "Embedding model is not loaded", nil)
            return
        }
        
        Task {
            let embedding = await modelContainer.perform { (model: EmbeddingModel, tokenizer: Tokenizer, pooling: Pooling) -> [Float] in
                let inputIds = tokenizer.encode(text: text, addSpecialTokens: true)
                let inputArray = MLXArray(inputIds)
                let padded = inputArray.expandedDimensions(axis: 0)
                
                let mask = MLXArray.ones(like: padded)
                let tokenTypes = MLXArray.zeros(like: padded)
                
                let output = model(padded, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: mask)
                
                let pooledOutput = pooling(output, normalize: true, applyLayerNorm: true)
                pooledOutput.eval()
                
                return pooledOutput.squeezed().asArray(Float.self)
            }
            
            resolve(embedding)
        }
    }
    
    @objc
    func embedBatch(_ texts: [String], batchSize: Int, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let modelContainer = modelContainer else {
            reject("MODEL_NOT_LOADED", "Embedding model is not loaded", nil)
            return
        }
        
        let effectiveBatchSize = batchSize > 0 ? batchSize : 4
        
        Task {
            var allEmbeddings: [[Float]] = []
            allEmbeddings.reserveCapacity(texts.count)
            
            for batchStart in stride(from: 0, to: texts.count, by: effectiveBatchSize) {
                let batchEnd = min(batchStart + effectiveBatchSize, texts.count)
                let batchTexts = Array(texts[batchStart..<batchEnd])
                
                let batchEmbeddings = await modelContainer.perform { (model: EmbeddingModel, tokenizer: Tokenizer, pooling: Pooling) -> [[Float]] in
                    let inputs = batchTexts.map { tokenizer.encode(text: $0, addSpecialTokens: true) }
                    
                    let maxLength = inputs.reduce(into: 16) { acc, elem in
                        acc = max(acc, elem.count)
                    }
                    
                    let padTokenId = tokenizer.eosTokenId ?? 0
                    let padded = MLX.stacked(
                        inputs.map { elem in
                            MLXArray(elem + Array(repeating: padTokenId, count: maxLength - elem.count))
                        }
                    )
                    
                    let mask = (padded .!= padTokenId)
                    let tokenTypes = MLXArray.zeros(like: padded)
                    
                    let output = model(padded, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: mask)
                    
                    let pooledOutput = pooling(output, normalize: true, applyLayerNorm: true)
                    pooledOutput.eval()
                    
                    return pooledOutput.map { $0.asArray(Float.self) }
                }
                
                allEmbeddings.append(contentsOf: batchEmbeddings)
                
                MLX.GPU.clearCache()
            }
            
            resolve(allEmbeddings)
        }
    }
    
    @objc
    func embedSequentially(_ texts: [String], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard modelContainer != nil else {
            reject("MODEL_NOT_LOADED", "Embedding model is not loaded", nil)
            return
        }
        
        Task {
            var embeddings: [[Float]] = []
            embeddings.reserveCapacity(texts.count)
            
            for text in texts {
                guard let modelContainer = self.modelContainer else {
                    reject("MODEL_NOT_LOADED", "Embedding model was unloaded during processing", nil)
                    return
                }
                
                let embedding = await modelContainer.perform { (model: EmbeddingModel, tokenizer: Tokenizer, pooling: Pooling) -> [Float] in
                    let inputIds = tokenizer.encode(text: text, addSpecialTokens: true)
                    let inputArray = MLXArray(inputIds)
                    let padded = inputArray.expandedDimensions(axis: 0)
                    
                    let mask = MLXArray.ones(like: padded)
                    let tokenTypes = MLXArray.zeros(like: padded)
                    
                    let output = model(padded, positionIds: nil, tokenTypeIds: tokenTypes, attentionMask: mask)
                    
                    let pooledOutput = pooling(output, normalize: true, applyLayerNorm: true)
                    pooledOutput.eval()
                    
                    return pooledOutput.squeezed().asArray(Float.self)
                }
                
                embeddings.append(embedding)
                
                MLX.GPU.clearCache()
            }
            
            resolve(embeddings)
        }
    }
    
    // MARK: - React Native
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
