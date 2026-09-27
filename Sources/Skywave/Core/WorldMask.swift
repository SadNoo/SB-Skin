import Foundation

/// Land mask of the world at 2° resolution, rasterized from Natural Earth 1:110m land
/// (public domain). Row 0 is latitude 83°N, each row steps 2° south; column 0 is longitude
/// 179°W, each column steps 2° east. Each hex digit packs four columns, most significant first.
enum WorldMask {
    static let columns = 180
    static let rows = 71
    static let originLatitude = 83.0
    static let originLongitude = -179.0
    static let step = 2.0

    private static let hexRows: [String] = [
        "0000000000007f800ffc0000000000000000000000000",
        "000000000017ff3fffffe000000000000040000000000",
        "00000000061df0ffffff0000f8000000003c000000000",
        "000000030027c3ffffff8000200000000006000000000",
        "0000000038afc007ffff00000000030007ffc001d8000",
        "0000000e88b7b003fffe000000000c003ffffec000000",
        "80180009fc33fc00fffa00000300041dffffffeffc801",
        "00fffbfe725d8f00fff800001ff000edfffffffffffdf",
        "e0ffffffffff87c1ff8000007ffebffdfffffffffffff",
        "31fffffffffd1f80fc01e000f9ebfffffffffffffffff",
        "00fffffffff8034078000003e7fffffffffffffffffff",
        "01fdffffffe01e0038000007e7ffffffffffffffff2f0",
        "007807ffffe01e4000000007e3ffffffffffffff82200",
        "001001fffff80fe000000182c7fffffffffffffe00f00",
        "0080007fffff9ff8000003820ffffffffffffffc00e00",
        "0000007fffff9ffc000006cfffffffffffffffffc0800",
        "0000003ffffffffc000000dfffffffffffffffff40000",
        "00000017ffffff460000007fffffffffffffffff40000",
        "0000000fffffffc10000007ffffffffffffffffe40000",
        "0000000fffffff600000007f7f97fffffffffffc00000",
        "0000000ffffffe00000007f19f03fffffffffff8c0000",
        "0000000ffffffc00000003c26f7fffffffffffe080000",
        "0000000ffffff000000007c02dfffffffffff84080000",
        "00000007fffff0000000018740fffffffffffe6300000",
        "00000003fffff000000001fe022ffffffffffc4f00000",
        "00000001ffffc000000003ff000ffffffffffc1800000",
        "00000000ffff8000000007ffef7ffffffffffe0000000",
        "000000003fc04000000007ffffffdffffffffe0000000",
        "000000005f80400000001fffffefe7fffffffc0000000",
        "000000002f80000000001fffffe7f41ffffffc0000000",
        "000000000780c00000003ffffff7ff07fffff20000000",
        "000000000786100000007ffffffbfe07fcff000000000",
        "0000000003cc020000003ffffff9fe03f07e800000000",
        "0000000000fc000000003ffffff9f801e07f020000000",
        "00000000000f000000007ffffffde001c01f020000000",
        "000000000003000000003ffffffe8001c01f820000000",
        "0000000000010f0000003fffffff3000c013008000000",
        "000000000000aff000001fffffffe000a012000000000",
        "0000000000001ff800000fffffffe0002000008000000",
        "0000000000001fff00000687ffffc000002c180000000",
        "0000000000001fff80000001ffff80000014380000000",
        "0000000000003fff80000001ffff000000187a0000000",
        "0000000000003fffe0000003fffe0000000c781800000",
        "0000000000003ffffc000001fffc00000006762b80000",
        "0000000000007fffff000000fffc000000020101e0000",
        "0000000000003fffff800000fffc00000001c001f0800",
        "0000000000001fffff000000fffc000000000880d0200",
        "0000000000001ffffe0000007ffc00000000000000000",
        "0000000000000ffffe000000fffc20000000001c40000",
        "0000000000000ffffe000000fffc2000000000fc60040",
        "00000000000003fffc000000fff8e000000001fe60000",
        "00000000000001fffc000000fff0e000000001ffe0000",
        "00000000000001fffc0000007ff0c00000000ffff8080",
        "00000000000001fff00000007ff0c00000001ffff8000",
        "00000000000001ffc00000007fe0800000001ffffc000",
        "00000000000001ffc00000003fc0000000001ffffe000",
        "00000000000003ff800000003fc0000000001ffffe000",
        "00000000000003ff800000001f80000000000ffffe000",
        "00000000000003ff000000001f00000000000f07fc000",
        "00000000000003f8000000000000000000000801f8008",
        "00000000000007fc000000000000000000000000f8004",
        "00000000000007e000000000000000000000000000006",
        "00000000000007a00000000000000000000000003000c",
        "00000000000003c000000000000000000000000010018",
        "000000000000078000000000000000000000000000030",
        "000000000000078000000000000000000000000000000",
        "0000000000000f0000000000000000080000000000000",
        "0000000000000e0000000000000000000000000000000",
        "000000000000070000000000000000000000000000000",
        "000000000000030000000000000000000000000000000",
        "000000000000000000000000000000000000000000000",
    ]

    /// Every land cell as (column, row).
    static let landCells: [(column: Int, row: Int)] = {
        var cells: [(Int, Int)] = []
        for (row, line) in hexRows.enumerated() {
            for (index, character) in line.enumerated() {
                guard let nibble = character.hexDigitValue else { continue }
                for bit in 0 ..< 4 where nibble & (8 >> bit) != 0 {
                    let column = index * 4 + bit
                    if column < columns { cells.append((column, row)) }
                }
            }
        }
        return cells
    }()

    /// Grid position of a coordinate, fractional.
    static func gridPoint(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        ((longitude - originLongitude) / step, (originLatitude - latitude) / step)
    }
}
