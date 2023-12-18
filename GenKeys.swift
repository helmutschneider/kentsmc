import Foundation

let body = try String(contentsOfFile: "keys.txt", encoding: .utf8)
    .trimmingCharacters(in: CharacterSet(charactersIn: "\n\t "))

var stuff: [String: String] = [:]

for line in body.split(separator: "\n") {
    let chunks = line.split(separator: ":")
    var key = String(chunks[1])
    var desc = String(chunks[0])
    var doRepeat = 1

    if key.contains("%d") {
        doRepeat = 10
    } else if key.contains("%") {
        key.replace("%", with: "%d")
        desc.replace("%", with: "%d")
        doRepeat = 10
    }

    for i in 0..<doRepeat {
        let k = String(format: key, arguments: [i])
        let v = String(format: desc, arguments: [i])
        stuff[k] = v
    }
}

print("// I was auto-generated on \(Date.now)")
print("let SMC_KEYS: [String: String] = [")
for (k, v) in stuff {
    print("    \"\(k)\": \"\(v)\",")
}
print("]")
