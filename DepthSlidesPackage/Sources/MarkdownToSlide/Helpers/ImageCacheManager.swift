import CryptoKit
import Foundation

/// 画像URLからダウンロードしてローカルキャッシュに保存するマネージャー
@MainActor
public final class ImageCacheManager {
  public static let shared = ImageCacheManager()

  private let cacheDirectory: URL
  private let session: URLSession

  private init() {
    // tmp領域にキャッシュディレクトリを作成
    let tmpDir = FileManager.default.temporaryDirectory
    cacheDirectory = tmpDir.appendingPathComponent(
      "ImageCache",
      isDirectory: true
    )

    // ディレクトリが存在しない場合は作成
    if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
      try? FileManager.default.createDirectory(
        at: cacheDirectory,
        withIntermediateDirectories: true
      )
    }

    // URLSessionの設定（タイムアウトなど）
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 60
    session = URLSession(configuration: configuration)
  }

  /// URLのSHA256ハッシュを計算してファイル名を生成
  private func cacheFileName(for urlString: String) -> String {
    let hash = SHA256.hash(data: Data(urlString.utf8))
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

    // 拡張子を保持（可能な場合）
    if let url = URL(string: urlString),
      let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
    {
      return "\(hashString).\(ext)"
    }
    return hashString
  }

  /// ローカルキャッシュファイルのURLを取得
  private func localCacheURL(for urlString: String) -> URL {
    let fileName = cacheFileName(for: urlString)
    return cacheDirectory.appendingPathComponent(fileName)
  }

  /// 画像がキャッシュに存在するか確認
  public func isCached(_ urlString: String) -> Bool {
    let localURL = localCacheURL(for: urlString)
    return FileManager.default.fileExists(atPath: localURL.path)
  }

  /// 画像をダウンロードしてキャッシュに保存（非同期）
  /// - Parameter urlString: 画像のURL文字列
  /// - Returns: ローカルキャッシュファイルのURL（file://で始まる）
  public func cacheImage(_ urlString: String) async throws -> URL {
    // 既にキャッシュに存在する場合はそのURLを返す
    let localURL = localCacheURL(for: urlString)
    if FileManager.default.fileExists(atPath: localURL.path) {
      return localURL
    }

    // URLが既にfile://で始まる場合（ローカルファイル）はそのまま返す
    if urlString.hasPrefix("file://") {
      return URL(fileURLWithPath: urlString)
    }

    guard let url = URL(string: urlString) else {
      throw ImageCacheError.invalidURL(urlString)
    }

    // 画像をダウンロード
    let (data, response) = try await session.data(from: url)

    // HTTPレスポンスを確認
    if let httpResponse = response as? HTTPURLResponse,
      !(200...299).contains(httpResponse.statusCode)
    {
      throw ImageCacheError.httpError(httpResponse.statusCode)
    }

    // データを保存
    try data.write(to: localURL, options: .atomic)

    return localURL
  }

  /// 複数の画像URLを一括でキャッシュ
  /// - Parameter urlStrings: 画像URL文字列の配列
  /// - Returns: 元のURLとローカルURLのマッピング辞書
  public func cacheImages(_ urlStrings: [String]) async -> [String: URL] {
    var mapping: [String: URL] = [:]

    await withTaskGroup(of: (String, URL?).self) { group in
      for urlString in urlStrings {
        group.addTask {
          do {
            let localURL = try await self.cacheImage(urlString)
            return (urlString, localURL)
          } catch {
            print("Failed to cache image \(urlString): \(error)")
            return (urlString, nil)
          }
        }
      }

      for await (urlString, localURL) in group {
        if let localURL = localURL {
          mapping[urlString] = localURL
        }
      }
    }

    return mapping
  }

  /// キャッシュをクリア
  public func clearCache() {
    try? FileManager.default.removeItem(at: cacheDirectory)
    try? FileManager.default.createDirectory(
      at: cacheDirectory,
      withIntermediateDirectories: true
    )
  }
}

// MARK: - Error

public enum ImageCacheError: LocalizedError {
  case invalidURL(String)
  case httpError(Int)

  public var errorDescription: String? {
    switch self {
    case .invalidURL(let urlString):
      return "Invalid URL: \(urlString)"
    case .httpError(let statusCode):
      return "HTTP error: \(statusCode)"
    }
  }
}
