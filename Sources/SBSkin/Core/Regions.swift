import Foundation

/// Where a node probably is, inferred from its tag.
///
/// The core does not know the geography of a server, so skins that talk about places
/// (Places, Radio) read it from the name the provider gave the node: a flag emoji,
/// an ISO code, or a country / city name in English or Chinese. Anything unrecognized
/// falls into “Other”. This is presentation only; nothing is sent anywhere.
public struct SkinRegion: Hashable, Sendable, Identifiable {
    public let code: String
    public let latitude: Double
    public let longitude: Double
    public let continent: Continent

    public var id: String { code }

    public enum Continent: String, CaseIterable, Sendable {
        case asia, europe, americas, oceania, africa, middleEast

        var displayName: String {
            switch self {
            case .asia: SkinL("Asia")
            case .europe: SkinL("Europe")
            case .americas: SkinL("Americas")
            case .oceania: SkinL("Oceania")
            case .africa: SkinL("Africa")
            case .middleEast: SkinL("Middle East")
            }
        }
    }

    public var name: String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    public var flag: String {
        code.unicodeScalars.compactMap { UnicodeScalar(127_397 + $0.value) }.map(String.init).joined()
    }

    // MARK: Inference

    public static func infer(from tag: String) -> SkinRegion? {
        if let code = flagCode(in: tag), let region = table[code] {
            return region
        }
        let lower = tag.lowercased()
        for (keyword, code) in keywords where matches(keyword, in: lower) {
            if let region = table[code] { return region }
        }
        return nil
    }

