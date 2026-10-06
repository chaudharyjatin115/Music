import Foundation

private let whRegex = try? NSRegularExpression(pattern: "=w[0-9]+-h[0-9]+(-[a-z0-9]+)*")
private let sRegex = try? NSRegularExpression(pattern: "=s[0-9]+(-[a-z0-9]+)*")
private let mzRegex = try? NSRegularExpression(pattern: #"[0-9]+x[0-9]+(?:[a-z0-9\-]*)?\.(jpg|png|webp)"#)
private let saavnRegex = try? NSRegularExpression(pattern: #"[0-9]+x[0-9]+\.jpg"#)

extension String {
    public func thumbnailSized(for dimension: Int) -> String {
        guard !isEmpty else { return "" }

        if contains("=w") && contains("-h"), let regex = whRegex {
            let range = NSRange(startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "=w\(dimension)-h\(dimension)-c-l90-rj")
        }

        if contains("=s"), let regex = sRegex {
            let range = NSRange(startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "=s\(dimension)-c")
        }

        if contains("i.ytimg.com/vi/") {
            if dimension <= 120 {
                return replacingOccurrences(of: "maxresdefault.jpg", with: "default.jpg")
                    .replacingOccurrences(of: "hqdefault.jpg", with: "default.jpg")
                    .replacingOccurrences(of: "mqdefault.jpg", with: "default.jpg")
            } else if dimension <= 360 {
                return replacingOccurrences(of: "maxresdefault.jpg", with: "mqdefault.jpg")
                    .replacingOccurrences(of: "hqdefault.jpg", with: "mqdefault.jpg")
            }
            return self
        }

        if contains("mzstatic.com"), let regex = mzRegex {
            let range = NSRange(startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "\(dimension)x\(dimension)cc.$1")
        }

        if contains("saavncdn.com"), let regex = saavnRegex {
            let dim = dimension <= 150 ? 150 : 500
            let range = NSRange(startIndex..., in: self)
            return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "\(dim)x\(dim).jpg")
        }

        return self
    }
}
