import Foundation

class APIClient {
    static let shared = APIClient()
    var baseURL: String {
        return UserDefaults.standard.string(forKey: "backendURL") ?? "http://localhost:8000"
    }
    let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 3600 // 1 hour
        config.timeoutIntervalForResource = 3600 // 1 hour
        self.session = URLSession(configuration: config)
    }
    
    // Structs for responses
    struct SeparateResponse: Decodable {
        let status: String
        let method: String?
        let vocals: String?
        let instrumental: String?
        let message: String?
    }
    
    struct TranscribeResponse: Decodable {
        let status: String
        let syncedLyrics: String?
        let error: String?
    }
    
    enum APIError: Error {
        case fileReadFailed
        case invalidURL
        case requestFailed(String)
        case decodingFailed
    }
    
    func separate(fileURL: URL, engine: String, token: String, progress: @escaping (String) -> Void) async throws -> SeparateResponse {
        progress("Reading audio file...")
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw APIError.fileReadFailed
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(baseURL)/api/separate") else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let filename = fileURL.lastPathComponent
        var body = Data()
        
        // Engine field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"engine\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(engine)\r\n".data(using: .utf8)!)
        
        // Token field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(token)\r\n".data(using: .utf8)!)
        
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        progress("Uploading to Local Server...")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed("Server returned non-200 status code")
        }
        
        progress("Processing audio (this may take a few minutes)...")
        
        do {
            let result = try JSONDecoder().decode(SeparateResponse.self, from: data)
            if result.status == "error" {
                throw APIError.requestFailed(result.message ?? "Unknown error")
            }
            return result
        } catch {
            throw APIError.decodingFailed
        }
    }
    
    func transcribe(fileURL: URL) async throws -> TranscribeResponse {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw APIError.fileReadFailed
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let url = URL(string: "\(baseURL)/api/transcribe") else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let filename = fileURL.lastPathComponent
        var body = Data()
        
        // File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.requestFailed("Server returned non-200 status code")
        }
        
        do {
            let result = try JSONDecoder().decode(TranscribeResponse.self, from: data)
            if result.status == "error" {
                throw APIError.requestFailed(result.error ?? "Unknown error")
            }
            return result
        } catch {
            throw APIError.decodingFailed
        }
    }
    
    func getFullURL(from relativePath: String) -> URL? {
        return URL(string: "\(baseURL)\(relativePath)")
    }
}