    /// Removes a leading flag emoji so names read cleanly next to a badge.
    public static func stripFlag(_ tag: String) -> String {
        var scalars = Array(tag.unicodeScalars)
        while let first = scalars.first, (0x1F1E6 ... 0x1F1FF).contains(first.value) {
            scalars.removeFirst()
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    private static func flagCode(in tag: String) -> String? {
        let scalars = Array(tag.unicodeScalars)
        guard scalars.count >= 2 else { return nil }
        for index in 0 ..< scalars.count - 1 {
            let a = scalars[index].value
            let b = scalars[index + 1].value
            if (0x1F1E6 ... 0x1F1FF).contains(a), (0x1F1E6 ... 0x1F1FF).contains(b) {
                let first = Character(UnicodeScalar(a - 127_397)!)
                let second = Character(UnicodeScalar(b - 127_397)!)
                return String([first, second])
            }
        }
        return nil
    }

    /// ASCII keywords must stand alone (so “us” does not match “russia”); CJK can match anywhere.
    private static func matches(_ keyword: String, in text: String) -> Bool {
        guard keyword.unicodeScalars.allSatisfy(\.isASCII) else {
            return text.contains(keyword)
        }
        var searchRange = text.startIndex ..< text.endIndex
        while let range = text.range(of: keyword, range: searchRange) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            let boundaryBefore = before.map { !$0.isLetter || !$0.isASCII } ?? true
            let boundaryAfter = after.map { !$0.isLetter || !$0.isASCII } ?? true
            if boundaryBefore, boundaryAfter { return true }
            searchRange = range.upperBound ..< text.endIndex
        }
        return false
    }

    private static func region(_ code: String, _ lat: Double, _ lon: Double, _ continent: Continent) -> (String, SkinRegion) {
        (code, SkinRegion(code: code, latitude: lat, longitude: lon, continent: continent))
    }

    static let table: [String: SkinRegion] = Dictionary(uniqueKeysWithValues: [
        region("HK", 22.3, 114.2, .asia), region("MO", 22.2, 113.5, .asia), region("TW", 25.0, 121.5, .asia),
        region("CN", 31.2, 121.5, .asia), region("JP", 35.7, 139.7, .asia), region("KR", 37.6, 127.0, .asia),
        region("SG", 1.35, 103.8, .asia), region("MY", 3.1, 101.7, .asia), region("TH", 13.8, 100.5, .asia),
        region("VN", 10.8, 106.7, .asia), region("PH", 14.6, 121.0, .asia), region("ID", -6.2, 106.8, .asia),
        region("IN", 19.1, 72.9, .asia), region("KZ", 43.2, 76.9, .asia), region("MN", 47.9, 106.9, .asia),
        region("US", 37.4, -122.0, .americas), region("CA", 43.7, -79.4, .americas), region("MX", 19.4, -99.1, .americas),
        region("BR", -23.5, -46.6, .americas), region("AR", -34.6, -58.4, .americas), region("CL", -33.4, -70.6, .americas),
        region("GB", 51.5, -0.1, .europe), region("DE", 50.1, 8.7, .europe), region("FR", 48.9, 2.4, .europe),
        region("NL", 52.4, 4.9, .europe), region("CH", 47.4, 8.5, .europe), region("SE", 59.3, 18.1, .europe),
        region("FI", 60.2, 24.9, .europe), region("NO", 59.9, 10.8, .europe), region("IE", 53.3, -6.3, .europe),
        region("IT", 45.5, 9.2, .europe), region("ES", 40.4, -3.7, .europe), region("PL", 52.2, 21.0, .europe),
        region("RU", 55.8, 37.6, .europe), region("UA", 50.5, 30.5, .europe), region("TR", 41.0, 29.0, .europe),
        region("AT", 48.2, 16.4, .europe), region("CZ", 50.1, 14.4, .europe), region("RO", 44.4, 26.1, .europe),
        region("AE", 25.2, 55.3, .middleEast), region("IL", 32.1, 34.8, .middleEast), region("SA", 24.7, 46.7, .middleEast),
        region("AU", -33.9, 151.2, .oceania), region("NZ", -36.8, 174.8, .oceania),
        region("ZA", -26.2, 28.0, .africa), region("EG", 30.0, 31.2, .africa), region("NG", 6.5, 3.4, .africa),
    ])

    /// Ordered longest-first so “united kingdom” wins over “united states” prefixes etc.
    static let keywords: [(String, String)] = {
        let pairs: [(String, [String])] = [
            ("HK", ["香港", "hong kong", "hongkong", "hk", "hkg"]),
            ("MO", ["澳门", "macau", "macao"]),
            ("TW", ["台湾", "臺灣", "台北", "taiwan", "taipei", "tw"]),
            ("CN", ["中国", "上海", "北京", "广州", "深圳", "china", "shanghai", "beijing", "cn"]),
            ("JP", ["日本", "东京", "東京", "大阪", "japan", "tokyo", "osaka", "jp"]),
            ("KR", ["韩国", "韓國", "首尔", "korea", "seoul", "kr"]),
            ("SG", ["新加坡", "狮城", "singapore", "sg"]),
            ("MY", ["马来西亚", "吉隆坡", "malaysia", "kuala lumpur"]),
            ("TH", ["泰国", "曼谷", "thailand", "bangkok", "th"]),
            ("VN", ["越南", "vietnam", "vn"]),
            ("PH", ["菲律宾", "马尼拉", "philippines", "manila", "ph"]),
            ("ID", ["印尼", "印度尼西亚", "雅加达", "indonesia", "jakarta"]),
            ("IN", ["印度", "孟买", "india", "mumbai"]),
            ("KZ", ["哈萨克", "kazakhstan", "kz"]),
            ("MN", ["蒙古", "mongolia"]),
            ("US", ["美国", "美國", "洛杉矶", "硅谷", "圣何塞", "西雅图", "纽约", "芝加哥", "达拉斯", "united states", "usa", "los angeles", "san jose", "seattle", "new york", "chicago", "dallas", "silicon valley", "us"]),
            ("CA", ["加拿大", "多伦多", "温哥华", "canada", "toronto", "vancouver", "ca"]),
            ("MX", ["墨西哥", "mexico", "mx"]),
            ("BR", ["巴西", "圣保罗", "brazil", "sao paulo", "br"]),
            ("AR", ["阿根廷", "argentina", "ar"]),
            ("CL", ["智利", "chile", "cl"]),
            ("GB", ["英国", "英國", "伦敦", "united kingdom", "britain", "london", "uk", "gb"]),
            ("DE", ["德国", "德國", "法兰克福", "germany", "frankfurt", "de"]),
            ("FR", ["法国", "巴黎", "france", "paris", "fr"]),
            ("NL", ["荷兰", "阿姆斯特丹", "netherlands", "amsterdam", "nl"]),
            ("CH", ["瑞士", "苏黎世", "switzerland", "zurich", "ch"]),
            ("SE", ["瑞典", "sweden", "stockholm", "se"]),
            ("FI", ["芬兰", "finland", "helsinki", "fi"]),
            ("NO", ["挪威", "norway", "oslo"]),
            ("IE", ["爱尔兰", "ireland", "dublin", "ie"]),
            ("IT", ["意大利", "米兰", "italy", "milan"]),
            ("ES", ["西班牙", "马德里", "spain", "madrid", "es"]),
            ("PL", ["波兰", "poland", "warsaw", "pl"]),
            ("RU", ["俄罗斯", "莫斯科", "russia", "moscow", "ru"]),
            ("UA", ["乌克兰", "ukraine", "kyiv", "ua"]),
            ("TR", ["土耳其", "伊斯坦布尔", "turkey", "türkiye", "istanbul", "tr"]),
            ("AT", ["奥地利", "维也纳", "austria", "vienna"]),
            ("CZ", ["捷克", "czech", "prague", "cz"]),
            ("RO", ["罗马尼亚", "romania", "ro"]),
            ("AE", ["阿联酋", "迪拜", "united arab emirates", "dubai", "uae", "ae"]),
            ("IL", ["以色列", "israel", "il"]),
            ("SA", ["沙特", "saudi", "sa"]),
            ("AU", ["澳大利亚", "澳洲", "悉尼", "australia", "sydney", "au"]),
            ("NZ", ["新西兰", "new zealand", "auckland", "nz"]),
            ("ZA", ["南非", "south africa", "johannesburg", "za"]),
            ("EG", ["埃及", "egypt", "cairo", "eg"]),
            ("NG", ["尼日利亚", "nigeria", "lagos", "ng"]),
        ]
        return pairs
            .flatMap { code, words in words.map { ($0, code) } }
            .sorted { $0.0.count > $1.0.count }
    }()
}
